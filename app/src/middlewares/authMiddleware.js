const config = require("../config");
const jwt = require("jsonwebtoken");

// 1. API Key 인증 (서버 간 통신용)
exports.verifyApiKey = (req, res, next) => {
  if (config.env === "test") return next();

  const clientKey = req.headers["x-api-key"];
  if (!clientKey || clientKey !== config.security.apiKey) {
    return res
      .status(401)
      .json({ error: "Unauthorized", message: "Invalid API Key" });
  }
  next();
};

// 2. JWT 인증 (관리자/유저용)
exports.verifyJwt = (req, res, next) => {
  const authHeader = req.headers["authorization"];
  const token = authHeader && authHeader.split(" ")[1]; // "Bearer TOKEN"

  if (!token)
    return res
      .status(401)
      .json({ error: "Unauthorized", message: "Token required" });

  jwt.verify(token, config.security.jwtSecret, (err, user) => {
    if (err)
      return res
        .status(403)
        .json({ error: "Forbidden", message: "Invalid Token" });
    req.user = user;
    next();
  });
};
