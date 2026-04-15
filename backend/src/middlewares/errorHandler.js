const { sendDiscordNotification } = require('../../utils/discord');
// Usamos el manejador de utils local si migramos sendDiscordNotification, o el original 
// de backend/utils/discord.js. Por ahora el original.

const errorHandler = (err, req, res, next) => {
    err.statusCode = err.statusCode || 500;
    err.status = err.status || 'error';

    // Log the error in console
    console.error(`[❌ ERROR] ${err.statusCode} - ${err.message}`);
    if (err.statusCode === 500) {
        console.error(err.stack);
        
        // Notify Discord for critical unhandled errors
        try {
            sendDiscordNotification({
                embeds: [{
                    title: '🚨 Error Interno Crítico (500)',
                    description: `Un error incontrolado ocurrió en el endpoint \`${req.originalUrl}\`\n\n**Mensaje:** ${err.message}\n\`\`\`\n${err.stack.substring(0, 500)}...\n\`\`\``,
                    color: 0xE74C3C, // Rojo
                    fields: [
                        { name: 'IP', value: req.ip || 'Desconocida', inline: true },
                        { name: 'Método', value: req.method, inline: true }
                    ]
                }]
            });
        } catch (discordErr) {
            console.error('Fallo al enviar notificación a Discord:', discordErr);
        }
    }

    // Send the response
    res.status(err.statusCode).json({
        status: err.status,
        error: err.message,
        // Send stack trace only in development
        ...(process.env.NODE_ENV !== 'production' && { stack: err.stack })
    });
};

module.exports = errorHandler;
