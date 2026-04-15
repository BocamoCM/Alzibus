const express = require('express');
const feedbackController = require('../controllers/feedback.controller');
const { authenticateToken, authenticateAdmin } = require('../middlewares/auth.middleware');

const router = express.Router();

router.get('/feedback', authenticateToken, feedbackController.getUserTickets);
router.post('/feedback', authenticateToken, feedbackController.createTicket);
router.get('/feedback/:id/messages', authenticateToken, feedbackController.getTicketMessages);
router.post('/feedback/:id/reply', authenticateToken, feedbackController.userReply);

router.get('/admin/feedback', authenticateAdmin, feedbackController.getAllTicketsAdmin);
router.post('/admin/feedback/:id/reply', authenticateAdmin, feedbackController.adminReply);
router.put('/admin/feedback/:id/status', authenticateAdmin, feedbackController.updateStatusAdmin);
router.get('/admin/feedback/:id/replies', authenticateAdmin, feedbackController.getTicketRepliesAdmin);

module.exports = router;
