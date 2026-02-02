/* app/index.js */
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

// [미들웨어] 로깅
app.use((req, res, next) => {
  if (process.env.NODE_ENV !== 'test') {
    console.log(`${new Date().toISOString()} ${req.method} ${req.path} [${req.headers.host}]`);
  }
  next();
});

// [Global] K8s Health Check (모든 도메인 공통)
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy', uptime: process.uptime() });
});

app.get('/ready', (req, res) => {
  res.status(200).json({ ready: true });
});

// [HTML] 메인 페이지용 HTML
const mainHtml = `
<!DOCTYPE html>
<html>
<head>
    <title>Upbit Exchange</title>
    <style>
        body { display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; background-color: #f4f4f4; font-family: Arial, sans-serif; }
        .center-box { text-align: center; padding: 20px; background: white; border-radius: 8px; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
        h1 { color: #0058dc; }
    </style>
</head>
<body>
    <div class="center-box">
        <h1>This is Upbit Exchange</h1>
        <p>Welcome to playdevops.xyz</p>
    </div>
</body>
</html>
`;

// [라우팅] 도메인 분기 처리 미들웨어
app.use((req, res, next) => {
  const host = req.headers.host || '';
  // 포트 번호 제거 (localhost:3000 -> localhost)
  const hostname = host.split(':')[0];

  // 1. Custody 서브도메인 (custody.playdevops.xyz)
  if (hostname.startsWith('custody')) {
    if (req.path.startsWith('/introduction')) {
      return res.json({
        service: 'Upbit Custody',
        message: 'Institutional Grade Custody Service',
        domain: 'custody.playdevops.xyz',
      });
    }
    return res.json({ welcome: 'Welcome to Custody Service' });
  }

  // 2. Datalab 서브도메인 (datalab.playdevops.xyz)
  if (hostname.startsWith('datalab')) {
    return res.json({
      service: 'Data Lab',
      message: 'Market Analysis & Insights',
      domain: 'datalab.playdevops.xyz',
      query: req.query,
    });
  }

  // 3. 메인 도메인 (playdevops.xyz) - 다음 라우터로 통과
  next();
});

// [라우팅] 메인 도메인 경로 핸들러
app.get(['/', '/exchange'], (req, res) => {
  res.send(mainHtml);
});

app.get('/trends', (req, res) => {
  res.json({
    page: 'Trends',
    message: 'This is Coin Trends Page',
    domain: 'playdevops.xyz',
  });
});

app.get('/staking/items', (req, res) => {
  res.json({ service: 'Staking', items: ['ETH', 'SOL', 'ADA'] });
});

app.get('/recurring_buy', (req, res) => {
  res.json({ service: 'Recurring Buy', status: 'Active' });
});

app.get('/lending', (req, res) => {
  res.json({ service: 'Lending', rates: 'Variable' });
});

app.get('/nft', (req, res) => {
  res.json({ service: 'NFT', featured: 'BTS Moments' });
});

// 404 처리 (메인 도메인)
app.use((req, res) => {
  res.status(404).json({ error: 'Page Not Found on Main Exchange' });
});

// 서버 실행 (테스트 환경 제외)
if (require.main === module) {
  const server = app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Server running on port ${PORT}`);
  });

  process.on('SIGTERM', () => {
    console.log('SIGTERM received, shutting down gracefully...');
    server.close(() => {
      console.log('Server closed');
      process.exit(0);
    });
  });
}

module.exports = app;