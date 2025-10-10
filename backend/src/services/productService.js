const { getExecutor, query } = require('../db/pool');

function mapProductRow(row) {
  if (!row) {
    return null;
  }

  return {
    id: row.id,
    name: row.name,
    description: row.description,
    category: row.category,
    price: Number(row.price),
    stock: Number(row.stock),
    image: row.image,
    tags: row.tags || [],
  };
}

async function listProducts({ category, search, sort, minPrice, maxPrice } = {}) {
  const filters = [];
  const values = [];

  if (category) {
    values.push(category);
    filters.push(`LOWER(category) = LOWER($${values.length})`);
  }

  if (search) {
    values.push(`%${search}%`);
    const placeholder = `$${values.length}`;
    filters.push(
      `(
        name ILIKE ${placeholder}
        OR description ILIKE ${placeholder}
        OR EXISTS (
          SELECT 1 FROM unnest(COALESCE(tags, ARRAY[]::text[])) AS tag WHERE tag ILIKE ${placeholder}
        )
      )`
    );
  }

  if (minPrice !== undefined) {
    values.push(Number(minPrice));
    filters.push(`price >= $${values.length}`);
  }

  if (maxPrice !== undefined) {
    values.push(Number(maxPrice));
    filters.push(`price <= $${values.length}`);
  }

  let orderBy = 'ORDER BY name ASC';
  if (sort === 'price-asc') {
    orderBy = 'ORDER BY price ASC, name ASC';
  } else if (sort === 'price-desc') {
    orderBy = 'ORDER BY price DESC, name ASC';
  } else if (sort === 'stock-desc') {
    orderBy = 'ORDER BY stock DESC, name ASC';
  }

  const whereClause = filters.length ? `WHERE ${filters.join(' AND ')}` : '';

  const productsQuery = `
    SELECT id, name, description, category, price, stock, image, tags
    FROM products
    ${whereClause}
    ${orderBy}
  `;

  const { rows } = await query(productsQuery, values);
  return rows.map(mapProductRow);
}

async function listCategories() {
  const { rows } = await query(
    'SELECT DISTINCT category FROM products ORDER BY category ASC'
  );
  return rows.map((row) => row.category);
}

async function findProductById(id, client) {
  const executor = getExecutor(client);
  const { rows } = await executor.query(
    `SELECT id, name, description, category, price, stock, image, tags
     FROM products
     WHERE id = $1`,
    [id]
  );

  return mapProductRow(rows[0]);
}

async function decrementStock(orderItems, client) {
  const executor = getExecutor(client);

  for (const item of orderItems) {
    const result = await executor.query(
      `UPDATE products
         SET stock = stock - $1,
             updated_at = NOW()
       WHERE id = $2 AND stock >= $1`,
      [item.quantity, item.productId]
    );

    if (result.rowCount === 0) {
      throw new Error(`Stock insuficiente para: ${item.productId}`);
    }
  }
}

module.exports = {
  listProducts,
  listCategories,
  findProductById,
  decrementStock,
};

