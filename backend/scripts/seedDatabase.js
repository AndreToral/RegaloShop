#!/usr/bin/env node
require('dotenv').config();

const fs = require('fs/promises');
const path = require('path');
const { withTransaction, pool } = require('../src/db/pool');

const ROOT_DIR = path.join(__dirname, '..');
const DATA_DIR = path.join(ROOT_DIR, 'src', 'data');

function readJSON(fileName) {
  const filePath = path.join(DATA_DIR, fileName);
  return fs.readFile(filePath, 'utf-8').then((content) => JSON.parse(content));
}

async function seedProducts(client, products, truncate) {
  if (truncate) {
    await client.query('TRUNCATE TABLE products RESTART IDENTITY CASCADE');
  }

  for (const product of products) {
    await client.query(
      `INSERT INTO products (id, name, description, category, price, stock, image, tags)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       ON CONFLICT (id) DO UPDATE SET
         name = EXCLUDED.name,
         description = EXCLUDED.description,
         category = EXCLUDED.category,
         price = EXCLUDED.price,
         stock = EXCLUDED.stock,
         image = EXCLUDED.image,
         tags = EXCLUDED.tags,
         updated_at = NOW()`,
      [
        product.id,
        product.name,
        product.description,
        product.category,
        Number(product.price),
        Number(product.stock),
        product.image || null,
        Array.isArray(product.tags) ? product.tags : [],
      ]
    );
  }
}

async function seedOrders(client, orders, truncate) {
  if (truncate) {
    await client.query('TRUNCATE TABLE orders RESTART IDENTITY CASCADE');
  }

  for (const order of orders) {
    await client.query(
      `INSERT INTO orders (
         id,
         created_at,
         customer_name,
         customer_email,
         customer_address,
         notes,
         status,
         subtotal,
         shipping_cost,
         total
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
       ON CONFLICT (id) DO NOTHING`,
      [
        order.id,
        order.createdAt ? new Date(order.createdAt) : new Date(),
        order.customer?.name,
        order.customer?.email,
        order.customer?.address,
        order.notes || '',
        order.status || 'pending',
        Number(order.subtotal),
        Number(order.shippingCost),
        Number(order.total),
      ]
    );

    if (Array.isArray(order.items)) {
      for (const item of order.items) {
        await client.query(
          `INSERT INTO order_items (order_id, product_id, name, price, quantity, subtotal)
           VALUES ($1, $2, $3, $4, $5, $6)
           ON CONFLICT DO NOTHING`,
          [
            order.id,
            item.productId,
            item.name,
            Number(item.price),
            Number(item.quantity),
            Number(item.subtotal),
          ]
        );
      }
    }
  }
}

async function main() {
  const truncate = process.argv.includes('--truncate');
  const includeOrders = process.argv.includes('--with-orders');

  try {
    const products = await readJSON('products.json');
    const orders = includeOrders ? await readJSON('orders.json') : [];

    await withTransaction(async (client) => {
      await seedProducts(client, products, truncate);

      if (includeOrders && orders.length > 0) {
        await seedOrders(client, orders, truncate);
      }
    });

    console.log('Seed completado correctamente');
  } catch (error) {
    console.error('Fallo al ejecutar el seed', error);
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
}

main();
