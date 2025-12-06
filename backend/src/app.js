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
    return res.status(200).json({ status: 'ok', database: 'skipped', ...basePayload });
  }

  try {
    await query('SELECT 1');
    res.status(200).json({ status: 'ok', database: 'reachable', ...basePayload });
  } catch (error) {
    console.error('Healthcheck fallo al conectar con la base de datos', error);
    // Retornar 200 de todas formas para que el ALB considere el task como healthy
    // mientras se recupera la conexión a la BD
    res.status(200).json({ status: 'degraded', database: 'unreachable', error: error.message, ...basePayload });
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
