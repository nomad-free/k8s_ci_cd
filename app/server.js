const app = require("./src/app");
const config = require("./src/config");
const { initTable } = require("./src/repositories/settlementRepository");

const startServer = async () => {
  try {
    // 1. DB 테이블 초기화 시도 (기다림)
    await initTable();

    // 2. 성공 시 서버 시작
    app.listen(config.port, () => {
      console.log(
        `🚀 Exchange Settlement Service running on port ${config.port}`,
      );
      console.log(`   Environment: ${config.env}`);
      console.log(`   Security: JWT & Encryption Enabled`);
    });
  } catch (err) {
    // 3. 실패 시 에러 로그 출력 및 프로세스 종료
    console.error("❌ Critical Error: Failed to initialize DB:", err);
    process.exit(1);
  }
};

startServer();
