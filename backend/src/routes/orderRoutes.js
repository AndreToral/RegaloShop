const express = require('express');
const { getOrders, postOrder } = require('../controllers/orderController');

const router = express.Router();

router.get('/', getOrders);
router.post('/', postOrder);

module.exports = router;
