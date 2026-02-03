const express = require("express");
const helmet = require("helmet");
const rateLimit = require("express-rate-limit");
const { v4: uuidv4 } = require("uuid");
const routes = require("./routes");

const app = express();

// =====================================================
// 🛡️ 보안 미들웨어
// =====================================================
app.use(helmet());

// 신뢰할 수 있는 프록시 설정 (AWS NLB/ALB 뒤에 있으므로)
app.set("trust proxy", 1);

// Rate Limiting (분당 100 요청)
const limiter = rateLimit({
  windowMs: 60 * 1000, // 1분
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: "Too many requests, please try again later" },
  skip: (req) => req.path === "/api/v1/health", // 헬스체크 제외
});
app.use(limiter);

// Body parser
app.use(express.json({ limit: "10kb" })); // 요청 크기 제한

// =====================================================
// 📝 Request ID & Logging 미들웨어
// =====================================================
app.use((req, res, next) => {
  // Request ID 생성 (추적용)
  req.id = req.headers["x-request-id"] || uuidv4();
  res.setHeader("x-request-id", req.id);

  // 구조화된 로깅
  if (process.env.NODE_ENV !== "test") {
    const startTime = Date.now();

    res.on("finish", () => {
      const duration = Date.now() - startTime;
      console.log(
        JSON.stringify({
          timestamp: new Date().toISOString(),
          requestId: req.id,
          method: req.method,
          path: req.url,
          statusCode: res.statusCode,
          durationMs: duration,
          userAgent: req.get("user-agent"),
          ip: req.ip,
        }),
      );
    });
  }

  next();
});

// =====================================================
// 🛣️ 라우트
// =====================================================
app.use("/api/v1", routes);

// =====================================================
// ❌ 404 핸들러
// =====================================================
app.use((req, res) => {
  res.status(404).json({
    error: "Endpoint not found",
    requestId: req.id,
    path: req.url,
  });
});

// =====================================================
// 🚨 글로벌 에러 핸들러 (반드시 마지막에!)
// =====================================================
app.use((err, req, res, next) => {
  // 에러 로깅
  console.error(
    JSON.stringify({
      timestamp: new Date().toISOString(),
      requestId: req.id,
      error: err.message,
      stack: process.env.NODE_ENV === "development" ? err.stack : undefined,
    }),
  );

  // 클라이언트에게 응답
  const statusCode = err.statusCode || 500;
  res.status(statusCode).json({
    error:
      process.env.NODE_ENV === "production"
        ? "Internal server error"
        : err.message,
    requestId: req.id,
  });
});

module.exports = app;
