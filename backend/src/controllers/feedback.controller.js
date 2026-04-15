const feedbackService = require('../services/feedback.service');

class FeedbackController {
    async getUserTickets(req, res, next) {
        try {
            const result = await feedbackService.getUserTickets(req.user.email);
            res.json(result);
        } catch (err) { next(err); }
    }

    async createTicket(req, res, next) {
        try {
            const result = await feedbackService.createTicket(req.user.email, req.body);
            res.status(201).json(result);
        } catch (err) { next(err); }
    }

    async getTicketMessages(req, res, next) {
        try {
            const result = await feedbackService.getTicketMessages(req.params.id, req.user.email);
            res.json(result);
        } catch (err) { next(err); }
    }

    async userReply(req, res, next) {
        try {
            const result = await feedbackService.userReply(req.params.id, req.user.email, req.body.message);
            res.status(201).json(result);
        } catch (err) { next(err); }
    }

    async getAllTicketsAdmin(req, res, next) {
        try {
            const result = await feedbackService.getAllTicketsAdmin();
            res.json(result);
        } catch (err) { next(err); }
    }

    async adminReply(req, res, next) {
        try {
            const result = await feedbackService.adminReply(req.params.id, req.body.message);
            res.status(201).json(result);
        } catch (err) { next(err); }
    }

    async updateStatusAdmin(req, res, next) {
        try {
            const result = await feedbackService.updateStatusAdmin(req.params.id, req.body.status);
            res.json(result);
        } catch (err) { next(err); }
    }

    async getTicketRepliesAdmin(req, res, next) {
        try {
            const result = await feedbackService.getTicketRepliesAdmin(req.params.id);
            res.json(result);
        } catch (err) { next(err); }
    }
}

module.exports = new FeedbackController();
