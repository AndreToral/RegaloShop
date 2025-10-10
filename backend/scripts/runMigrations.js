#!/usr/bin/env node
require('dotenv').config();

const fs = require('fs/promises');
const path = require('path');
const { pool } = require('../src/db/pool');

async function run() {
  const migrationsDir = path.join(__dirname, '..', 'db', 'migrations');
  const entries = await fs.readdir(migrationsDir, { withFileTypes: true });
  const files = entries
    .filter((e) => e.isFile() && e.name.endsWith('.sql'))
    .map((e) => e.name)
    .sort();

  for (const file of files) {
    const filePath = path.join(migrationsDir, file);
    const sql = await fs.readFile(filePath, 'utf-8');
    process.stdout.write(`Applying migration: ${file}... `);
    try {
      await pool.query(sql);
      process.stdout.write('done\n');
    } catch (error) {
      console.error(`\nFailed on ${file}:`, error.message);
      process.exitCode = 1;
      break;
    }
  }

  await pool.end();
}

run();

