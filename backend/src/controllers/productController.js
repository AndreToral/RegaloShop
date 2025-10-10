const {
  listProducts,
  findProductById,
  listCategories,
} = require('../services/productService');

async function getProducts(req, res, next) {
  try {
    const { category, search, sort, minPrice, maxPrice } = req.query;
    const products = await listProducts({ category, search, sort, minPrice, maxPrice });
    res.json(products);
  } catch (error) {
    next(error);
  }
}

async function getProductById(req, res, next) {
  try {
    const product = await findProductById(req.params.id);
    if (!product) {
      return res.status(404).json({ message: 'Producto no encontrado' });
    }
    res.json(product);
  } catch (error) {
    next(error);
  }
}

async function getCategories(req, res, next) {
  try {
    const categories = await listCategories();
    res.json(categories);
  } catch (error) {
    next(error);
  }
}

module.exports = {
  getProducts,
  getProductById,
  getCategories,
};

