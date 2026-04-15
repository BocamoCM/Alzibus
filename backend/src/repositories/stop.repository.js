const pool = require('../../db');

class StopRepository {
    async getAllStops() {
        const result = await pool.query('SELECT * FROM stops ORDER BY id ASC');
        return result.rows;
    }

    async createStop({ name, lat, lng, lines }) {
        const linesJson = JSON.stringify(lines || []);
        const result = await pool.query(
            'INSERT INTO stops (name, lat, lng, lines) VALUES ($1, $2, $3, $4) RETURNING *',
            [name, lat, lng, linesJson]
        );
        return result.rows[0];
    }

    async updateStop(id, { name, lat, lng, lines }) {
        const linesJson = JSON.stringify(lines || []);
        const result = await pool.query(
            'UPDATE stops SET name = $1, lat = $2, lng = $3, lines = $4 WHERE id = $5 RETURNING *',
            [name, lat, lng, linesJson, id]
        );
        return result.rows[0];
    }

    async deleteStop(id) {
        const result = await pool.query('DELETE FROM stops WHERE id = $1 RETURNING id', [id]);
        return result.rows[0];
    }
}

module.exports = new StopRepository();
