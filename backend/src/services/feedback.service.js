const feedbackRepository = require('../repositories/feedback.repository');
const { sendDiscordNotification } = require('../../utils/discord');
const { NotFoundError, BadRequestError, ForbiddenError } = require('../utils/errors');

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

        return await feedbackRepository.getTicketReplies(ticketId);
    }

    async userReply(ticketId, userEmail, message) {
        if (!message || message.trim().length === 0) throw new BadRequestError('Mensaje vacío');

        const ticket = await feedbackRepository.getTicketById(ticketId);
        if (!ticket) throw new NotFoundError('Ticket no encontrado');
        if (ticket.user_email !== userEmail) throw new ForbiddenError('No tienes permiso');

        const reply = await feedbackRepository.addReply(ticketId, userEmail, message.trim(), 'user');
        
        await feedbackRepository.updateTicketStatus(ticketId, 'open'); // Reabre si estaba cerrado
        console.log(`[Feedback] 💬 Nuevo mensaje de ${userEmail} en ticket ${ticketId}`);
        return reply;
    }

    async getAllTicketsAdmin() {
        return await feedbackRepository.getAllTicketsAdmin();
    }

    async adminReply(ticketId, message) {
        if (!message || message.trim().length === 0) throw new BadRequestError('El mensaje no puede estar vacío');

        const ticket = await feedbackRepository.getTicketById(ticketId);
        if (!ticket) throw new NotFoundError('Ticket no encontrado');

        const reply = await feedbackRepository.addReply(ticketId, ticket.user_email, message.trim(), 'admin');
        await feedbackRepository.updateTicketStatus(ticketId, 'in_progress');

        console.log(`[Feedback] 💬 Admin respondió al ticket #${ticketId}`);
        return reply;
    }

    async updateStatusAdmin(ticketId, status) {
        if (!['open', 'in_progress', 'resolved', 'closed'].includes(status)) {
            throw new BadRequestError('Estado inválido');
        }
        const ticket = await feedbackRepository.updateTicketStatus(ticketId, status);
        if (!ticket) throw new NotFoundError('Ticket no encontrado');
        return ticket;
    }

    async getTicketRepliesAdmin(ticketId) {
        return await feedbackRepository.getTicketReplies(ticketId);
    }
}

module.exports = new FeedbackService();
