const pool = require('../../db');

class NoticeRepository {
    async getActiveNotices(userEmail) {
        const result = await pool.query(`
            SELECT n.id, n.title, n.body, n.line, n.active, n.expires_at, n.created_at, n.target_email,
                   (SELECT MAX(id) FROM notice_replies nr
                     WHERE nr.notice_id = n.id AND nr.sender_type = 'admin'
                       AND (nr.user_email = $1 OR n.target_email = $1)
                   ) as last_admin_reply_id,
                   -- Cuántos mensajes del admin tiene este usuario sin leer
                   -- en su thread (avisos generales: filtrar por user_email
                   -- del propio thread, no por target_email).
                   (SELECT COUNT(*)::int FROM notice_replies nr
                     WHERE nr.notice_id = n.id
                       AND nr.sender_type = 'admin'
                       AND nr.read_at IS NULL
                       AND (nr.user_email = $1 OR n.target_email = $1)
                   ) as unread_admin_count
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

    // Para AVISOS GENERALES (target_email = NULL), el "thread" se identifica
    // por user_email: solo se devuelven los mensajes del usuario en cuestión
    // y las respuestas del admin a ese mismo user_email. De este modo cada
    // usuario ve solo su propio hilo y nunca los de otros.
    //
    // Para AVISOS PERSONALES (target_email = un email concreto) sigue
    // funcionando como antes — todos los mensajes del aviso son de y para
    // ese usuario.
    async getMessagesForNotice(noticeId, userEmail) {
        const result = await pool.query(
            `SELECT r.id, r.message, r.sender_type, r.created_at, r.read_at
               FROM notice_replies r
               JOIN notices n ON n.id = r.notice_id
              WHERE r.notice_id = $1
                AND (n.target_email IS NOT NULL OR r.user_email = $2)
              ORDER BY r.created_at ASC`,
            [noticeId, userEmail]
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

    // Marca como leído lo que el admin envió en MI thread de este aviso.
    // Solo toca filas con read_at IS NULL para no machacar timestamps.
    async markRepliesRead(noticeId, userEmail) {
        const result = await pool.query(
            `UPDATE notice_replies
                SET read_at = NOW()
              WHERE notice_id = $1
                AND sender_type = 'admin'
                AND user_email = $2
                AND read_at IS NULL
              RETURNING id`,
            [noticeId, userEmail]
        );
        return result.rowCount;
    }

    // Registra la primera vez que un usuario ve el aviso. Upsert idempotente
    // (no actualiza el timestamp en visitas posteriores).
    async markNoticeRead(noticeId, userEmail) {
        await pool.query(
            `INSERT INTO notice_reads (notice_id, user_email)
             VALUES ($1, $2)
             ON CONFLICT (notice_id, user_email) DO NOTHING`,
            [noticeId, userEmail]
        );
    }

    // Lista de usuarios que han marcado este aviso como leído. Para que el
    // admin sepa quién lo ha visto y a qué hora.
    async getNoticeReaders(noticeId) {
        const result = await pool.query(
            `SELECT user_email, read_at
               FROM notice_reads
              WHERE notice_id = $1
              ORDER BY read_at DESC`,
            [noticeId]
        );
        return result.rows;
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
        // Devolvemos todos los mensajes del aviso ordenados por usuario y
        // fecha — el admin panel los agrupa por user_email para mostrar
        // un thread separado por cada usuario que ha interactuado.
        const result = await pool.query(
            `SELECT id, notice_id, user_email, message, sender_type, created_at, read_at
               FROM notice_replies
              WHERE notice_id = $1
              ORDER BY user_email ASC, created_at ASC`,
            [noticeId]
        );
        return result.rows;
    }

    // Marca como leídos los mensajes del USUARIO en mi thread (admin abrió
    // el chat). Análogo a feedback con sender_type='user'.
    async markUserRepliesReadByAdmin(noticeId, userEmail) {
        const result = await pool.query(
            `UPDATE notice_replies
                SET read_at = NOW()
              WHERE notice_id = $1
                AND sender_type = 'user'
                AND user_email = $2
                AND read_at IS NULL
              RETURNING id`,
            [noticeId, userEmail]
        );
        return result.rowCount;
    }
}

module.exports = new NoticeRepository();
