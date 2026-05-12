const express = require('express');
const feedbackController = require('../controllers/feedback.controller');
const { authenticateToken, authenticateAdmin } = require('../middlewares/auth.middleware');
const { upload, MAX_FILES_PER_REQUEST } = require('../utils/feedbackUploads');

const router = express.Router();

// Wrap multer.array para que los errores (tamaño, número de archivos, MIME
// no permitido) lleguen al error handler de Express como 400 en vez de 500.
function attachmentsMiddleware(req, res, next) {
    upload.array('attachments', MAX_FILES_PER_REQUEST)(req, res, (err) => {
        if (err) {
            const msg = err.code === 'LIMIT_FILE_SIZE'
                ? 'Archivo demasiado grande (máx 5 MB)'
                : err.code === 'LIMIT_FILE_COUNT'
                    ? `Demasiados archivos (máx ${MAX_FILES_PER_REQUEST})`
                    : err.message;
            return res.status(400).json({ error: msg });
        }
        next();
    });
}

router.get('/feedback', authenticateToken, feedbackController.getUserTickets);
router.post('/feedback', authenticateToken, feedbackController.createTicket);
router.get('/feedback/:id/messages', authenticateToken, feedbackController.getTicketMessages);
router.post('/feedback/:id/reply', authenticateToken, attachmentsMiddleware, feedbackController.userReply);
router.post('/feedback/:id/read', authenticateToken, feedbackController.markTicketRead);

router.get('/admin/feedback', authenticateAdmin, feedbackController.getAllTicketsAdmin);
router.post('/admin/feedback/:id/reply', authenticateAdmin, attachmentsMiddleware, feedbackController.adminReply);
router.post('/admin/feedback/:id/read', authenticateAdmin, feedbackController.markTicketReadAdmin);
router.put('/admin/feedback/:id/status', authenticateAdmin, feedbackController.updateStatusAdmin);
router.get('/admin/feedback/:id/replies', authenticateAdmin, feedbackController.getTicketRepliesAdmin);
// Edit / delete de mensajes del propio admin. Los mensajes del usuario son
// inmutables (protegido en el service).
router.patch('/admin/feedback/replies/:replyId', authenticateAdmin, feedbackController.editAdminReply);
router.delete('/admin/feedback/replies/:replyId', authenticateAdmin, feedbackController.deleteAdminReply);

// Descarga de adjuntos. El handler decide permisos en función del rol
// (admin = acceso a todo; user = solo a sus tickets). Usamos optionalToken
// con verificación dentro del service en lugar de dos endpoints separados
// para no duplicar /api/admin/feedback/attachments/:id.
router.get('/feedback/attachments/:attachmentId', authenticateToken, feedbackController.downloadAttachment);
router.get('/admin/feedback/attachments/:attachmentId', authenticateAdmin, feedbackController.downloadAttachment);

module.exports = router;
