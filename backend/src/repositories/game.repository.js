// ==========================================
// src/repositories/game.repository.js
// ==========================================
// Acceso a datos para el estado de juego del usuario (monedas + skins).
const pool = require('../../db');

class GameRepository {
    /**
     * Devuelve {coins, ownedSkins} del usuario. Si por algún motivo no
     * existe el registro (raro, sería un user huérfano), devuelve defaults.
     */
    async getState(userId) {
        const res = await pool.query(
            'SELECT game_coins, owned_skins FROM users WHERE id = $1',
            [userId]
        );
        if (res.rows.length === 0) {
            return { coins: 0, ownedSkins: ['default'] };
        }
        const row = res.rows[0];
        return {
            coins: row.game_coins,
            ownedSkins: (row.owned_skins || 'default')
                .split(',')
                .map(s => s.trim())
                .filter(Boolean),
        };
    }

    /**
     * Actualiza el saldo de monedas a un valor absoluto. La validación de
     * "no permitir overflow / valores absurdos" se hace en el service.
     */
    async setCoins(userId, coins) {
        const res = await pool.query(
            `UPDATE users SET game_coins = $2 WHERE id = $1
             RETURNING game_coins`,
            [userId, coins]
        );
        return res.rows[0]?.game_coins ?? 0;
    }

    /**
     * Actualiza el set de skins poseídos como CSV.
     */
    async setOwnedSkins(userId, ownedSkins) {
        const csv = Array.from(new Set([...ownedSkins, 'default'])).join(',');
        const res = await pool.query(
            `UPDATE users SET owned_skins = $2 WHERE id = $1
             RETURNING owned_skins`,
            [userId, csv]
        );
        return (res.rows[0]?.owned_skins || 'default').split(',');
    }
}

module.exports = new GameRepository();
