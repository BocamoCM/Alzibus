const express = require('express');
const statController = require('../controllers/stat.controller');
const { authenticateAdmin, optionalToken } = require('../middlewares/auth.middleware');
const rateLimit = require('express-rate-limit');

const router = express.Router();

// Whitelist (compartida vía .env con auth.routes.js).
const WHITELIST = new Set(
    (process.env.RATE_LIMIT_WHITELIST || '')
        .split(',').map(s => s.trim()).filter(Boolean)
);
const isWhitelisted = (req) => {
    if (WHITELIST.has('*')) return true;
    return WHITELIST.has(req.ip);
};

const contactLimiter = rateLimit({ windowMs: 60 * 60 * 1000, max: 2, skip: isWhitelisted, message: { error: 'Límite alcanzado' } });
const metricsLimiter = rateLimit({ windowMs: 5 * 60 * 1000, max: 2, skip: isWhitelisted, message: { error: 'Límite alcanzado' } });

// Admin Stats
router.get('/stats', authenticateAdmin, statController.getGeneralStats);
router.get('/stats/usage', authenticateAdmin, statController.getUsageStats);
router.get('/stats/activity', authenticateAdmin, statController.getActivityStats);
router.get('/stats/top-stops', authenticateAdmin, statController.getTopStops);
router.get('/stats/peak-hours', authenticateAdmin, statController.getPeakHours);
router.get('/stats/dashboard', authenticateAdmin, statController.getDashboard);
router.get('/stats/telemetry', authenticateAdmin, statController.getTelemetry);

// Admin Stats v2 (métricas nuevas)
router.get('/stats/retention', authenticateAdmin, statController.getRetention);
router.get('/stats/heatmap', authenticateAdmin, statController.getHeatmap);
router.get('/stats/payments', authenticateAdmin, statController.getPayments);
router.get('/stats/routes', authenticateAdmin, statController.getRoutes);
router.get('/stats/premium', authenticateAdmin, statController.getPremium);
router.get('/stats/game', authenticateAdmin, statController.getGame);
router.get('/stats/live-share', authenticateAdmin, statController.getLiveShare);
router.get('/stats/support', authenticateAdmin, statController.getSupport);
router.get('/stats/web-app', authenticateAdmin, statController.getWebApp);
router.get('/stats/revenue', authenticateAdmin, statController.getRevenue);
router.get('/stats/versions', authenticateAdmin, statController.getVersions);

// Público para la app: última versión / mínima soportada (para el aviso de actualizar)
router.get('/app/version', statController.getAppVersion);

// Public / Mobile Stats and Metrics
router.get('/stats/public', statController.getPublicStats);
router.post('/stats/log-alert', statController.logAlert);
router.post('/metrics/web', statController.logWebMetric);
router.post('/metrics/install', statController.logInstall);
router.post('/metrics/app-open', metricsLimiter, optionalToken, statController.logAppOpen);

// Contact
router.post('/contact', contactLimiter, statController.postContact);

module.exports = router;
