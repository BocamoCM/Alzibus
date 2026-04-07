const https = require('https');

/**
 * Envía una notificación a Discord vía Webhook
 * @param {string|object} data - Texto plano o objeto de Embed de Discord
 */
async function sendDiscordNotification(payload) {
    const webhookUrl = process.env.DISCORD_WEBHOOK_URL;
    if (!webhookUrl) {
        console.warn('[Discord] No hay URL de webhook configurada');
        return;
    }

    // Si payload es un string, envolverlo en el formato de Discord estándar
    // Si es un objeto, asumimos que ya tiene el formato correcto (ej: { embeds: [...] })
    let body;
    if (typeof payload === 'string') {
        body = JSON.stringify({ content: payload });
    } else {
        // Asegurarnos de que si enviamos un embed sin color, le pongamos el granate de Alzitrans
        if (payload.embeds && payload.embeds.length > 0) {
            payload.embeds.forEach(embed => {
                if (!embed.color) embed.color = 0x4A1D3D; // Burgundy Alzitrans
                if (!embed.timestamp) embed.timestamp = new Date().toISOString();
            });
        }
        body = JSON.stringify(payload);
    }

    const url = new URL(webhookUrl);
    const options = {
        hostname: url.hostname,
        path: url.pathname + url.search,
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(body),
        },
    };

    const req = https.request(options, (res) => {
        if (res.statusCode >= 400) {
            console.error(`[Discord] Error al enviar notificación: ${res.statusCode} para ${body}`);
        }
    });

    req.on('error', (error) => {
        console.error('[Discord] Error de conexión Discord:', error.message);
    });

    req.write(body);
    req.end();
}

module.exports = { sendDiscordNotification };