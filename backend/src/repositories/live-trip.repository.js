// ==========================================
// src/repositories/live-trip.repository.js
// ==========================================
// Acceso a datos para la tabla `live_trips` (viajes compartidos en vivo).
const pool = require('../../db');

class LiveTripRepository {
    /**
     * Crea un nuevo viaje en vivo y devuelve el registro completo.
     */
    async create({
        userId, shareToken, line,
        originStopId, originStopName,
        destinationStopId, destinationStopName,
        destinationLat, destinationLng,
        expiresAt,
    }) {
        const result = await pool.query(
            `INSERT INTO live_trips
                (user_id, share_token, line,
                 origin_stop_id, origin_stop_name,
                 destination_stop_id, destination_stop_name,
                 destination_lat, destination_lng,
                 expires_at)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
             RETURNING *`,
            [
                userId, shareToken, line,
                originStopId ?? null, originStopName ?? null,
                destinationStopId ?? null, destinationStopName ?? null,
                destinationLat ?? null, destinationLng ?? null,
                expiresAt,
            ]
        );
        return result.rows[0];
    }

    /**
     * Devuelve el viaje activo de un usuario (si existe). Solo uno puede
     * estar activo a la vez; el endpoint /start cierra el anterior.
     */
    async getActiveByUser(userId) {
        const result = await pool.query(
            `SELECT * FROM live_trips
             WHERE user_id = $1 AND status = 'active' AND expires_at > NOW()
             ORDER BY started_at DESC LIMIT 1`,
            [userId]
        );
        return result.rows[0] || null;
    }

    async findById(id) {
        const result = await pool.query('SELECT * FROM live_trips WHERE id = $1', [id]);
        return result.rows[0] || null;
    }

    async findByShareToken(token) {
        const result = await pool.query(
            'SELECT * FROM live_trips WHERE share_token = $1',
            [token]
        );
        return result.rows[0] || null;
    }

    /**
     * Actualiza posición + ETA con un ping. Solo si el trip está activo y no
     * expirado — si está cerrado, se ignora silenciosamente devolviendo null.
     */
    async ping(id, { lat, lng, speedMps, accuracyM, etaMin }) {
        const result = await pool.query(
            `UPDATE live_trips
             SET last_lat = $2,
                 last_lng = $3,
                 last_speed_mps = $4,
                 last_accuracy_m = $5,
                 eta_min = $6,
                 last_ping_at = NOW()
             WHERE id = $1
               AND status = 'active'
               AND expires_at > NOW()
             RETURNING *`,
            [id, lat, lng, speedMps ?? null, accuracyM ?? null, etaMin ?? null]
        );
        return result.rows[0] || null;
    }

    /**
     * Marca como ended (terminado por el usuario). No borra: queremos
     * conservar el registro para que el viewer muestre "Viaje finalizado".
     */
    async end(id, userId) {
        const result = await pool.query(
            `UPDATE live_trips
             SET status = 'ended', ended_at = NOW()
             WHERE id = $1 AND user_id = $2 AND status = 'active'
             RETURNING *`,
            [id, userId]
        );
        return result.rows[0] || null;
    }

    /**
     * Marca como expired todos los viajes activos cuyo expires_at ya pasó.
     * Llamar periódicamente (cron). Devuelve cuántos se marcaron.
     */
    async expireOldTrips() {
        const result = await pool.query(
            `UPDATE live_trips
             SET status = 'expired'
             WHERE status = 'active' AND expires_at <= NOW()
             RETURNING id`,
        );
        return result.rowCount;
    }
}

module.exports = new LiveTripRepository();
