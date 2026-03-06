// ==========================================
// db_migrate_premium.js — Migración de estado Premium
// ==========================================
// Script de migración que añade la columna 'is_premium' a la tabla 'users'.
// Esta columna indica si el usuario ha pagado la suscripción Premium (vía Stripe).
//
// Por defecto es FALSE. Se pone a TRUE cuando:
// 1. El webhook de Stripe confirma un pago exitoso.
// 2. O cuando la app llama a /confirm-manual como fallback.
//
// Uso: node db_migrate_premium.js
// Es seguro ejecutarlo múltiples veces (IF NOT EXISTS lo hace idempotente).

const pool = require('./db'); // Conexión a la base de datos PostgreSQL

async function migrate() {
    try {
        console.log('Running Premium Status migration...');

        // Añadir columna booleana para el estado Premium del usuario
        await pool.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS is_premium BOOLEAN DEFAULT FALSE;');

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
