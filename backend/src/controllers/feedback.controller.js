const fs = require('fs');
const feedbackService = require('../services/feedback.service');
const feedbackRepository = require('../repositories/feedback.repository');
const { resolveAttachmentPath } = require('../utils/feedbackUploads');

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
            // req.files lo rellena multer si el endpoint es multipart;
            // si es JSON normal viene como undefined → array vacío.
            const files = Array.isArray(req.files) ? req.files : [];
            const result = await feedbackService.userReply(
                req.params.id, req.user.email, req.body.message, files
            );
            res.status(201).json(result);
        } catch (err) { next(err); }
    }

    async markTicketRead(req, res, next) {
        try {
            const result = await feedbackService.markTicketReadByUser(req.params.id, req.user.email);
            res.json(result);
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
            const files = Array.isArray(req.files) ? req.files : [];
            const result = await feedbackService.adminReply(
                req.params.id, req.body.message, files
            );
            res.status(201).json(result);
        } catch (err) { next(err); }
    }

    async markTicketReadAdmin(req, res, next) {
        try {
            const result = await feedbackService.markTicketReadByAdmin(req.params.id);
            res.json(result);
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

    // Descarga un adjunto. Usuario o admin pueden pedirlo: si es usuario,
    // verificamos que sea dueño del ticket. Las cabeceras evitan que el
    // navegador interprete el archivo como HTML/JS aunque el atacante haya
    // conseguido subir algo raro.
    async downloadAttachment(req, res, next) {
        try {
            const att = await feedbackService.getAttachmentForDownload(req.params.attachmentId, {
                userEmail: req.user?.email,
                isAdmin: req.user?.role === 'admin',
            });

            const filePath = resolveAttachmentPath(att);
            if (!fs.existsSync(filePath)) {
                return res.status(410).json({ error: 'Archivo no disponible' });
            }

            res.setHeader('Content-Type', att.mime_type);
            res.setHeader('X-Content-Type-Options', 'nosniff');
            // inline para imágenes/PDFs (preview nativo), attachment para el resto.
            const inline = att.mime_type.startsWith('image/') || att.mime_type === 'application/pdf';
            const dispositionType = inline ? 'inline' : 'attachment';
            // Sanitiza el nombre original para Content-Disposition (sin saltos, sin comillas).
            const safeName = String(att.original_name).replace(/[\r\n"]/g, '_');
            res.setHeader(
                'Content-Disposition',
                `${dispositionType}; filename="${safeName}"`
            );
            fs.createReadStream(filePath).pipe(res);
        } catch (err) { next(err); }
    }
}

module.exports = new FeedbackController();
