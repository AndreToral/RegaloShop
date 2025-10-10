const express = require('express');
const { getCategories } = require('../controllers/productController');

const router = express.Router();

router.get('/', getCategories);

module.exports = router;
