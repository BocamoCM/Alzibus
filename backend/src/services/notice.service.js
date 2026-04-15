const noticeRepository = require('../repositories/notice.repository');
const { NotFoundError, BadRequestError, ForbiddenError } = require('../utils/errors');

class NoticeService {
    async getActiveNotices(userEmail) {
        return await noticeRepository.getActiveNotices(userEmail);
    }

    async getUserMessages(noticeId, userEmail) {
        const notice = await noticeRepository.getNoticeTargetEmail(noticeId);
        if (!notice) throw new NotFoundError('Aviso no encontrado o expirado');
        if (notice.target_email !== userEmail) throw new ForbiddenError('No puedes ver los mensajes de este aviso');

        return await noticeRepository.getMessagesForNotice(noticeId);
    }

    async userReply(noticeId, userEmail, message) {
        if (!message || message.trim().length === 0) throw new BadRequestError('El mensaje no puede estar vacío');

        const notice = await noticeRepository.getNoticeTargetEmail(noticeId);
        if (!notice) throw new NotFoundError('Aviso no encontrado o inactivo');
        if (notice.target_email !== userEmail) throw new ForbiddenError('No puedes responder a este aviso');

        const reply = await noticeRepository.addReply(noticeId, userEmail, message.trim(), 'user');
        console.log(`[Notices] 💬 Respuesta de ${userEmail} al aviso #${noticeId}`);
        return reply;
    }

    async getAllNoticesAdmin() {
        return await noticeRepository.getAllNoticesAdmin();
    }

    async createNoticeAdmin(data) {
        if (!data.title || !data.body) throw new BadRequestError('Título y cuerpo requeridos');
        // Aquí no emitimos socket directamente para no acoplar. El controller debe hacerlo.
        return await noticeRepository.createNoticeAdmin(data);
    }

    async deleteNoticeAdmin(noticeId) {
        await noticeRepository.deleteNoticeAdmin(noticeId);
    }

    async getNoticeRepliesAdmin(noticeId) {
        return await noticeRepository.getNoticeRepliesAdmin(noticeId);
    }

    async adminReply(noticeId, message) {
        if (!message || message.trim().length === 0) throw new BadRequestError('El mensaje no puede estar vacío');

        const notice = await noticeRepository.getNoticeById(noticeId);
        if (!notice) throw new NotFoundError('Aviso no encontrado');

        const reply = await noticeRepository.addReply(noticeId, notice.target_email || 'admin', message.trim(), 'admin');
        console.log(`[Notices] 💬 Admin respondió al aviso #${noticeId}`);
        return reply;
    }
}

module.exports = new NoticeService();
