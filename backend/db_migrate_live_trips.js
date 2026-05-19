// ==========================================
// db_migrate_live_trips.js — Migración de viajes compartidos en vivo
// ==========================================
// Crea la tabla `live_trips` para la feature "Compartir mi viaje".
// Distinto de `trips` (historial inmutable): `live_trips` son viajes
// ACTIVOS con posición GPS actualizándose en tiempo real y un token
// compartible para que otra persona vea dónde vas en un mapa público.
//
// Uso: node db_migrate_live_trips.js
// Es idempotente (CREATE TABLE IF NOT EXISTS / ADD COLUMN IF NOT EXISTS).

const pool = require('./db');

async function migrate() {
    try {
        console.log('Running live_trips migration...');

        // Tabla principal.
        await pool.query(`
            CREATE TABLE IF NOT EXISTS live_trips (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                share_token VARCHAR(16) UNIQUE NOT NULL,
                line VARCHAR(20),
                origin_stop_id INTEGER,
                origin_stop_name VARCHAR(255),
                destination_stop_id INTEGER,
                destination_stop_name VARCHAR(255),
                destination_lat DECIMAL(10, 7),
                destination_lng DECIMAL(10, 7),
                last_lat DECIMAL(10, 7),
                last_lng DECIMAL(10, 7),
                last_speed_mps DECIMAL(6, 2),
                last_accuracy_m DECIMAL(8, 2),
                last_ping_at TIMESTAMPTZ,
                eta_min INTEGER,
                status VARCHAR(20) NOT NULL DEFAULT 'active',
                started_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
                ended_at TIMESTAMPTZ,
                expires_at TIMESTAMPTZ NOT NULL
            );
        `);

        // Índices: búsqueda por share_token (público, hot path), por usuario
        // (para "viaje activo del user"), y por (status, expires_at) para que
        // el job de expiración pueda hacer un scan eficiente.
        await pool.query(
            'CREATE INDEX IF NOT EXISTS idx_live_trips_share_token ON live_trips(share_token);'
        );
        await pool.query(
            'CREATE INDEX IF NOT EXISTS idx_live_trips_user_id ON live_trips(user_id);'
        );
        await pool.query(
            'CREATE INDEX IF NOT EXISTS idx_live_trips_status_expires ON live_trips(status, expires_at);'
        );

        // pgcrypto necesaria para gen_random_uuid(). Algunos clusters ya la
        // tienen instalada — IF NOT EXISTS evita el error si ya está.
        await pool.query('CREATE EXTENSION IF NOT EXISTS pgcrypto;');

        console.log('Migration completed!');
    } catch (err) {
        console.error('Migration failed:', err);
        process.exitCode = 1;
    } finally {
        pool.end();
    }
}

migrate();
