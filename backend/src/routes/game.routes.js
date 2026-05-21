// ==========================================
// src/routes/game.routes.js
// ==========================================
// Endpoints de monedas + skins del jugador.
//
//   GET  /api/game/state       → { coins, ownedSkins }
//   POST /api/game/coins/sync  → { coins: <client>} → { coins: <max(client,server)> }
//   POST /api/game/skins/sync  → { ownedSkins: [] } → { ownedSkins: <union> }
//
// Todos autenticados (auth.middleware).

const express = require('express');
const rateLimit = require('express-rate-limit');
const controller = require('../controllers/game.controller');
const { authenticateToken } = require('../middlewares/auth.middleware');

const router = express.Router();

// Rate limit: el cliente sincroniza cada ~30s en uso normal. 60/min es
// un techo generoso pero corta el abuso (loop infinito tipo bug).
const syncLimiter = rateLimit({
    windowMs: 60 * 1000,
    max: 60,
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: 'Demasiadas sincronizaciones, espera unos segundos' },
});

router.get('/game/state', authenticateToken, controller.getState);
router.post('/game/coins/sync', authenticateToken, syncLimiter, controller.syncCoins);
router.post('/game/skins/sync', authenticateToken, syncLimiter, controller.syncSkins);

module.exports = router;
