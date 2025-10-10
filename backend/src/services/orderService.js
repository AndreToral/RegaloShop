const { v4: uuid } = require('uuid');
const { withTransaction, query } = require('../db/pool');

function normalizeMoney(value) {
  return Number(Number(value).toFixed(2));
}

function validateCustomer(customer = {}) {
  const requiredFields = ['name', 'email', 'address'];
  for (const field of requiredFields) {
    if (!customer[field] || typeof customer[field] !== 'string') {
      throw new Error(`Falta informacion del cliente: ${field}`);
    }
  }
}

function validateItems(items) {
  if (!Array.isArray(items) || items.length === 0) {
    throw new Error('La orden debe incluir al menos un producto.');
  }

  for (const item of items) {
    if (!item.productId || typeof item.productId !== 'string') {
      throw new Error('Cada articulo debe incluir un productId valido.');
    }

    if (!Number.isInteger(item.quantity) || item.quantity <= 0) {
      throw new Error('La cantidad debe ser un entero positivo.');
    }
  }
}

async function createOrder({ customer, items, notes }) {
  validateCustomer(customer);
  validateItems(items);

  return withTransaction(async (client) => {
    const productIds = [...new Set(items.map((item) => item.productId))];
    const quantityByProduct = items.reduce((acc, item) => {
      const current = acc.get(item.productId) || 0;
      acc.set(item.productId, current + item.quantity);
      return acc;
    }, new Map());

    const { rows: productRows } = await client.query(
      `SELECT id, name, price, stock
         FROM products
        WHERE id = ANY($1::text[])
        FOR UPDATE`,
      [productIds]
    );

    const productMap = new Map(productRows.map((row) => [row.id, row]));

    const detailedItems = items.map((item) => {
      const product = productMap.get(item.productId);
      if (!product) {
        throw new Error(`Producto no encontrado: ${item.productId}`);
      }

      const requested = quantityByProduct.get(item.productId) || 0;
      const stock = Number(product.stock);
      if (stock < requested) {
        throw new Error(`Stock insuficiente para: ${product.name}`);
      }

      const price = Number(product.price);
      const subtotal = normalizeMoney(price * item.quantity);

      return {
        productId: product.id,
        name: product.name,
        price,
        quantity: item.quantity,
        subtotal,
      };
    });

    for (const [productId, requested] of quantityByProduct.entries()) {
      const product = productMap.get(productId);
      const updateResult = await client.query(
        `UPDATE products
            SET stock = stock - $1,
                updated_at = NOW()
          WHERE id = $2 AND stock >= $1`,
        [requested, productId]
      );

      if (updateResult.rowCount === 0) {
        throw new Error(`Stock insuficiente para: ${product ? product.name : productId}`);
      }
    }

    const subtotal = normalizeMoney(
      detailedItems.reduce((acc, current) => acc + current.subtotal, 0)
    );
    const shippingCost = subtotal >= 80 ? 0 : 6.99;
    const total = normalizeMoney(subtotal + shippingCost);

    const orderId = uuid();
    const createdAt = new Date();

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
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
      [
        orderId,
        createdAt,
        customer.name,
        customer.email,
        customer.address,
        notes || '',
        'pending',
        subtotal,
        shippingCost,
        total,
      ]
    );

    for (const item of detailedItems) {
      await client.query(
        `INSERT INTO order_items (
           order_id,
           product_id,
           name,
           price,
           quantity,
           subtotal
         ) VALUES ($1, $2, $3, $4, $5, $6)`,
        [
          orderId,
          item.productId,
          item.name,
          item.price,
          item.quantity,
          item.subtotal,
        ]
      );
    }

    return {
      id: orderId,
      createdAt: createdAt.toISOString(),
      customer,
      items: detailedItems,
      subtotal,
      shippingCost,
      total,
      notes: notes || '',
      status: 'pending',
    };
  });
}

async function listOrders() {
  const { rows: orderRows } = await query(
    `SELECT id,
            created_at,
            customer_name,
            customer_email,
            customer_address,
            notes,
            status,
            subtotal,
            shipping_cost,
            total
       FROM orders
      ORDER BY created_at DESC`
  );

  if (orderRows.length === 0) {
    return [];
  }

  const orderIds = orderRows.map((row) => row.id);

  const { rows: itemRows } = await query(
    `SELECT order_id,
            product_id,
            name,
            price,
            quantity,
            subtotal
       FROM order_items
      WHERE order_id = ANY($1::uuid[])
      ORDER BY id ASC`,
    [orderIds]
  );

  const itemsByOrder = itemRows.reduce((acc, row) => {
    if (!acc.has(row.order_id)) {
      acc.set(row.order_id, []);
    }
    acc.get(row.order_id).push({
      productId: row.product_id,
      name: row.name,
      price: Number(row.price),
      quantity: Number(row.quantity),
      subtotal: Number(row.subtotal),
    });
    return acc;
  }, new Map());

  return orderRows.map((row) => ({
    id: row.id,
    createdAt:
      row.created_at instanceof Date
        ? row.created_at.toISOString()
        : new Date(row.created_at).toISOString(),
    customer: {
      name: row.customer_name,
      email: row.customer_email,
      address: row.customer_address,
    },
    items: itemsByOrder.get(row.id) || [],
    subtotal: Number(row.subtotal),
    shippingCost: Number(row.shipping_cost),
    total: Number(row.total),
    notes: row.notes || '',
    status: row.status,
  }));
}

module.exports = {
  createOrder,
  listOrders,
};
