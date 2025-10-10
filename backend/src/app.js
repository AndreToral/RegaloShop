const express = require('express');
const cors = require('cors');
const apiRoutes = require('./routes');
const { query } = require('./db/pool');

const app = express();

app.use(
  cors({
    origin: process.env.FRONTEND_URL ? process.env.FRONTEND_URL.split(',') : '*',
  })
);
app.use(express.json());

app.get('/health', async (req, res) => {
  const basePayload = { timestamp: new Date().toISOString() };

  const disableDb = (process.env.DISABLE_DB_HEALTHCHECK || '').toLowerCase() === 'true';
  if (disableDb) {
    return res.json({ status: 'ok', database: 'skipped', ...basePayload });
  }

  try {
    await query('SELECT 1');
    res.json({ status: 'ok', database: 'reachable', ...basePayload });
  } catch (error) {
    console.error('Healthcheck fallo al conectar con la base de datos', error);
    res.status(503).json({ status: 'error', database: 'unreachable', ...basePayload });
  }
});

app.use('/api', apiRoutes);

app.use((req, res) => {
  res.status(404).json({ message: 'Recurso no encontrado' });
});

app.use((error, req, res, next) => {
  console.error(error);
  const status = error.status || 500;
  res.status(status).json({
    message: error.message || 'Error interno del servidor',
  });
});

module.exports = app;
