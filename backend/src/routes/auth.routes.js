const express = require('express');
const authController = require('../controllers/auth.controller');
const rateLimit = require('express-rate-limit');

// Whitelist de IPs que NUNCA tocan el rate limit. Útil para pruebas desde
// la IP del admin o de localhost durante desarrollo. Configurable vía .env:
//
//   RATE_LIMIT_WHITELIST=82.45.12.34,127.0.0.1,::1
//
// Soporta IPv4 e IPv6 literales. La detección de IP real funciona porque
// server.js ya tiene app.set('trust proxy', 1) — req.ip lee X-Forwarded-For
// del proxy (Caddy).
const WHITELIST = new Set(
    (process.env.RATE_LIMIT_WHITELIST || '')
        .split(',')
        .map(s => s.trim())
        .filter(Boolean)
);
function isWhitelisted(req) {
    return WHITELIST.has(req.ip);
}
if (WHITELIST.size > 0) {
    console.log(`[auth] Rate limit bypass para IPs: ${[...WHITELIST].join(', ')}`);
}

// Middlewares locales para limitar el tráfico (extraídos del monolito de server.js)
const registerLimiter = rateLimit({
    windowMs: 60 * 60 * 1000,
    max: 5,
    skip: isWhitelisted,
    message: { error: 'Demasiados intentos de registro. Intenta de nuevo en 1 hora.' }
});

const loginLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 10,
    skip: isWhitelisted,
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
