const { createOrder, listOrders } = require('../services/orderService');

async function getOrders(req, res, next) {
  try {
    const orders = await listOrders();
    res.json(orders);
  } catch (error) {
    next(error);
  }
}

async function postOrder(req, res, next) {
  try {
    const order = await createOrder(req.body);
    res.status(201).json(order);
  } catch (error) {
    next(error);
  }
}

module.exports = {
  getOrders,
  postOrder,
};

