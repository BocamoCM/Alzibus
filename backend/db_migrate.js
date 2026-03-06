// ==========================================
// db_migrate.js — Migración de seguridad OTP
// ==========================================
// Script de migración que añade las columnas necesarias para el sistema
// de verificación por código OTP (One-Time Password) a la tabla 'users'.
//
// Estas columnas permiten:
// - otp_expires_at:   Establecer una fecha de expiración para el código (5 minutos).
// - otp_attempts:     Contar intentos fallidos y bloquear tras demasiados intentos.
// - otp_resend_count: Limitar cuántas veces se puede reenviar el código.
// - otp_penalty_until: Aplicar una penalización temporal si se abusa del reenvío.
//
// Uso: node db_migrate.js
// Es seguro ejecutarlo múltiples veces (IF NOT EXISTS lo hace idempotente).

const pool = require('./db'); // Conexión a la base de datos PostgreSQL

async function migrate() {
    try {
        console.log('Running OTP security migration...');

        // Añadir columna para la fecha de expiración del código OTP
        await pool.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS otp_expires_at TIMESTAMPTZ;');

        // Añadir contador de intentos fallidos de verificación
        await pool.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS otp_attempts INTEGER DEFAULT 0;');

        // Añadir contador de reenvíos del código OTP
        await pool.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS otp_resend_count INTEGER DEFAULT 0;');

        // Añadir columna de penalización temporal (bloqueo por abuso)
        await pool.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS otp_penalty_until TIMESTAMPTZ;');

        console.log('Migration completed!');
    } catch (err) {
        console.error('Migration failed:', err);
    } finally {
        // Cerrar el pool de conexiones al terminar (importante en scripts CLI)
        pool.end();
    }
}

// Ejecutar la migración inmediatamente
migrate();
