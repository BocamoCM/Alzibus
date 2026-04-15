const statRepository = require('../repositories/stat.repository');
const { sendDiscordNotification } = require('../../utils/discord');
const { sendContactNotification } = require('../../utils/email');

class StatService {
    async getGeneralStats() { return await statRepository.getGeneralStats(); }
    async getUsageStats(period) { return await statRepository.getUsageStats(period); }
    async getActivityStats() { return await statRepository.getActivityStats(); }
    async getTopStops() { return await statRepository.getTopStops(); }
    async getPeakHours() { return await statRepository.getPeakHours(); }
    async getDashboard(period) { return await statRepository.getDashboard(period); }
    async getPublicStats() { return await statRepository.getPublicStats(); }

    async logAlert({ stopName, line, destination }) {
        sendDiscordNotification(`🔔 **Alerta Activada**: Usuario esperando \`${line} -> ${destination}\` en **${stopName}**`);
        return { success: true };
    }

    async logWebMetric(ip, userAgent, data) {
        const { event_type } = data;
        await statRepository.logWebMetric(ip, userAgent, event_type);

        if (event_type === 'download_click') {
            let device = 'Móvil o Web';
            if (/android/i.test(userAgent)) device = 'Android 🤖';
            else if (/iphone|ipad|ipod/i.test(userAgent)) device = 'iOS 🍏';

            sendDiscordNotification({
                embeds: [{
                    title: "📥 Nuevo Click en Descarga (Web)",
                    description: "Un usuario ha pulsado el botón de descarga.",
                    color: 0x00FF00,
                    fields: [
                        { name: "Dispositivo", value: device, inline: true },
                        { name: "IP", value: ip, inline: true }
                    ]
                }]
            });
        }
        return { success: true };
    }

    async logInstall(ip, referrer) {
        sendDiscordNotification({
            embeds: [{
                title: '🎉 Nueva Instalación de la App',
                description: `Alguien acaba de instalar y abrir la app por primera vez.`,
                color: 0x2ECC71, // Verde
                fields: [
                    { name: 'Referrer', value: referrer || 'Orgánico', inline: true },
                    { name: 'IP', value: ip || 'Desconocida', inline: true }
                ]
            }]
        });
        return { success: true };
    }

    async logAppOpen(ip, email) {
        sendDiscordNotification({
            embeds: [{
                title: '📱 Aplicación Abierta',
                description: `Un usuario ha entrado en la app Alzitrans.`,
                color: 0x3498DB,
                fields: [
                    { name: 'Usuario', value: email, inline: true },
                    { name: 'IP', value: ip || 'Desconocida', inline: true }
                ]
            }]
        });
        return { success: true };
    }

    async postContact(ip, data) {
        const { name, email, subject, message, website } = data;

        if (website) return { success: true, message: 'Mensaje enviado correctamente' }; // Honeypot
        if (!name || !email || !message) throw new Error('Campos obligatorios requeridos');
        if (message.length < 5) throw new Error('El mensaje es demasiado corto');

        sendDiscordNotification({
            embeds: [{
                title: "📧 Mensaje de Contacto (Web)",
                color: 0x3498db,
                fields: [
                    { name: "👤 Nombre", value: name, inline: true },
                    { name: "📧 Email", value: email, inline: true },
                    { name: "📌 Asunto", value: subject || 'Sin asunto', inline: false },
                    { name: "💬 Mensaje", value: `\`\`\`${message}\`\`\``, inline: false },
                    { name: "🌍 IP", value: ip, inline: true }
                ],
                timestamp: new Date(),
                footer: { text: "Alzitrans Web Contact" }
            }]
        });

        sendContactNotification({ name, email, subject, message }).catch(err => console.error(err));
        return { success: true, message: 'Mensaje enviado correctamente' };
    }
}

module.exports = new StatService();
