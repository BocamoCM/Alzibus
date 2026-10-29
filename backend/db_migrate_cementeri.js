// ==========================================
// db_migrate_cementeri.js — Línea del cementerio (CEM)
// ==========================================
// Añade a la tabla 'stops' la línea CEM (servicio Alzira-Cementerio: jueves
// laborables, salida 16:00 de la plaza del Reino y vuelta 17:10):
// 1. Inserta la parada 79 CEMENTERI (con su id real del operador: es el que
//    usa la web de tiempos de paso para dar llegadas en tiempo real).
// 2. Añade "CEM" a las líneas de las paradas del recorrido.
//
// NO vacía ni reescribe la tabla (a diferencia de import_stops.js), así que
// respeta las paradas editadas desde el panel de admin.
// Es seguro ejecutarlo varias veces.
//
// Uso (en la Pi):  docker compose exec backend node db_migrate_cementeri.js

const pool = require('./db'); // Conexión a la base de datos PostgreSQL

const CEMENTERI = { id: 79, name: 'CEMENTERI', lat: 39.152597, lng: -0.398261 };
// Paradas del recorrido (mismo orden que assets/routes/CEM.json)
const ROUTE_STOP_IDS = [3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 79, 16, 20, 21, 22, 23, 24, 25, 82, 83, 26, 27];

async function migrate() {
    const client = await pool.connect();
    try {
        console.log('Añadiendo la línea del cementerio (CEM)...');
        await client.query('BEGIN');

        const ins = await client.query(
            `INSERT INTO stops (id, name, lat, lng, lines)
             VALUES ($1, $2, $3, $4, $5::jsonb)
             ON CONFLICT (id) DO NOTHING`,
            [CEMENTERI.id, CEMENTERI.name, CEMENTERI.lat, CEMENTERI.lng, JSON.stringify(['CEM'])]
        );
        console.log(ins.rowCount ? '  + parada 79 CEMENTERI creada' : '  = parada 79 ya existía');

        // Añadir "CEM" solo a las paradas que aún no la tienen
        const upd = await client.query(
            `UPDATE stops
                SET lines = COALESCE(lines, '[]'::jsonb) || '["CEM"]'::jsonb
              WHERE id = ANY($1::int[])
                AND NOT (COALESCE(lines, '[]'::jsonb) ? 'CEM')`,
            [ROUTE_STOP_IDS]
        );
        console.log(`  + "CEM" añadida a ${upd.rowCount} paradas`);

        // El id 79 se ha insertado a mano: que la secuencia no lo reutilice.
        await client.query(
            `SELECT setval(pg_get_serial_sequence('stops', 'id'),
                           GREATEST((SELECT MAX(id) FROM stops), 1))`
        );

        await client.query('COMMIT');

        const check = await client.query(
            `SELECT COUNT(*)::int AS n FROM stops WHERE lines ? 'CEM'`
        );
        console.log(`Hecho: ${check.rows[0].n} paradas con la línea CEM (esperadas ${ROUTE_STOP_IDS.length}).`);
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('La migración ha fallado (no se ha cambiado nada):', err);
        process.exitCode = 1;
    } finally {
        client.release();
        await pool.end();
    }
}

migrate();
