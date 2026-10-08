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
     * Sube el saldo al MAYOR entre el actual en BD y `coins`, de forma
     * ATÓMICA (una sola sentencia `GREATEST`). Esto evita la carrera
     * read-modify-write del antiguo flujo (getState + setCoins), donde dos
     * sincronizaciones concurrentes podían "pisarse" y perder el valor más
     * alto. El servidor nunca baja el saldo aquí (semántica max-wins).
     * Devuelve el saldo resultante.
     * Resiliente a missing column (devuelve el valor enviado sin persistir).
     */
    async bumpCoins(userId, coins) {
        try {
            const res = await pool.query(
                `UPDATE users SET game_coins = GREATEST(game_coins, $2)
                 WHERE id = $1
                 RETURNING game_coins`,
                [userId, coins]
            );
            // Usuario inexistente (0 filas): devolvemos el valor pedido como
            // mejor aproximación, sin persistir (coherente con getState).
            return res.rows[0]?.game_coins ?? coins;
        } catch (err) {
            if (err.code === '42703') {
                console.warn('[GameRepository] bumpCoins: falta columna, no se persiste');
                return coins;
            }
            throw err;
        }
    }

    /**
     * COMPRA server-authoritative de una skin, ATÓMICA en una sola
     * sentencia. En un único UPDATE:
     *   1. Sincroniza el saldo al mayor entre el de BD y el que trae el
     *      cliente (`GREATEST`, misma semántica max-wins que el sync de
     *      ganancias), de modo que las monedas ganadas offline cuenten.
     *   2. Resta el coste de verdad.
     *   3. Añade la skin al CSV.
     * Todo condicionado a que (a) el saldo efectivo alcance el coste y
     * (b) la skin NO esté ya poseída (comparación exacta con
     * `string_to_array`, sin comodines de LIKE).
     *
     * Devuelve {coins, ownedSkins} si la compra se realizó, o `null` si no
     * se actualizó ninguna fila (saldo insuficiente, o skin ya poseída —
     * el service distingue ambos casos leyendo el estado).
     * Resiliente a missing column.
     *
     * @param {number} clientCoins saldo local que afirma el cliente (ya
     *   validado y floored en el service).
     */
    async purchaseSkin(userId, skinId, cost, clientCoins) {
        try {
            const res = await pool.query(
                `UPDATE users
                 SET game_coins = GREATEST(game_coins, $4) - $3,
                     owned_skins = CASE
                         WHEN COALESCE(owned_skins, '') = '' THEN 'default,' || $2
                         ELSE owned_skins || ',' || $2
                     END
                 WHERE id = $1
                   AND GREATEST(game_coins, $4) >= $3
                   AND NOT ($2 = ANY(string_to_array(COALESCE(owned_skins, ''), ',')))
                 RETURNING game_coins, owned_skins`,
                [userId, skinId, cost, clientCoins]
            );
            if (res.rows.length === 0) return null;
            const row = res.rows[0];
            return {
                coins: row.game_coins,
                ownedSkins: (row.owned_skins || 'default')
                    .split(',')
                    .map(s => s.trim())
                    .filter(Boolean),
            };
        } catch (err) {
            if (err.code === '42703') {
                console.warn('[GameRepository] purchaseSkin: falta columna, no se persiste');
                return null;
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
