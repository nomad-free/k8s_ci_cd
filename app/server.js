const app = require("./src/app");
const config = require("./src/config");
const { initTable } = require("./src/repositories/settlementRepository");

let server;

async function startServer() {
  try {
    // DB 테이블 초기화 (선택적)
    if (process.env.NODE_ENV !== "test") {
      await initTable();
    }

    server = app.listen(config.port, () => {
      console.log(
        `🚀 Exchange Settlement Service running on port ${config.port}`,
      );
      console.log(`   Environment: ${config.env}`);
      console.log(`   Security: JWT & Encryption Enabled`);
    });

    // Graceful Shutdown 설정
    setupGracefulShutdown();
  } catch (error) {
    console.error("❌ Failed to start server:", error);
    process.exit(1);
  }
}

function setupGracefulShutdown() {
  const signals = ["SIGTERM", "SIGINT"];

  signals.forEach((signal) => {
    process.on(signal, async () => {
      console.log(`\n📛 Received ${signal}, starting graceful shutdown...`);

      // 새로운 요청 거부 (K8s가 트래픽 라우팅 중단하도록)
      server.close(async (err) => {
        if (err) {
          console.error("❌ Error during shutdown:", err);
          process.exit(1);
        }

        console.log("✅ HTTP server closed");

        // DB 연결 종료 등 정리 작업
        try {
          const { pool } = require("./src/repositories/settlementRepository");
          if (pool) {
            await pool.end();
            console.log("✅ Database connections closed");
          }
        } catch (dbError) {
          console.error("⚠️ Error closing database:", dbError);
        }

        console.log("👋 Graceful shutdown complete");
        process.exit(0);
      });

      // 강제 종료 타이머 (30초)
      setTimeout(() => {
        console.error("⏰ Forced shutdown after timeout");
        process.exit(1);
      }, 30000);
    });
  });
}

startServer();
