const pool = require('../../db');

class NoticeRepository {
    async getActiveNotices(userEmail) {
        const result = await pool.query(`
            SELECT n.id, n.title, n.body, n.line, n.active, n.expires_at, n.created_at, n.target_email,
                   (SELECT MAX(id) FROM notice_replies nr WHERE nr.notice_id = n.id AND nr.sender_type = 'admin') as last_admin_reply_id
            FROM notices n
            WHERE n.active = TRUE
              AND (n.expires_at IS NULL OR n.expires_at > NOW())
              AND (n.target_email IS NULL OR n.target_email = $1)
            ORDER BY n.created_at DESC
        `, [userEmail]);
        return result.rows;
    }

    async getNoticeTargetEmail(noticeId) {
        const result = await pool.query('SELECT target_email FROM notices WHERE id = $1 AND active = TRUE', [noticeId]);
        return result.rows[0];
    }

    async getNoticeById(noticeId) {
        const result = await pool.query('SELECT * FROM notices WHERE id = $1', [noticeId]);
        return result.rows[0];
    }

    async getMessagesForNotice(noticeId) {
        const result = await pool.query(
            'SELECT id, message, sender_type, created_at FROM notice_replies WHERE notice_id = $1 ORDER BY created_at ASC',
            [noticeId]
        );
        return result.rows;
    }

    async addReply(noticeId, userEmail, message, senderType) {
        const result = await pool.query(
            'INSERT INTO notice_replies (notice_id, user_email, message, sender_type) VALUES ($1, $2, $3, $4) RETURNING *',
            [noticeId, userEmail, message, senderType]
        );
        return result.rows[0];
    }

    async getAllNoticesAdmin() {
        const result = await pool.query('SELECT * FROM notices ORDER BY created_at DESC');
        return result.rows;
    }

    async createNoticeAdmin({ title, body, line, expiresAt, targetEmail }) {
        const result = await pool.query(
            'INSERT INTO notices (title, body, line, expires_at, target_email) VALUES ($1, $2, $3, $4, $5) RETURNING *',
            [title, body, line || null, expiresAt || null, targetEmail || null]
        );
        return result.rows[0];
    }

    async deleteNoticeAdmin(noticeId) {
        await pool.query('DELETE FROM notices WHERE id = $1', [noticeId]);
    }

    async getNoticeRepliesAdmin(noticeId) {
        const result = await pool.query(
            'SELECT id, notice_id, user_email, message, sender_type, created_at FROM notice_replies WHERE notice_id = $1 ORDER BY created_at ASC',
            [noticeId]
        );
        return result.rows;
    }
}

module.exports = new NoticeRepository();
