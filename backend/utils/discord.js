// ==========================================
// discord.js — Utilidad de notificaciones vía Discord Webhook
// ==========================================
// Envía mensajes al canal de Discord del equipo usando un Webhook URL.
// Se usa para alertar sobre: errores de base de datos, nuevos registros,
// alertas de proximidad, reportes diarios, etc.
// Usa el módulo nativo 'https' de Node.js (sin dependencias externas).

const https = require('https'); // Módulo HTTP/S nativo de Node.js

/**
 * Envía un mensaje de texto al canal de Discord configurado.
 * 
 * @param {string} content - El mensaje a enviar (soporta Markdown de Discord).
 * 
 * Funcionamiento:
 * 1. Lee la URL del webhook desde la variable de entorno DISCORD_WEBHOOK_URL.
 * 2. Si no está configurada, solo muestra un warning en consola (no falla).
 * 3. Construye una petición HTTPS POST con el contenido como JSON.
 * 4. Discord recibe el JSON y publica el mensaje en el canal asociado al webhook.
 * 
 * Ejemplo de uso:
 *   sendDiscordNotification('🆕 Nuevo usuario registrado: user@email.com');
 */
async function sendDiscordNotification(content) {
    // Obtener la URL del webhook de las variables de entorno
    const webhookUrl = process.env.DISCORD_WEBHOOK_URL;
    if (!webhookUrl) {
        // Si no hay webhook configurado, no hacer nada (útil en desarrollo local)
        console.warn('[Discord] No hay URL de webhook configurada');
        return;
    }

    // Preparar el cuerpo de la petición según el formato de Discord API
    // Discord espera un objeto JSON con un campo 'content' (texto del mensaje)
    const data = JSON.stringify({ content });
    const url = new URL(webhookUrl); // Parsear la URL para extraer hostname y path

    // Opciones de la petición HTTPS
    const options = {
        hostname: url.hostname,                       // ej: discord.com
        path: url.pathname + url.search,              // ej: /api/webhooks/1234/abcd
        method: 'POST',                               // Los webhooks de Discord usan POST
        headers: {
            'Content-Type': 'application/json',       // Indicar que el body es JSON
            'Content-Length': Buffer.byteLength(data), // Longitud exacta del body en bytes
        },
    };

    // Realizar la petición HTTPS
    const req = https.request(options, (res) => {
        // Verificar si Discord respondió con un error (código >= 400)
        if (res.statusCode >= 400) {
            console.error(`[Discord] Error al enviar notificación: ${res.statusCode}`);
        }
        // Si el código es 2xx (200, 204), el mensaje se envió correctamente
    });

    // Manejar errores de conexión (ej: sin Internet, DNS fallido)
    req.on('error', (error) => {
        console.error('[Discord] Error de conexión:', error.message);
    });

    // Escribir el cuerpo JSON y cerrar la petición
    req.write(data);
    req.end();
}

// Exportar la función para usarla en otros módulos
module.exports = { sendDiscordNotification };
