const express = require('express');
const stopController = require('../controllers/stop.controller');
const { authenticateAdmin } = require('../middlewares/auth.middleware');

const router = express.Router();

router.get('/stops', stopController.getAllStops);
router.post('/stops', authenticateAdmin, stopController.createStop);
router.put('/stops/:id', authenticateAdmin, stopController.updateStop);
router.delete('/stops/:id', authenticateAdmin, stopController.deleteStop);

module.exports = router;
