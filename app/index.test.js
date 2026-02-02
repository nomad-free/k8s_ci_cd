/* app/index.test.js */
const request = require("supertest");
const app = require("./index");

describe("Upbit Mock App Tests", () => {
  // 1. 공통 Health Check
  describe("Global Endpoints", () => {
    it("GET /health should return 200", async () => {
      const res = await request(app).get("/health");
      expect(res.statusCode).toEqual(200);
      expect(res.body).toHaveProperty("status", "healthy");
    });

    it("GET /ready should return 200", async () => {
      const res = await request(app).get("/ready");
      expect(res.statusCode).toEqual(200);
      expect(res.body).toHaveProperty("ready", true);
    });
  });

  // 2. 메인 도메인 테스트
  describe("Main Domain (playdevops.xyz)", () => {
    const host = "playdevops.xyz";

    it("GET / should return HTML", async () => {
      const res = await request(app).get("/").set("Host", host);
      expect(res.statusCode).toEqual(200);
      expect(res.text).toContain("This is Upbit Exchange");
    });

    it("GET /trends should return Trends JSON", async () => {
      const res = await request(app).get("/trends").set("Host", host);
      expect(res.statusCode).toEqual(200);
      expect(res.body).toHaveProperty("page", "Trends");
    });

    it("GET /nft should return NFT JSON", async () => {
      const res = await request(app).get("/nft").set("Host", host);
      expect(res.statusCode).toEqual(200);
      expect(res.body).toHaveProperty("service", "NFT");
    });
  });

  // 3. Custody 서브도메인 테스트
  describe("Custody Subdomain (custody.playdevops.xyz)", () => {
    const host = "custody.playdevops.xyz";

    it("GET /introduction should return Custody Info", async () => {
      const res = await request(app).get("/introduction").set("Host", host);
      expect(res.statusCode).toEqual(200);
      expect(res.body).toHaveProperty("service", "Upbit Custody");
      expect(res.body).toHaveProperty("domain", "custody.playdevops.xyz");
    });

    it("GET / (root) should return Welcome message", async () => {
      const res = await request(app).get("/").set("Host", host);
      expect(res.statusCode).toEqual(200);
      expect(res.body).toHaveProperty("welcome", "Welcome to Custody Service");
    });
  });

  // 4. Datalab 서브도메인 테스트
  describe("Datalab Subdomain (datalab.playdevops.xyz)", () => {
    const host = "datalab.playdevops.xyz";

    it("GET /any-path should return Datalab JSON", async () => {
      const res = await request(app).get("/?utm_source=test").set("Host", host);
      expect(res.statusCode).toEqual(200);
      expect(res.body).toHaveProperty("service", "Data Lab");
      expect(res.body.query).toHaveProperty("utm_source", "test");
    });
  });
});
