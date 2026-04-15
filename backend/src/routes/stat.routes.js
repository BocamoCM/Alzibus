const express = require('express');
const statController = require('../controllers/stat.controller');
const { authenticateAdmin, optionalToken } = require('../middlewares/auth.middleware');
const rateLimit = require('express-rate-limit');

const router = express.Router();

const contactLimiter = rateLimit({ windowMs: 60 * 60 * 1000, max: 2, message: { error: 'Límite alcanzado' } });
const metricsLimiter = rateLimit({ windowMs: 5 * 60 * 1000, max: 2, message: { error: 'Límite alcanzado' } });

// Admin Stats
router.get('/stats', authenticateAdmin, statController.getGeneralStats);
router.get('/stats/usage', authenticateAdmin, statController.getUsageStats);
router.get('/stats/activity', authenticateAdmin, statController.getActivityStats);
router.get('/stats/top-stops', authenticateAdmin, statController.getTopStops);
router.get('/stats/peak-hours', authenticateAdmin, statController.getPeakHours);
router.get('/stats/dashboard', authenticateAdmin, statController.getDashboard);

// Public / Mobile Stats and Metrics
router.get('/stats/public', statController.getPublicStats);
router.post('/stats/log-alert', statController.logAlert);
router.post('/metrics/web', statController.logWebMetric);
router.post('/metrics/install', statController.logInstall);
router.post('/metrics/app-open', metricsLimiter, optionalToken, statController.logAppOpen);

// Contact
router.post('/contact', contactLimiter, statController.postContact);

module.exports = router;
