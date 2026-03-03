const { Pool } = require('pg');
const { sendDiscordNotification } = require('./utils/discord');
require('dotenv').config();

const pool = new Pool({
    user: process.env.DB_USER,
    host: process.env.DB_HOST,
    database: process.env.DB_NAME,
    password: process.env.DB_PASSWORD,
    port: process.env.DB_PORT,
});

// Notificar errores críticos de base de datos
pool.on('error', (err) => {
    console.error('[DATABASE] Error inesperado en el pool:', err);
    sendDiscordNotification(`🫀 **Fallo en la Base de Datos**: \`${err.message}\``);
});

module.exports = pool;