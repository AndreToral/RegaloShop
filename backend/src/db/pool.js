const { Pool } = require('pg');

function asBoolean(value) {
  if (!value) {
    return false;
  }
  const normalized = value.toString().toLowerCase();
  return normalized === 'true' || normalized === '1' || normalized === 'require';
}

const poolConfig = {};

if (process.env.DATABASE_URL) {
  poolConfig.connectionString = process.env.DATABASE_URL;
} else {
  poolConfig.host = process.env.DB_HOST || 'localhost';
  poolConfig.port = Number(process.env.DB_PORT) || 5432;
  poolConfig.user = process.env.DB_USER || 'postgres';
  poolConfig.password = process.env.DB_PASSWORD;
  poolConfig.database = process.env.DB_NAME || 'regaloshop';
}

if (asBoolean(process.env.DB_SSL)) {
  poolConfig.ssl = {
    rejectUnauthorized: asBoolean(process.env.DB_SSL_STRICT),
  };
}

if (process.env.DB_POOL_MAX) {
  poolConfig.max = Number(process.env.DB_POOL_MAX);
}

if (process.env.DB_POOL_IDLE) {
  poolConfig.idleTimeoutMillis = Number(process.env.DB_POOL_IDLE);
}

if (process.env.DB_STATEMENT_TIMEOUT) {
  poolConfig.statement_timeout = Number(process.env.DB_STATEMENT_TIMEOUT);
}

const pool = new Pool(poolConfig);

pool.on('error', (error) => {
  console.error('Error inesperado en la conexion de PostgreSQL', error);
});

async function withTransaction(handler) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await handler(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    try {
      await client.query('ROLLBACK');
    } catch (rollbackError) {
      console.error('Fallo al revertir la transaccion', rollbackError);
    }
    throw error;
  } finally {
    client.release();
  }
}

function getExecutor(client) {
  if (client && typeof client.query === 'function') {
    return client;
  }
  return pool;
}

async function query(text, params) {
  return pool.query(text, params);
}

module.exports = {
  pool,
  query,
  withTransaction,
  getExecutor,
};
