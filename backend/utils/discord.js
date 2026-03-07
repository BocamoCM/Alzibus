const https = require('https');

/**
 * Envía una notificación a Discord vía Webhook
 */
async function sendDiscordNotification(content) {
    const webhookUrl = process.env.DISCORD_WEBHOOK_URL;
    if (!webhookUrl) {
        console.warn('[Discord] No hay URL de webhook configurada');
        return;
    }

    const data = JSON.stringify({ content });
    const url = new URL(webhookUrl);

    const options = {
        hostname: url.hostname,
        path: url.pathname + url.search,
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(data),
        },
    };

    const req = https.request(options, (res) => {
        if (res.statusCode >= 400) {
            console.error(`[Discord] Error al enviar notificación: ${res.statusCode}`);
        }
    });

    req.on('error', (error) => {
        console.error('[Discord] Error de conexión:', error.message);
    });

    req.write(data);
    req.end();
}

module.exports = { sendDiscordNotification };