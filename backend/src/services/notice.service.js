const noticeRepository = require('../repositories/notice.repository');
const { NotFoundError, BadRequestError, ForbiddenError } = require('../utils/errors');

class NoticeService {
    async getActiveNotices(userEmail) {
        return await noticeRepository.getActiveNotices(userEmail);
    }

    async getUserMessages(noticeId, userEmail) {
        // El aviso puede ser:
        //   - Personal: target_email = email concreto → solo ese usuario.
        //   - General:  target_email = NULL → cualquier usuario.
        // En ambos casos getMessagesForNotice filtra por user_email para que
        // cada usuario vea solo su propio thread con el admin.
        const notice = await noticeRepository.getNoticeTargetEmail(noticeId);
        if (!notice) throw new NotFoundError('Aviso no encontrado o expirado');
        if (notice.target_email !== null && notice.target_email !== userEmail) {
            throw new ForbiddenError('No puedes ver los mensajes de este aviso');
        }

        // Marcar como leídos los mensajes admin de mi thread al abrir el chat
        // (fire-and-forget — si falla no rompe la consulta).
        noticeRepository.markRepliesRead(noticeId, userEmail)
            .catch(err => console.error('[Notices] markRepliesRead:', err));

        return await noticeRepository.getMessagesForNotice(noticeId, userEmail);
    }

    async userReply(noticeId, userEmail, message) {
        if (!message || message.trim().length === 0) throw new BadRequestError('El mensaje no puede estar vacío');

        const notice = await noticeRepository.getNoticeTargetEmail(noticeId);
        if (!notice) throw new NotFoundError('Aviso no encontrado o inactivo');
        // Personal: solo el destinatario puede responder.
        // General: cualquier usuario autenticado puede preguntar.
        if (notice.target_email !== null && notice.target_email !== userEmail) {
            throw new ForbiddenError('No puedes responder a este aviso');
        }

        const reply = await noticeRepository.addReply(noticeId, userEmail, message.trim(), 'user');
        console.log(`[Notices] 💬 Respuesta de ${userEmail} al aviso #${noticeId}`);
        return reply;
    }

    // Marca el aviso como visto por el usuario (la primera vez crea fila,
    // las siguientes no hacen nada). Idempotente.
    async markNoticeRead(noticeId, userEmail) {
        // Validamos que el aviso existe y es visible para este usuario.
        const notice = await noticeRepository.getNoticeTargetEmail(noticeId);
        if (!notice) throw new NotFoundError('Aviso no encontrado');
        if (notice.target_email !== null && notice.target_email !== userEmail) {
            throw new ForbiddenError('No puedes acceder a este aviso');
        }
        await noticeRepository.markNoticeRead(noticeId, userEmail);
        return { ok: true };
    }

    async getNoticeReadersAdmin(noticeId) {
        return await noticeRepository.getNoticeReaders(noticeId);
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

    async adminReply(noticeId, message, targetUserEmail = null) {
        if (!message || message.trim().length === 0) throw new BadRequestError('El mensaje no puede estar vacío');

        const notice = await noticeRepository.getNoticeById(noticeId);
        if (!notice) throw new NotFoundError('Aviso no encontrado');

        // Determinar a qué thread va dirigida la respuesta:
        //   - Aviso PERSONAL: notice.target_email es fijo, no se puede cambiar.
        //   - Aviso GENERAL:  el admin tiene que especificar a qué usuario
        //     responde (targetUserEmail). Si no, no sabemos en qué thread
        //     poner el mensaje.
        let threadUser;
        if (notice.target_email) {
            threadUser = notice.target_email;
        } else if (targetUserEmail) {
            threadUser = targetUserEmail;
        } else {
            throw new BadRequestError('En avisos generales hay que indicar a qué usuario responder');
        }

        const reply = await noticeRepository.addReply(noticeId, threadUser, message.trim(), 'admin');

        // Al responder, asumimos que el admin ya ha leído todo lo que el
        // usuario escribió en este thread (fire-and-forget).
        noticeRepository.markUserRepliesReadByAdmin(noticeId, threadUser)
            .catch(err => console.error('[Notices] markUserRepliesReadByAdmin:', err));

        console.log(`[Notices] 💬 Admin respondió al aviso #${noticeId} (thread ${threadUser})`);
        return reply;
    }
}

module.exports = new NoticeService();
