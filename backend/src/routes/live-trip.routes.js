// ==========================================
// src/routes/live-trip.routes.js
// ==========================================
// Endpoints de "Compartir mi viaje en vivo".
//
// Endpoints autenticados (dueño del viaje):
//   POST   /api/live-trips            → inicia un viaje, devuelve shareUrl
//   POST   /api/live-trips/:id/ping   → actualiza posición GPS (cada ~30s)
//   POST   /api/live-trips/:id/end    → finaliza el viaje
//   GET    /api/live-trips/active     → mi viaje activo actual (o null)
//
// Endpoint público (sin auth, accedido por quien recibe el link):
//   GET    /api/live-trips/public/:shareToken → posición + ETA + estado

const express = require('express');
const rateLimit = require('express-rate-limit');
const controller = require('../controllers/live-trip.controller');
const { authenticateToken } = require('../middlewares/auth.middleware');

const router = express.Router();

// Rate limiter para el ping: 1 request cada 5s por IP. Es generoso porque
// la app envía 1 cada 30s en condiciones normales; el límite solo entra
// si alguien intenta spamear.
const pingLimiter = rateLimit({
    windowMs: 60 * 1000,
    max: 30, // 30 pings por minuto = 1 cada 2s en el peor caso
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: 'Demasiados pings, espera unos segundos' },
});

// Rate limiter para el endpoint público: 20 req/min por IP. El viewer hace
// polling cada 15s = 4/min, así que 20 deja margen para varios viewers
// detrás del mismo NAT (familia mirando desde casa).
const publicLimiter = rateLimit({
    windowMs: 60 * 1000,
    max: 20,
    standardHeaders: true,
    legacyHeaders: false,
});

// ─── Autenticadas (dueño) ────────────────────────────────────────────────
router.post('/live-trips', authenticateToken, controller.start);
router.post('/live-trips/:id/ping', authenticateToken, pingLimiter, controller.ping);
router.post('/live-trips/:id/end', authenticateToken, controller.end);
router.get('/live-trips/active', authenticateToken, controller.getMyActive);

// ─── Pública ─────────────────────────────────────────────────────────────
router.get('/live-trips/public/:shareToken', publicLimiter, controller.getPublic);

module.exports = router;
