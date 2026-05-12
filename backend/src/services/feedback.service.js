const fs = require('fs');
const feedbackRepository = require('../repositories/feedback.repository');
const { sendDiscordNotification } = require('../../utils/discord');
const { NotFoundError, BadRequestError, ForbiddenError } = require('../utils/errors');
const { persistAttachment, resolveAttachmentPath } = require('../utils/feedbackUploads');

// Canonicalización de estados. Hasta ahora la BD tenía mezcla: algunos
// tickets con valores en español ('Abierto', 'En progreso'...) que vienen
// del DEFAULT de init.sql, y otros en inglés ('open', 'in_progress'...)
// que vienen de las transiciones automáticas (admin responde → 'in_progress').
//
// A partir de ahora: el código canónico es siempre en INGLÉS y en snake_case.
// El servicio acepta tanto la etiqueta en español como el código en inglés
// para no romper APKs antiguas ni el admin panel sin recompilar, pero
// SIEMPRE persiste el código en inglés.
const STATUS_ALIASES = {
    // Canonical
    'open':        'open',
    'in_progress': 'in_progress',
    'resolved':    'resolved',
    'dismissed':   'dismissed',
    // Aliases en español que usaba el dropdown del admin panel.
    'Abierto':      'open',
    'En progreso':  'in_progress',
    'Resuelto':     'resolved',
    'Desestimado':  'dismissed',
    'Cerrado':      'dismissed', // alias antiguo, mapeo a dismissed
    // Alias de inglés que puede aparecer en BD por reglas anteriores.
    'closed':       'dismissed',
};

function normalizeStatus(input) {
    return STATUS_ALIASES[input] || null;
}

class FeedbackService {
    async getUserTickets(userEmail) {
        return await feedbackRepository.getUserTickets(userEmail);
    }

    async createTicket(userEmail, data) {
        const { tag, title, description } = data;
        if (!tag || !title || !description) throw new BadRequestError('Faltan campos obligatorios');

        const ticket = await feedbackRepository.createTicket(userEmail, tag, title, description);

        sendDiscordNotification({
            embeds: [{
                title: `🎫 Nuevo Ticket de Soporte: ${tag}`,
                description: `**Asunto:** ${title}\n\n${description}`,
                color: 0xE67E22,
                fields: [
                    { name: 'Usuario', value: userEmail, inline: true },
                    { name: 'ID Ticket', value: ticket.id.toString(), inline: true }
                ]
            }]
        });

        return ticket;
    }

    async getTicketMessages(ticketId, userEmail) {
        const ticket = await feedbackRepository.getTicketById(ticketId);
        if (!ticket) throw new NotFoundError('Ticket no encontrado');
        if (ticket.user_email !== userEmail) throw new ForbiddenError('No puedes ver los mensajes de este ticket');

        // Al consultar mensajes, el usuario está "viendo" el chat → marcamos
        // como leídos los mensajes del admin. No esperamos al UPDATE: si
        // falla, el siguiente fetch lo intentará otra vez.
        feedbackRepository.markRepliesAsRead(ticketId, 'admin')
            .catch(err => console.error('[Feedback] markRepliesAsRead user side:', err));

        return await feedbackRepository.getTicketReplies(ticketId);
    }

    // Acepta opcionalmente una lista de archivos (multerFiles) recibidos por el
    // endpoint /reply. Crea el reply y luego adjunta los archivos validados.
    async userReply(ticketId, userEmail, message, multerFiles = []) {
        const safeMessage = (message || '').trim();
        // Permitimos mensaje vacío si hay al menos un adjunto (caso "el usuario
        // solo manda una captura"). Si no hay ni texto ni archivos, error.
        if (safeMessage.length === 0 && multerFiles.length === 0) {
            throw new BadRequestError('Mensaje vacío');
        }

        const ticket = await feedbackRepository.getTicketById(ticketId);
        if (!ticket) throw new NotFoundError('Ticket no encontrado');
        if (ticket.user_email !== userEmail) throw new ForbiddenError('No tienes permiso');

        const reply = await feedbackRepository.addReply(ticketId, userEmail, safeMessage, 'user');

        // Persistir adjuntos. Cualquier fallo aquí lo loggeamos pero no
        // rompemos el reply (el mensaje ya está enviado).
        const attachments = await this._persistAttachments(ticket.id, reply.id, multerFiles);

        await feedbackRepository.updateTicketStatus(ticketId, 'open'); // Reabre si estaba cerrado
        console.log(`[Feedback] 💬 Nuevo mensaje de ${userEmail} en ticket ${ticketId} (${attachments.length} adjuntos)`);
        return { ...reply, attachments };
    }

    async _persistAttachments(ticketId, replyId, multerFiles) {
        const saved = [];
        for (const file of multerFiles) {
            try {
                const meta = await persistAttachment(ticketId, file);
                const row = await feedbackRepository.createAttachment({
                    replyId,
                    ticketId,
                    originalName: meta.originalName,
                    storedName:   meta.storedName,
                    mimeType:     meta.mimeType,
                    sizeBytes:    meta.sizeBytes,
                });
                saved.push({
                    id: row.id,
                    original_name: row.original_name,
                    mime_type:     row.mime_type,
                    size_bytes:    row.size_bytes,
                });
            } catch (err) {
                // Log con stack — los errores de FS (EACCES/ENOENT) o BD
                // (tabla no existe) son los más frecuentes en despliegue.
                console.error('[Feedback] Adjunto rechazado:',
                    `mime=${file?.mimetype} name=${file?.originalname} size=${file?.size}`,
                    err.stack || err.message);
                throw new BadRequestError(err.message);
            }
        }
        return saved;
    }

    async markTicketReadByUser(ticketId, userEmail) {
        const ticket = await feedbackRepository.getTicketById(ticketId);
        if (!ticket) throw new NotFoundError('Ticket no encontrado');
        if (ticket.user_email !== userEmail) throw new ForbiddenError('No tienes permiso');
        const updated = await feedbackRepository.markRepliesAsRead(ticketId, 'admin');
        return { marked: updated };
    }

    async markTicketReadByAdmin(ticketId) {
        const ticket = await feedbackRepository.getTicketById(ticketId);
        if (!ticket) throw new NotFoundError('Ticket no encontrado');
        const updated = await feedbackRepository.markRepliesAsRead(ticketId, 'user');
        return { marked: updated };
    }

    // Lee los metadatos de un adjunto y verifica que el solicitante tenga
    // permiso para descargarlo. Devuelve también la ruta física segura.
    async getAttachmentForDownload(attachmentId, { userEmail = null, isAdmin = false }) {
        const att = await feedbackRepository.getAttachmentById(attachmentId);
        if (!att) throw new NotFoundError('Adjunto no encontrado');
        if (!isAdmin && att.ticket_user_email !== userEmail) {
            throw new ForbiddenError('No tienes permiso para ver este adjunto');
        }
        return att;
    }

    async getAllTicketsAdmin() {
        return await feedbackRepository.getAllTicketsAdmin();
    }

    async adminReply(ticketId, message, multerFiles = []) {
        const safeMessage = (message || '').trim();
        if (safeMessage.length === 0 && multerFiles.length === 0) {
            throw new BadRequestError('El mensaje no puede estar vacío');
        }

        const ticket = await feedbackRepository.getTicketById(ticketId);
        if (!ticket) throw new NotFoundError('Ticket no encontrado');

        const reply = await feedbackRepository.addReply(ticketId, ticket.user_email, safeMessage, 'admin');
        const attachments = await this._persistAttachments(ticket.id, reply.id, multerFiles);

        await feedbackRepository.updateTicketStatus(ticketId, 'in_progress');

        // Al responder el admin asumimos que ya ha "leído" lo del usuario.
        feedbackRepository.markRepliesAsRead(ticketId, 'user')
            .catch(err => console.error('[Feedback] markRepliesAsRead admin reply:', err));

        console.log(`[Feedback] 💬 Admin respondió al ticket #${ticketId} (${attachments.length} adjuntos)`);
        return { ...reply, attachments };
    }

    async updateStatusAdmin(ticketId, status) {
        // Acepta tanto códigos en inglés (open/in_progress/resolved/dismissed)
        // como las etiquetas en español heredadas del admin panel viejo.
        // Persistimos SIEMPRE el código canónico en inglés.
        const normalized = normalizeStatus(status);
        if (!normalized) {
            throw new BadRequestError(`Estado inválido: ${status}`);
        }
        const ticket = await feedbackRepository.updateTicketStatus(ticketId, normalized);
        if (!ticket) throw new NotFoundError('Ticket no encontrado');
        return ticket;
    }

    // Edita un mensaje del admin. Solo el propio admin (cualquier admin)
    // puede editar mensajes sender_type='admin' — los mensajes del usuario
    // son inmutables por integridad de la conversación.
    async editAdminReply(replyId, newMessage) {
        const safe = (newMessage || '').trim();
        if (safe.length === 0) throw new BadRequestError('El mensaje no puede estar vacío');

        const reply = await feedbackRepository.getReplyById(replyId);
        if (!reply) throw new NotFoundError('Mensaje no encontrado');
        if (reply.sender_type !== 'admin') {
            throw new ForbiddenError('Solo se pueden editar mensajes del admin');
        }

        const updated = await feedbackRepository.updateReplyMessage(replyId, safe);
        console.log(`[Feedback] ✏️ Mensaje #${replyId} editado por admin en ticket #${reply.ticket_id}`);
        return updated;
    }

    // Elimina un mensaje admin junto con sus adjuntos (BD + ficheros en
    // disco). Solo sender_type='admin' — los del usuario quedan protegidos.
    async deleteAdminReply(replyId) {
        const reply = await feedbackRepository.getReplyById(replyId);
        if (!reply) throw new NotFoundError('Mensaje no encontrado');
        if (reply.sender_type !== 'admin') {
            throw new ForbiddenError('Solo se pueden borrar mensajes del admin');
        }

        // Borramos primero los blobs de disco. Si fallan, lo logueamos pero
        // seguimos: la fila se irá igual y el cleanup queda como huérfano
        // (preferible a dejar la BD inconsistente).
        const attachments = await feedbackRepository.getAttachmentsByReplyId(replyId);
        for (const att of attachments) {
            try {
                const filePath = resolveAttachmentPath(att);
                await fs.promises.unlink(filePath);
            } catch (err) {
                if (err.code !== 'ENOENT') {
                    console.error('[Feedback] No se pudo borrar adjunto en disco:', err.message);
                }
            }
        }

        const deleted = await feedbackRepository.deleteReply(replyId);
        console.log(`[Feedback] 🗑️ Mensaje #${replyId} borrado por admin en ticket #${reply.ticket_id} (${attachments.length} adjuntos)`);
        return { deleted: true, replyId: deleted.id, ticketId: deleted.ticket_id };
    }

    async getTicketRepliesAdmin(ticketId) {
        // Al abrir el chat el admin, marcamos los mensajes del usuario como
        // leídos. Esto es fire-and-forget igual que en el lado usuario.
        feedbackRepository.markRepliesAsRead(ticketId, 'user')
            .catch(err => console.error('[Feedback] markRepliesAsRead admin side:', err));
        return await feedbackRepository.getTicketReplies(ticketId);
    }
}

module.exports = new FeedbackService();
