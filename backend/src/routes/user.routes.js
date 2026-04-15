const express = require('express');
const userController = require('../controllers/user.controller');
const { authenticateToken, authenticateAdmin } = require('../middlewares/auth.middleware');

const router = express.Router();

// ── Rutas de Usuario (Requieren Token) ──
router.post('/users/heartbeat', authenticateToken, userController.heartbeat);
router.post('/users/logout', authenticateToken, userController.logout);
router.get('/users/profile', authenticateToken, userController.getProfile);
router.put('/users/profile', authenticateToken, userController.updateEmail);
router.put('/users/password', authenticateToken, userController.updatePassword);
router.delete('/users/profile', authenticateToken, userController.deleteProfile);

// Ranking
router.get('/ranking', authenticateToken, userController.getRanking);

// ── Rutas de Admin (Requieren Admin Token) ──
router.get('/admin/active-users', authenticateAdmin, userController.getActiveUsers);
router.get('/admin/users', authenticateAdmin, userController.getAllUsers);
router.get('/admin/users/emails', authenticateAdmin, userController.getAllUserEmails);

module.exports = router;
