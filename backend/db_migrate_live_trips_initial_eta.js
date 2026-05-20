// ==========================================
// db_migrate_live_trips_initial_eta.js
// ==========================================
// Añade la columna `initial_eta_min` a `live_trips`.
//
// La app pasa al backend, en POST /api/live-trips/start, el tiempo total
// que calculó el planificador local para el trayecto completo (walk a la
// parada + bus + walk final). Lo guardamos para usarlo como countdown en
// el endpoint público del viewer: `ETA = initial_eta_min - minutos_desde_start`.
//
// Antes de este cambio, el viewer calculaba ETA por haversine straight-line
// desde GPS actual a destino, a 6 m/s — y daba resultados muy distintos al
// planner (que sigue la ruta real del bus).
//
// Uso: docker compose exec backend node db_migrate_live_trips_initial_eta.js
// Idempotente (ADD COLUMN IF NOT EXISTS).

const pool = require('./db');

async function migrate() {
    try {
        console.log('Running live_trips.initial_eta_min migration...');
        await pool.query(
            'ALTER TABLE live_trips ADD COLUMN IF NOT EXISTS initial_eta_min INTEGER;'
        );
        console.log('Migration completed!');
    } catch (err) {
        console.error('Migration failed:', err);
        process.exitCode = 1;
    } finally {
        pool.end();
    }
}

migrate();
