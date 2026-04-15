const express = require('express');
const tripController = require('../controllers/trip.controller');
const { authenticateToken } = require('../middlewares/auth.middleware');

const router = express.Router();

router.get('/trips', authenticateToken, tripController.getTrips);
router.post('/trips', authenticateToken, tripController.createTrip);
router.delete('/trips/:id', authenticateToken, tripController.deleteTrip);
router.delete('/trips', authenticateToken, tripController.deleteAllTrips);

module.exports = router;
