const pool = require('../../db');

class TripRepository {
    async getTripsByUser(userId) {
        const result = await pool.query(
            `SELECT id, line, destination, stop_name AS "stopName", stop_id AS "stopId",
             timestamp, confirmed, payment_method AS "paymentMethod"
             FROM trips
             WHERE user_id = $1
             ORDER BY timestamp DESC`,
            [userId]
        );
        return result.rows;
    }

    async createTrip({ userId, line, destination, stopName, stopId, timestamp, confirmed, paymentMethod }) {
        const result = await pool.query(
            `INSERT INTO trips (user_id, line, destination, stop_name, stop_id, timestamp, confirmed, payment_method)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
             RETURNING id, line, destination, stop_name AS "stopName", stop_id AS "stopId", timestamp, confirmed, payment_method AS "paymentMethod"`,
            [userId, line, destination, stopName, stopId, timestamp, confirmed, paymentMethod]
        );
        return result.rows[0];
    }

    async deleteTrip(tripId, userId) {
        const result = await pool.query(
            'DELETE FROM trips WHERE id = $1 AND user_id = $2 RETURNING id',
            [tripId, userId]
        );
        return result.rows[0];
    }

    async deleteAllTrips(userId) {
        await pool.query('DELETE FROM trips WHERE user_id = $1', [userId]);
    }
}

module.exports = new TripRepository();
