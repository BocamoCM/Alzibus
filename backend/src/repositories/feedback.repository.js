const pool = require('../../db');

class FeedbackRepository {
    async getUserTickets(userEmail) {
        const result = await pool.query(`
            SELECT t.*, 
                   (SELECT MAX(id) FROM feedback_replies fr WHERE fr.ticket_id = t.id AND fr.sender_type = 'admin') as last_admin_reply_id
            FROM feedback_tickets t
            WHERE t.user_email = $1
            ORDER BY t.created_at DESC
        `, [userEmail]);
        return result.rows;
    }

    async createTicket(userEmail, tag, title, description) {
        const result = await pool.query(
            'INSERT INTO feedback_tickets (user_email, tag, title, description) VALUES ($1, $2, $3, $4) RETURNING *',
            [userEmail, tag, title, description]
        );
        return result.rows[0];
    }

    async getTicketById(ticketId) {
        const result = await pool.query('SELECT * FROM feedback_tickets WHERE id = $1', [ticketId]);
        return result.rows[0];
    }

    async getTicketReplies(ticketId) {
        const result = await pool.query(
            'SELECT id, message, sender_type, created_at FROM feedback_replies WHERE ticket_id = $1 ORDER BY created_at ASC',
            [ticketId]
        );
        return result.rows;
    }

    async addReply(ticketId, userEmail, message, senderType) {
        const result = await pool.query(
            'INSERT INTO feedback_replies (ticket_id, user_email, message, sender_type) VALUES ($1, $2, $3, $4) RETURNING *',
            [ticketId, userEmail, message, senderType]
        );
        return result.rows[0];
    }

    async updateTicketStatus(ticketId, status) {
        const result = await pool.query(
            'UPDATE feedback_tickets SET status = $1, updated_at = NOW() WHERE id = $2 RETURNING *',
            [status, ticketId]
        );
        return result.rows[0];
    }

    async getAllTicketsAdmin() {
        const result = await pool.query(
            'SELECT * FROM feedback_tickets ORDER BY created_at DESC'
        );
        return result.rows;
    }
}

module.exports = new FeedbackRepository();
