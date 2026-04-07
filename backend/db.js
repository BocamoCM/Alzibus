// ==========================================
// db.js — Módulo de conexión a PostgreSQL
// ==========================================
// Este archivo crea y exporta un "pool" de conexiones a la base de datos.
// Un pool reutiliza conexiones existentes en vez de abrir una nueva por cada
// consulta, lo que es mucho más eficiente. Todos los demás archivos del backend
// hacen `require('./db')` para obtener este pool.

const { Pool } = require('pg'); // Pool de conexiones de la librería 'pg' (node-postgres)
const { sendDiscordNotification } = require('./utils/discord'); // Para alertar errores críticos
require('dotenv').config(); // Carga las variables de entorno desde el archivo .env

// Crear el pool con los datos de conexión desde variables de entorno.
// Esto permite tener distintas configuraciones para desarrollo y producción
// sin tocar el código (solo cambiando el archivo .env).
const pool = new Pool({
    user: process.env.DB_USER,         // Nombre de usuario de PostgreSQL (ej: alzibus_user)
    host: process.env.DB_HOST,         // Host del servidor (ej: localhost o IP de la Raspberry)
    database: process.env.DB_NAME,     // Nombre de la base de datos (ej: alzibus_db)
    password: process.env.DB_PASSWORD, // Contraseña del usuario
    port: process.env.DB_PORT,         // Puerto de PostgreSQL (por defecto 5433 en Docker)
});

// Listener de errores inesperados en el pool.
// Si PostgreSQL se cae o hay un problema de red, este evento se dispara.
// Además de loggearlo en consola, enviamos una alerta a Discord para que
// el equipo se entere inmediatamente y pueda investigar.
pool.on('error', (err) => {
    console.error('[DATABASE] Error inesperado en el pool:', err);
    sendDiscordNotification({
        embeds: [{
            title: "🔴 Fallo Crítico de Base de Datos",
            description: "Se ha detectado un error inesperado en el pool de conexiones de PostgreSQL.",
            color: 0xFF0000, // Red
            fields: [
                { name: "Error", value: `\`${err.message}\`` },
                { name: "Código", value: `\`${err.code || 'N/A'}\`` }
            ],
            footer: { text: "Alzitrans Backend Monitor" }
        }]
    });
});

// Exportar el pool para que el resto del backend lo use con:
// const pool = require('./db');
// await pool.query('SELECT * FROM ...');
module.exports = pool;