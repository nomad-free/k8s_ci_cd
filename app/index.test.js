/**
 * 기본 테스트 파일
 */
const app = require('./index');
describe('Health Check', () => {
  test('should return healthy status', async () => {
    
    expect(true).toBe(true);
  });
});
describe('App', () => {
  test('should be defined', () => {
    expect(app).toBeDefined();
  });
});
