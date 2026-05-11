const statRepository = require('../repositories/stat.repository');
const { sendDiscordNotification } = require('../../utils/discord');
const { sendContactNotification } = require('../../utils/email');
const { parseUserAgent } = require('../utils/ua-parser');

// Whitelist de valores aceptados (evita inyección y datos chatarra)
const VALID_SOURCES   = new Set(['landing', 'web_app', 'mobile_app']);
const VALID_PLATFORMS = new Set(['android', 'ios', 'windows', 'macos', 'linux', 'web', 'unknown']);

function sanitizeSource(s)   { return VALID_SOURCES.has(s)   ? s : 'unknown'; }
function sanitizePlatform(p) { return VALID_PLATFORMS.has(p) ? p : 'unknown'; }

class StatService {
    async getGeneralStats() { return await statRepository.getGeneralStats(); }
    async getUsageStats(period) { return await statRepository.getUsageStats(period); }
    async getActivityStats() { return await statRepository.getActivityStats(); }
    async getTopStops() { return await statRepository.getTopStops(); }
    async getPeakHours() { return await statRepository.getPeakHours(); }
    async getDashboard(period) { return await statRepository.getDashboard(period); }
    async getPublicStats() { return await statRepository.getPublicStats(); }
    async getTelemetry(period) { return await statRepository.getTelemetryBreakdown(period); }

    async logAlert({ stopName, line, destination }) {
        sendDiscordNotification(`🔔 **Alerta Activada**: Usuario esperando \`${line} -> ${destination}\` en **${stopName}**`);
        return { success: true };
    }

    async logWebMetric(ip, userAgent, data) {
        const { event_type } = data;
        const parsed = parseUserAgent(userAgent);

        // source/platform: si la app los envía explícitamente, prevalecen sobre el UA.
        const source   = sanitizeSource(data.source || 'landing');
        const platform = sanitizePlatform(data.platform || parsed.platform);
        const browser  = parsed.browser;

        await statRepository.logWebMetric(ip, userAgent, event_type, source, platform, browser);

        if (event_type === 'download_click') {
            let device = 'Móvil o Web';
            if (platform === 'android') device = 'Android 🤖';
            else if (platform === 'ios') device = 'iOS 🍏';
            else if (platform === 'windows') device = 'Windows 🪟';
            else if (platform === 'macos') device = 'macOS 🍎';
            else if (platform === 'linux') device = 'Linux 🐧';

            sendDiscordNotification({
                embeds: [{
                    title: "📥 Nuevo Click en Descarga (Web)",
                    description: "Un usuario ha pulsado el botón de descarga.",
                    color: 0x00FF00,
                    fields: [
                        { name: "Dispositivo", value: device, inline: true },
                        { name: "Origen", value: source, inline: true },
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

    async logAppOpen(ip, email, userAgent, data = {}) {
        const parsed = parseUserAgent(userAgent);
        // La app debe enviar source ('mobile_app' o 'web_app') y platform; si no, deducimos del UA
        const source   = sanitizeSource(data.source || 'mobile_app');
        const platform = sanitizePlatform(data.platform || parsed.platform);
        const browser  = parsed.browser;

        // event: 'app_open' (arranque) | 'login' (tras autenticar). Por defecto 'app_open'.
        const event = (data.event === 'login') ? 'login' : 'app_open';

        // Persistir en web_metrics con el event_type recibido para que la consulta
        // de telemetría agregue mobile_app + web_app + landing en una sola tabla.
        try {
            await statRepository.logWebMetric(ip, userAgent, event, source, platform, browser);
        } catch (e) {
            console.error('[telemetry] logAppOpen DB error:', e.message);
        }

        // Emojis legibles por plataforma
        const platformEmoji = {
            android: '🤖 Android',
            ios:     '🍏 iOS',
            windows: '🪟 Windows',
            macos:   '🍎 macOS',
            linux:   '🐧 Linux',
            web:     '🌐 Web',
            unknown: '❓ Desconocida',
        }[platform] || `❓ ${platform}`;

        const sourceLabel = {
            mobile_app: '📲 App móvil',
            web_app:    '💻 App web',
            landing:    '🌐 Landing',
        }[source] || source;

        // Diferenciar el embed según sea arranque o login
        const isLogin = event === 'login';
        sendDiscordNotification({
            embeds: [{
                title: isLogin ? '🔓 Inicio de Sesión' : '📱 Aplicación Abierta',
                description: isLogin
                    ? 'Un usuario ha iniciado sesión en Alzitrans.'
                    : 'Un usuario ha entrado en la app Alzitrans.',
                color: isLogin ? 0x9b59b6 : 0x3498DB,
                fields: [
                    { name: 'Usuario',    value: email,         inline: true },
                    { name: 'Origen',     value: sourceLabel,   inline: true },
                    { name: 'Plataforma', value: platformEmoji, inline: true },
                    { name: 'IP',         value: ip || 'Desconocida', inline: true }
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
