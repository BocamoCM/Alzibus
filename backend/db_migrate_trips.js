// ==========================================
// db_migrate_trips.js — Migración de historial de viajes
// ==========================================
// Script de migración que añade la columna 'payment_method'
// a la tabla 'trips' para distinguir entre pagos con tarjeta y efectivo.
//
// Uso: node db_migrate_trips.js
// Es seguro ejecutarlo múltiples veces (IF NOT EXISTS lo hace idempotente).

const pool = require('./db'); // Conexión a la base de datos PostgreSQL

async function migrate() {
    try {
        console.log('Running Trips payment_method migration...');

        // Añadir columna para el método de pago
        await pool.query('ALTER TABLE trips ADD COLUMN IF NOT EXISTS payment_method VARCHAR(20);');

        console.log('Migration completed!');
    } catch (err) {
        console.error('Migration failed:', err);
    } finally {
        // Cerrar el pool de conexiones al terminar
        pool.end();
    }
}

// Ejecutar la migración inmediatamente
migrate();
