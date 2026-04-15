const noticeService = require('../services/notice.service');

class NoticeController {
    async getNotices(req, res, next) {
        try {
            const result = await noticeService.getActiveNotices(req.user?.email || null);
            res.json(result);
        } catch (err) { next(err); }
    }

    async getMessages(req, res, next) {
        try {
            const result = await noticeService.getUserMessages(req.params.id, req.user.email);
            res.json(result);
        } catch (err) { next(err); }
    }

    async replyToNotice(req, res, next) {
        try {
            const result = await noticeService.userReply(req.params.id, req.user.email, req.body.message);
            res.status(201).json(result);
        } catch (err) { next(err); }
    }

    // Admin endpoints
    async getAllNoticesAdmin(req, res, next) {
        try {
            const result = await noticeService.getAllNoticesAdmin();
            res.json(result);
        } catch (err) { next(err); }
    }

    async createNoticeAdmin(req, res, next) {
        try {
            const result = await noticeService.createNoticeAdmin(req.body);
            // El controller emite el websocket
            const io = req.app.get('io');
            if (io) io.emit('new_notice', result);
            res.status(201).json(result);
        } catch (err) { next(err); }
    }

    async deleteNoticeAdmin(req, res, next) {
        try {
            await noticeService.deleteNoticeAdmin(req.params.id);
            res.json({ message: 'Aviso eliminado' });
        } catch (err) { next(err); }
    }

    async getNoticeRepliesAdmin(req, res, next) {
        try {
            const result = await noticeService.getNoticeRepliesAdmin(req.params.id);
            res.json(result);
        } catch (err) { next(err); }
    }

    async adminReplyToNotice(req, res, next) {
        try {
            const result = await noticeService.adminReply(req.params.id, req.body.message);
            res.status(201).json(result);
        } catch (err) { next(err); }
    }
}

module.exports = new NoticeController();
