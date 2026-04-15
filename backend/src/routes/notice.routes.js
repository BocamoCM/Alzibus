const express = require('express');
const noticeController = require('../controllers/notice.controller');
const { authenticateToken, authenticateAdmin, optionalToken } = require('../middlewares/auth.middleware');

const router = express.Router();

// ── Rutas Públicas / Móviles ──
// Soporta optionalToken porque si hay usuario le enseñamos sus avisos, sino los públicos.
router.get('/notices', optionalToken, noticeController.getNotices);
router.get('/notices/:id/messages', authenticateToken, noticeController.getMessages);
router.post('/notices/:id/reply', authenticateToken, noticeController.replyToNotice);

// ── Rutas de Administración ──
router.get('/admin/notices', authenticateAdmin, noticeController.getAllNoticesAdmin);
router.post('/admin/notices', authenticateAdmin, noticeController.createNoticeAdmin);
router.delete('/admin/notices/:id', authenticateAdmin, noticeController.deleteNoticeAdmin);
router.get('/admin/notices/:id/replies', authenticateAdmin, noticeController.getNoticeRepliesAdmin);
router.post('/admin/notices/:id/reply', authenticateAdmin, noticeController.adminReplyToNotice);

module.exports = router;
