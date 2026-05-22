// ==========================================
// src/repositories/game.repository.js
// ==========================================
// Acceso a datos para el estado de juego del usuario (monedas + skins).
const pool = require('../../db');

class GameRepository {
    /**
     * Devuelve {coins, ownedSkins} del usuario. Si por algún motivo no
     * existe el registro (raro, sería un user huérfano), devuelve defaults.
     *
     * **Defensa contra missing column**: si la migración
     * `db_migrate_game_coins.js` no se ha ejecutado, Postgres lanza
     * `column "game_coins" does not exist` → 500 al cliente → app
     * crashea en el reconcile inicial. Capturamos ese error y
     * devolvemos defaults (la app sigue funcionando con su local).
     * Loguea WARN para que el admin sepa que falta migración.
     */
    async getState(userId) {
        try {
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
        } catch (err) {
            // 42703 = undefined_column en Postgres
            if (err.code === '42703') {
                console.warn(
                    '[GameRepository] FALTA MIGRACIÓN: columna game_coins ' +
                    'o owned_skins no existe en tabla users. ' +
                    'Ejecutar: docker compose exec backend node db_migrate_game_coins.js'
                );
                return { coins: 0, ownedSkins: ['default'] };
            }
            throw err;
        }
    }

    /**
     * Actualiza el saldo de monedas a un valor absoluto. La validación de
     * "no permitir overflow / valores absurdos" se hace en el service.
     * Resiliente a missing column (devuelve el valor enviado sin persistir).
     */
    async setCoins(userId, coins) {
        try {
            const res = await pool.query(
                `UPDATE users SET game_coins = $2 WHERE id = $1
                 RETURNING game_coins`,
                [userId, coins]
            );
            return res.rows[0]?.game_coins ?? 0;
        } catch (err) {
            if (err.code === '42703') {
                console.warn('[GameRepository] setCoins: falta columna, no se persiste');
                return coins;
            }
            throw err;
        }
    }

    /**
     * Actualiza el set de skins poseídos como CSV.
     * Resiliente a missing column.
     */
    async setOwnedSkins(userId, ownedSkins) {
        const csv = Array.from(new Set([...ownedSkins, 'default'])).join(',');
        try {
            const res = await pool.query(
                `UPDATE users SET owned_skins = $2 WHERE id = $1
                 RETURNING owned_skins`,
                [userId, csv]
            );
            return (res.rows[0]?.owned_skins || 'default').split(',');
        } catch (err) {
            if (err.code === '42703') {
                console.warn('[GameRepository] setOwnedSkins: falta columna, no se persiste');
                return ownedSkins;
            }
            throw err;
        }
    }
}

module.exports = new GameRepository();
