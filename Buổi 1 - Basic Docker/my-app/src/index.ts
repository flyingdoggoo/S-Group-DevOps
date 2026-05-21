import express from 'express';

const app = express();
const PORT = Number(process.env.PORT ?? 3000);
let shuttingDown = false;

process.on('SIGTERM', () => {
  shuttingDown = true;
  setTimeout(() => process.exit(0), 10_000);
});

app.get('/live', (_req, res) => {
  res.json({ status: 'alive' });
});

app.get('/ready', (_req, res) => {
  if (shuttingDown) {
    res.status(503).json({ status: 'shutting_down' });
    return;
  }

  res.json({ status: 'ready' });
});

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', env: process.env.NODE_ENV ?? null });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
});