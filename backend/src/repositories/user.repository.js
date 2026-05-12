const pool = require('../../db');

class UserRepository {
    async findByEmail(email) {
        const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
        return result.rows[0];
    }

    // Crea un usuario sin OTP. La verificación se hará en el primer login
    // (el OTP de login marca is_verified=true). Se mantiene el nombre
    // "Unverified" por claridad: el estado inicial es is_verified=false.
    async createUnverifiedUser(email, passwordHash) {
        const result = await pool.query(
            `INSERT INTO users (email, password_hash, is_verified, otp_attempts, otp_resend_count)
             VALUES ($1, $2, false, 0, 0) RETURNING id, email`,
            [email, passwordHash]
        );
        return result.rows[0];
    }

    // Permite "re-registrar" si la cuenta ya existe pero no está verificada
    // (típico: el usuario olvidó la contraseña antes de loguearse por primera
    // vez). Reseteamos password + estado OTP + created_at (para que el reloj
    // de limpieza de 7 días empiece de nuevo).
    async updateExistingUnverifiedUser(userId, passwordHash) {
        await pool.query(
            `UPDATE users
                SET password_hash = $1,
                    verification_code = NULL,
                    otp_expires_at = NULL,
                    otp_attempts = 0,
                    otp_resend_count = 0,
                    otp_penalty_until = NULL,
                    created_at = NOW()
              WHERE id = $2`,
            [passwordHash, userId]
        );
    }

    // Limpia cuentas que se registraron pero nunca completaron su primer
    // login (en el nuevo flujo, "verificación" = "completar OTP del primer
    // login"). 7 días da margen suficiente para que el usuario vuelva.
    async deleteStaleUnverifiedAccounts() {
        await pool.query(
            "DELETE FROM users WHERE is_verified = false AND created_at < NOW() - INTERVAL '7 days'"
        );
    }
    
    async incrementOtpAttemptsAndSetPenalty(userId, attempts, penaltyUntil) {
        await pool.query(
            'UPDATE users SET otp_attempts = $1, otp_penalty_until = $2 WHERE id = $3',
            [attempts, penaltyUntil, userId]
        );
    }

    async updateOtpAttempts(userId, attempts) {
        await pool.query('UPDATE users SET otp_attempts = $1 WHERE id = $2', [attempts, userId]);
    }

    async markAsVerified(userId) {
        await pool.query(
            'UPDATE users SET is_verified = true, verification_code = NULL, otp_expires_at = NULL, otp_attempts = 0, otp_penalty_until = NULL WHERE id = $1',
            [userId]
        );
    }

    async updateOtpCode(userId, newCode, expiry, resendCount) {
        await pool.query(
            'UPDATE users SET verification_code = $1, otp_expires_at = $2, otp_attempts = 0, otp_resend_count = $3 WHERE id = $4',
            [newCode, expiry, resendCount, userId]
        );
    }

    async updatePassword(userId, passwordHash) {
        await pool.query(
            'UPDATE users SET password_hash = $1, verification_code = NULL, otp_expires_at = NULL, otp_attempts = 0 WHERE id = $2',
            [passwordHash, userId]
        );
    }

    async updateLastAccess(userId) {
         await pool.query('UPDATE users SET last_access = NOW() WHERE id = $1', [userId]);
    }

    async getActiveUsers(minutes) {
        const result = await pool.query(
            "SELECT email, last_access FROM users WHERE last_access > NOW() - INTERVAL '" + minutes + " minutes' ORDER BY last_access DESC"
        );
        return result.rows;
    }

    async findById(userId) {
        const result = await pool.query('SELECT id, email, created_at, last_access, is_premium FROM users WHERE id = $1', [userId]);
        return result.rows[0];
    }

    async findByIdWithPassword(userId) {
        const result = await pool.query('SELECT password_hash FROM users WHERE id = $1', [userId]);
        return result.rows[0];
    }

    async findByEmailExcludeId(email, excludeUserId) {
        const result = await pool.query('SELECT id FROM users WHERE email = $1 AND id != $2', [email, excludeUserId]);
        return result.rows[0];
    }

    async updateEmail(userId, newEmail) {
        await pool.query('UPDATE users SET email = $1 WHERE id = $2', [newEmail, userId]);
    }

    async deleteUser(userId) {
        await pool.query('DELETE FROM users WHERE id = $1', [userId]);
    }

    async deleteUserTrips(userId) {
         await pool.query('DELETE FROM trips WHERE user_id = $1', [userId]);
    }

    // Invierte el flag active (true → false → true). Devuelve el usuario
    // resultante para que el cliente refresque la UI sin tener que recargar
    // toda la lista. Usado por el panel admin como "banear/desbanear".
    async toggleActive(userId) {
        const result = await pool.query(
            'UPDATE users SET active = NOT COALESCE(active, TRUE) WHERE id = $1 RETURNING id, email, active',
            [userId]
        );
        return result.rows[0];
    }

    async getTotalTrips(userId) {
        const result = await pool.query('SELECT COUNT(*) FROM trips WHERE user_id = $1', [userId]);
        return result.rows[0].count;
    }

    async getMostUsedLine(userId) {
        const result = await pool.query(
            'SELECT line, COUNT(*) as count FROM trips WHERE user_id = $1 GROUP BY line ORDER BY count DESC LIMIT 1', 
            [userId]
        );
        return result.rows[0]?.line;
    }

    async getThisMonthTrips(userId) {
        const result = await pool.query(
            "SELECT COUNT(*) FROM trips WHERE user_id = $1 AND timestamp >= date_trunc('month', NOW())", 
            [userId]
        );
        return result.rows[0].count;
    }

    async getTopRanking(period) {
        const dateFilter = period === 'month' ? "AND t.timestamp >= date_trunc('month', NOW())" : '';
        const query = `
            SELECT
                u.id,
                u.email,
                COUNT(t.id)::int AS trips,
                RANK() OVER (ORDER BY COUNT(t.id) DESC) AS position
            FROM users u
            JOIN trips t ON t.user_id = u.id
            WHERE 1=1 ${dateFilter}
            GROUP BY u.id
            ORDER BY trips DESC
            LIMIT 20
        `;
        const result = await pool.query(query);
        return result.rows;
    }

    async getUserRanking(userId, period) {
        const dateFilter = period === 'month' ? "AND t.timestamp >= date_trunc('month', NOW())" : '';
        const query = `
            SELECT position, trips FROM (
                SELECT
                    u.id,
                    COUNT(t.id)::int AS trips,
                    RANK() OVER (ORDER BY COUNT(t.id) DESC) AS position
                FROM users u
                JOIN trips t ON t.user_id = u.id
                WHERE 1=1 ${dateFilter}
                GROUP BY u.id
            ) ranked
            WHERE id = $1
        `;
        const result = await pool.query(query, [userId]);
        return result.rows[0];
    }

    async getAllUsersOverview() {
        const result = await pool.query(
            "SELECT id, email, created_at, last_access, is_premium, active, is_verified FROM users ORDER BY created_at DESC"
        );
        return result.rows;
    }

    async getAllUserEmails() {
        const result = await pool.query("SELECT email FROM users WHERE is_verified = TRUE");
        return result.rows.map(row => row.email);
    }
}

module.exports = new UserRepository();
