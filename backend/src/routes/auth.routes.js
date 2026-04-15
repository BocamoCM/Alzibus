const express = require('express');
const authController = require('../controllers/auth.controller');
const rateLimit = require('express-rate-limit');

// Middlewares locales para limitar el tráfico (extraídos del monolito de server.js)
const registerLimiter = rateLimit({
    windowMs: 60 * 60 * 1000, 
    max: 5, 
    message: { error: 'Demasiados intentos de registro. Intenta de nuevo en 1 hora.' }
});

const router = express.Router();

// ── Rutas Mapeadas a Controladores ──

router.post('/register', registerLimiter, authController.register);
router.post('/verify-email', authController.verifyEmail);

// Resto de rutas se agregarán según se vayan migrando...
// router.post('/login', loginLimiter, authController.login);
// router.post('/resend-otp', registerLimiter, authController.resendOtp);

module.exports = router;
