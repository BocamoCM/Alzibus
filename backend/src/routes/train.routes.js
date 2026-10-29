const express = require('express');
const rateLimit = require('express-rate-limit');
const trainController = require('../controllers/train.controller');

// Endpoint público (lo usa la página estática /estacion-renfe/, que no lleva
// API key): limitado por IP para que nadie lo use de proxy gratis de Renfe.
const trainsLimiter = rateLimit({
    windowMs: 60 * 1000,
    max: 30,
    message: { error: 'Demasiadas peticiones. Inténtalo en un minuto.' },
});

const router = express.Router();

router.get('/trains/alzira', trainsLimiter, trainController.getAlziraDepartures);

module.exports = router;
