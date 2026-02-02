
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;
app.use(express.json());
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} ${req.method} ${req.path}`);
  next();
});
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});
app.get('/ready', (req, res) => {
  
  res.status(200).json({ ready: true });
});
app.get('/', (req, res) => {
  res.json({
    message: 'Hello from EKS CI/CD!',
    version: process.env.VERSION || '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    pod: process.env.POD_NAME || 'local'
  });
});
app.get('/api/info', (req, res) => {
  res.json({
    app: 'k8s-ci-cd-app',
    node_version: process.version,
    environment: {
      NODE_ENV: process.env.NODE_ENV,
      POD_NAME: process.env.POD_NAME,
      POD_NAMESPACE: process.env.POD_NAMESPACE
    }
  });
});
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`   Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`   Health check: http:
});
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully...');
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});
module.exports = app;
