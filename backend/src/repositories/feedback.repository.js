const pool = require('../../db');

class FeedbackRepository {
    async getUserTickets(userEmail) {
        // Devuelve además unread_admin_count: cuántos mensajes del admin
        // sigue sin leer este usuario en cada ticket (para badges de la lista).
        const result = await pool.query(`
            SELECT t.*,
                   (SELECT MAX(id) FROM feedback_replies fr
                      WHERE fr.ticket_id = t.id AND fr.sender_type = 'admin') AS last_admin_reply_id,
                   (SELECT COUNT(*)::int FROM feedback_replies fr
                      WHERE fr.ticket_id = t.id
                        AND fr.sender_type = 'admin'
                        AND fr.read_at IS NULL) AS unread_admin_count
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

    // Devuelve replies con adjuntos agregados en un campo JSON para que el
    // cliente no necesite hacer una segunda query por mensaje. Usamos
    // json_agg + FILTER para que mensajes sin adjuntos devuelvan [] en vez
    // de [null].
    async getTicketReplies(ticketId) {
        const result = await pool.query(`
            SELECT r.id,
                   r.ticket_id,
                   r.message,
                   r.sender_type,
                   r.created_at,
                   r.read_at,
                   COALESCE(
                       json_agg(
                           json_build_object(
                               'id', a.id,
                               'original_name', a.original_name,
                               'mime_type', a.mime_type,
                               'size_bytes', a.size_bytes
                           )
                       ) FILTER (WHERE a.id IS NOT NULL),
                       '[]'::json
                   ) AS attachments
              FROM feedback_replies r
              LEFT JOIN feedback_attachments a ON a.reply_id = r.id
             WHERE r.ticket_id = $1
             GROUP BY r.id
             ORDER BY r.created_at ASC
        `, [ticketId]);
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
        // unread_user_count: cuántos mensajes del usuario están aún sin leer
        // por el admin. Sirve para el badge "tienes mensajes nuevos" en el
        // listado del admin panel.
        const result = await pool.query(`
            SELECT t.*,
                   (SELECT COUNT(*)::int FROM feedback_replies fr
                      WHERE fr.ticket_id = t.id
                        AND fr.sender_type = 'user'
                        AND fr.read_at IS NULL) AS unread_user_count
              FROM feedback_tickets t
             ORDER BY t.created_at DESC
        `);
        return result.rows;
    }

    // Marca todos los mensajes del lado opuesto al que abre el chat como leídos.
    // - Usuario abre el ticket → marca los mensajes admin como leídos.
    // - Admin abre el ticket   → marca los mensajes user como leídos.
    // Solo actualiza filas con read_at = NULL para no machacar timestamps.
    async markRepliesAsRead(ticketId, senderTypeToMark) {
        const result = await pool.query(
            `UPDATE feedback_replies
                SET read_at = NOW()
              WHERE ticket_id = $1
                AND sender_type = $2
                AND read_at IS NULL
              RETURNING id`,
            [ticketId, senderTypeToMark]
        );
        return result.rowCount;
    }

    // ── Adjuntos ──
    async createAttachment({ replyId, ticketId, originalName, storedName, mimeType, sizeBytes }) {
        const result = await pool.query(
            `INSERT INTO feedback_attachments
                (reply_id, ticket_id, original_name, stored_name, mime_type, size_bytes)
             VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
            [replyId, ticketId, originalName, storedName, mimeType, sizeBytes]
        );
        return result.rows[0];
    }

    async getAttachmentById(attachmentId) {
        const result = await pool.query(
            `SELECT a.*, t.user_email AS ticket_user_email
               FROM feedback_attachments a
               JOIN feedback_tickets t ON t.id = a.ticket_id
              WHERE a.id = $1`,
            [attachmentId]
        );
        return result.rows[0];
    }
}

module.exports = new FeedbackRepository();
