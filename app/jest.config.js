/* app/jest.config.js */
module.exports = {
  testEnvironment: "node",
  // 현재 디렉토리의 모든 js 파일에서 커버리지 수집 (테스트 파일 제외)
  collectCoverageFrom: [
    "*.js",
    "!*.test.js",
    "!jest.config.js",
    "!.eslintrc.js",
  ],
  coverageDirectory: "coverage",
  verbose: true,
};
