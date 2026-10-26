const crypto = require('crypto');
const pool = require('../../db');

// Guardamos SOLO el hash del refresh token. Si la BD se filtrara, los tokens
// no serían usables (no se puede revertir el sha256).
function hashToken(raw) {
    return crypto.createHash('sha256').update(raw).digest('hex');
}

class RefreshTokenRepository {
    async create(userId, email, rawToken, expiresAt) {
        await pool.query(
            `INSERT INTO refresh_tokens (user_id, email, token_hash, expires_at)
             VALUES ($1, $2, $3, $4)`,
            [userId, email, hashToken(rawToken), expiresAt]
        );
    }

    async findValid(rawToken) {
        const r = await pool.query(
            `SELECT user_id, email FROM refresh_tokens
             WHERE token_hash = $1 AND revoked = FALSE AND expires_at > NOW()`,
            [hashToken(rawToken)]
        );
        return r.rows[0] || null;
    }

    async revoke(rawToken) {
        await pool.query(
            'UPDATE refresh_tokens SET revoked = TRUE WHERE token_hash = $1',
            [hashToken(rawToken)]
        );
    }
}

module.exports = new RefreshTokenRepository();
