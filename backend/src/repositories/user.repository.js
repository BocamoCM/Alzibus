const pool = require('../../db');

class UserRepository {
    async findByEmail(email) {
        const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
        return result.rows[0];
    }

    async createUnverifiedUser(email, passwordHash, verificationCode, otpExpiresAt) {
        const result = await pool.query(
            `INSERT INTO users (email, password_hash, is_verified, verification_code, otp_expires_at, otp_attempts, otp_resend_count)
             VALUES ($1, $2, false, $3, $4, 0, 0) RETURNING id, email`,
            [email, passwordHash, verificationCode, otpExpiresAt]
        );
        return result.rows[0];
    }

    async updateExistingUnverifiedUser(userId, passwordHash, verificationCode) {
        await pool.query(
            'UPDATE users SET password_hash = $1, verification_code = $2, created_at = NOW() WHERE id = $3',
            [passwordHash, verificationCode, userId]
        );
    }

    async deleteStaleUnverifiedAccounts() {
        await pool.query(
            "DELETE FROM users WHERE is_verified = false AND created_at < NOW() - INTERVAL '5 minutes'"
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
}

module.exports = new UserRepository();
