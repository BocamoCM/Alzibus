const express = require('express');
const authController = require('../controllers/auth.controller');
const rateLimit = require('express-rate-limit');

// Middlewares locales para limitar el tráfico (extraídos del monolito de server.js)
const registerLimiter = rateLimit({
    windowMs: 60 * 60 * 1000, 
    max: 5, 
    message: { error: 'Demasiados intentos de registro. Intenta de nuevo en 1 hora.' }
});

const loginLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 10,
    message: { error: 'Demasiados intentos de inicio de sesión. Reinténtalo en 15 minutos.' }
});

const router = express.Router();

// ── Rutas Mapeadas a Controladores ──

router.post('/register', registerLimiter, authController.register);
router.post('/verify-email', authController.verifyEmail);
router.post('/login', loginLimiter, authController.login);
router.post('/login/verify', loginLimiter, authController.verifyLogin);
router.post('/resend-otp', registerLimiter, authController.resendOtp);
router.post('/forgot-password', registerLimiter, authController.forgotPassword);
router.post('/reset-password', registerLimiter, authController.resetPassword);

// Administrador
router.post('/admin/login', loginLimiter, authController.adminLogin);

module.exports = router;
