const express = require('express');
const noticeController = require('../controllers/notice.controller');
const { authenticateToken, authenticateAdmin, optionalToken } = require('../middlewares/auth.middleware');

const router = express.Router();

// ── Rutas Públicas / Móviles ──
// Soporta optionalToken porque si hay usuario le enseñamos sus avisos, sino los públicos.
router.get('/notices', optionalToken, noticeController.getNotices);
router.get('/notices/:id/messages', authenticateToken, noticeController.getMessages);
router.post('/notices/:id/reply', authenticateToken, noticeController.replyToNotice);
// Marca el aviso como leído por el usuario (idempotente). Se llama al
// abrir el aviso en la app — sirve para que el admin vea quién lo ha visto.
router.post('/notices/:id/read', authenticateToken, noticeController.markNoticeRead);

// ── Rutas de Administración ──
router.get('/admin/notices', authenticateAdmin, noticeController.getAllNoticesAdmin);
router.post('/admin/notices', authenticateAdmin, noticeController.createNoticeAdmin);
router.delete('/admin/notices/:id', authenticateAdmin, noticeController.deleteNoticeAdmin);
router.get('/admin/notices/:id/replies', authenticateAdmin, noticeController.getNoticeRepliesAdmin);
router.post('/admin/notices/:id/reply', authenticateAdmin, noticeController.adminReplyToNotice);
// Lista de usuarios que han marcado el aviso como leído.
router.get('/admin/notices/:id/readers', authenticateAdmin, noticeController.getNoticeReadersAdmin);

module.exports = router;
