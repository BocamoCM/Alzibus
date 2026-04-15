// ============================================================
// server.js — Servidor principal del backend de Alzitrans
// ============================================================
const path = require('path');                     // Módulo para manejar rutas de archivos
// Este archivo es el punto de entrada del backend. Configura:
// - Express como framework HTTP
// - Socket.IO para comunicación en tiempo real (WebSockets)
// - PostgreSQL como base de datos (vía pool de conexiones)
// - Stripe para pagos Premium
// - JWT para autenticación de usuarios
// - Nodemailer para envío de emails (verificación OTP)
// - Helmet y CORS para seguridad HTTP
// - Rate limiting para protección contra ataques de fuerza bruta
// - Discord webhooks para notificaciones al equipo de desarrollo
// ============================================================

const express = require('express');               // Framework web para crear la API REST
const { sendDiscordNotification } = require('./utils/discord'); // Utilidad para enviar alertas a Discord
const { sendEmail, sendContactNotification } = require('./utils/email'); // Utilidad para correos
const http = require('http');                     // Módulo HTTP nativo de Node.js (necesario para Socket.IO)
const socketIo = require('socket.io');            // WebSockets para comunicación bidireccional en tiempo real
const cors = require('cors');                     // Middleware para permitir peticiones desde otros dominios (Cross-Origin)
const bcrypt = require('bcrypt');                 // Librería para hashear contraseñas de forma segura (bcrypt con salt)
const jwt = require('jsonwebtoken');              // JSON Web Tokens para autenticación stateless
const rateLimit = require('express-rate-limit');  // Limita el número de peticiones por IP (anti brute-force y DDoS)
const nodemailer = require('nodemailer');          // Envío de emails SMTP (usado para códigos OTP de verificación)
const helmet = require('helmet');                 // Establece cabeceras HTTP de seguridad (X-Frame-Options, CSP, etc.)
const pool = require('./db');                     // Pool de conexiones a PostgreSQL (importado desde db.js)
require('dotenv').config();                       // Carga las variables de entorno desde el archivo .env

const app = express();                // Instancia de la aplicación Express
const server = http.createServer(app); // Servidor HTTP que envuelve Express (necesario para poder adjuntar Socket.IO)

// ==========================================
// CONFIGURACIÓN DE PROXY (Caddy / Nginx)
// ==========================================
// Al estar detrás de Caddy, todas las peticiones llegan localmente (127.0.0.1).
// Esto le dice a Express que lea la IP real del usuario desde los headers (X-Forwarded-For).
app.set('trust proxy', 1);

// Configuración de CORS dinámica:
// Lee los orígenes permitidos desde la variable de entorno ALLOWED_ORIGINS (separados por comas).
// Si no está definida, permite todos los orígenes ('*') — solo recomendable en desarrollo.
const allowedOrigins = process.env.ALLOWED_ORIGINS ? process.env.ALLOWED_ORIGINS.split(',') : ['*'];

// Inicializar Socket.IO sobre el servidor HTTP.
// Socket.IO permite enviar eventos en tiempo real a todos los clientes conectados
// (por ejemplo, cuando se crea un nuevo aviso desde el panel de admin,
// se emite un evento 'new_notice' y la app lo recibe al instante).
const io = socketIo(server, {
    pingTimeout: 60000,
    pingInterval: 25000,
    cors: {
        origin: (origin, callback) => callback(null, true),
        methods: ["GET", "POST"]
    }
});

// Logs de depuración para WebSockets
io.on('connection', (socket) => {
    console.log(`[Socket.IO] Nuevo cliente conectado: ${socket.id} desde ${socket.handshake.address}`);

    socket.on('disconnect', (reason) => {
        console.log(`[Socket.IO] Cliente desconectado (${socket.id}): ${reason}`);
    });
});



// ── Middleware de depuración ──
// Solo activo fuera de producción para no saturar los logs de Caddy con cada petición.
if (process.env.NODE_ENV !== 'production') {
    app.use((req, res, next) => {
        console.log(`[DEBUG] ${req.method} ${req.url} desde ${req.ip}`);
        next();
    });
}

// ── Middlewares de seguridad ──

// Helmet: Añade automáticamente cabeceras HTTP de seguridad a todas las respuestas:
// - X-Content-Type-Options: nosniff (evita que el navegador adivine tipos MIME)
// - X-Frame-Options: SAMEORIGIN (previene clickjacking)
// - Strict-Transport-Security (fuerza HTTPS)
// crossOriginResourcePolicy: false → permite que otros dominios carguen recursos (necesario para CORS)
app.use(helmet({
    crossOriginResourcePolicy: false,
}));

// CORS: Permite que la app Flutter (y el panel admin web) hagan peticiones a esta API
// desde un dominio diferente. Sin esto, el navegador bloquearía las peticiones.
app.use(cors({
    origin: true,                                                      // Acepta cualquier origen (se refina con allowedOrigins en Socket.IO)
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],     // Métodos HTTP permitidos
    allowedHeaders: ['Content-Type', 'Authorization', 'X-API-Key'],    // Headers que el cliente puede enviar
    credentials: true,                                                  // Permite enviar cookies/tokens entre dominios
    preflightContinue: false,                                           // No pasa las peticiones OPTIONS al siguiente handler
    optionsSuccessStatus: 204                                           // Responde 204 (No Content) a las preflight requests
}));
// ── Servir app-ads.txt (Requerido por AdMob) ──
app.get('/app-ads.txt', (req, res) => {
    res.setHeader('Content-Type', 'text/plain');
    res.sendFile(path.join(__dirname, 'app-ads.txt'));
});

// ── Smart QR Tracker (Redirección dinámica) ──
// Intercepta escaneos de códigos QR físicos, registra en BD, avisa a Discord y redirige.
app.get('/qr', async (req, res) => {
    const userAgent = req.get('User-Agent') || 'Desconocido';
    const ip = req.ip || req.headers['x-forwarded-for'] || req.socket.remoteAddress;
    const source = req.query.src || 'qr_paradas'; // Permite trackear distintos carteles
    const stopId = req.query.id ? parseInt(req.query.id) : null;
    const stopName = req.query.name || null;

    // Detección simple pero efectiva de dispositivo
    let device = 'Móvil o Web';
    let emoji = '📱';
    if (/android/i.test(userAgent)) { device = 'Android'; emoji = '🤖'; }
    else if (/iphone|ipad|ipod/i.test(userAgent)) { device = 'iOS (iPhone/iPad)'; emoji = '🍏'; }
    else if (/windows/i.test(userAgent)) { device = 'Windows'; emoji = '💻'; }
    else if (/macintosh|mac os x/i.test(userAgent)) { device = 'macOS'; emoji = '🍎'; }
    else if (/linux/i.test(userAgent)) { device = 'Linux'; emoji = '🐧'; }

    // 1. Registrar en la Base de Datos para métricas detalladas (Asíncrono)
    try {
        await pool.query(
            'INSERT INTO qr_scans (ip, user_agent, device, source, stop_id, stop_name) VALUES ($1, $2, $3, $4, $5, $6)',
            [ip, userAgent, device, source, stopId, stopName]
        );
    } catch (err) {
        console.error('[ERROR] Error al registrar scan de QR:', err.message);
    }

    // 2. Enviar notificación a Discord con Embed enriquecido
    const stopInfo = stopName ? `\n📍 Parada: **${stopName}** (#${stopId})` : '';
    sendDiscordNotification({
        embeds: [{
            title: `${emoji} Nuevo Escaneo de QR detectado`,
            color: 0xff4757, // Coral Alzitrans
            description: `Se ha escaneado un código físico de la campaña **${source}**. ${stopInfo}`,
            fields: [
                { name: "Dispositivo", value: `${emoji} ${device}`, inline: true },
                { name: "Origen", value: `📍 ${source}`, inline: true },
                { name: "Parada", value: stopName || 'No especificada', inline: true },
                { name: "IP (Ofuscada)", value: `||${ip.substring(0, 7)}...||`, inline: true },
                { name: "User-Agent", value: `\`\`\`${userAgent.substring(0, 150)}...\`\`\``, inline: false }
            ],
            timestamp: new Date(),
            footer: { text: "Telemetría Alzitrans" }
        }]
    });

    // 3. Redirigir a la landing page de descarga
    res.redirect(`/descargar?src=${source}`);
});

// (La ruta de Install Tracker fue movida a stat.routes.js)

// express.json(): Middleware que parsea el body de las peticiones con Content-Type: application/json.
// Convierte el body JSON en un objeto JavaScript accesible en req.body.
// DEBE ir después del webhook de Stripe (que necesita el body crudo).
app.use(express.json());

// ==========================================
// SEGURIDAD: CONTROL DE ACCESOS Y BLOQUEOS
// ==========================================
const failedApiKeyLog = {}; // Registro de fallos por IP: { '1.2.3.4': 5 }
const bannedIps = new Set(); // IPs bloqueadas temporalmente

const MAX_API_KEY_FAILURES = 10;   // Umbral de fallos antes del baneo
const BAN_DURATION = 24 * 60 * 60 * 1000; // Duración del baneo (24 horas)

// Middleware: Validación de API Key con Protección Anti-BruteForce
const validateApiKey = (req, res, next) => {
    const ip = req.ip;

    // 1. Verificar si la IP está en la lista negra
    if (bannedIps.has(ip)) {
        return res.status(403).json({
            error: 'Acceso denegado de forma persistente. IP bloqueada por seguridad.'
        });
    }

    if (req.method === 'OPTIONS') {
        return next();
    }

    // Excepciones: Rutas que no requieren API Key (Ej: Landing Page o Health Check)
    const originalPath = req.originalUrl.split('?')[0]; // Limpiar query params si los hubiera
    const publicRoutes = ['/api/stats/public', '/api/health', '/api/metrics/web', '/api/contact'];

    if (publicRoutes.includes(originalPath)) {
        return next();
    }

    const apiKey = req.headers['x-api-key'];

    if (!apiKey || apiKey !== process.env.API_KEY) {
        // Registrar el fallo
        failedApiKeyLog[ip] = (failedApiKeyLog[ip] || 0) + 1;

        console.warn(`[API Key] Fallo (${failedApiKeyLog[ip]}/${MAX_API_KEY_FAILURES}) desde ${ip}: ${req.method} ${req.url}`);

        // Si supera el umbral, bloquear IP
        if (failedApiKeyLog[ip] >= MAX_API_KEY_FAILURES) {
            bannedIps.add(ip);
            console.error(`[SECURITY] 🚫 IP BLOQUEADA: ${ip} tras ${MAX_API_KEY_FAILURES} intentos fallidos.`);

            // Notificar a Discord con Embed Rojo
            sendDiscordNotification({
                embeds: [{
                    title: "🚫 IP Bloqueada Automáticamente",
                    description: `Se ha detectado un posible ataque de escaneo desde la IP **${ip}**.`,
                    color: 0xFF0000,
                    fields: [
                        { name: "IP", value: `\`${ip}\``, inline: true },
                        { name: "Intentos", value: `\`${failedApiKeyLog[ip]}\``, inline: true },
                        { name: "Ruta final", value: `\`${req.method} ${req.url}\``, inline: false },
                        { name: "Acción", value: "Baneo temporal (24h)", inline: false }
                    ],
                    footer: { text: "Alzitrans Shield System" }
                }]
            });

            // Programar desbloqueo automático
            setTimeout(() => {
                bannedIps.delete(ip);
                delete failedApiKeyLog[ip];
                console.log(`[SECURITY] IP Desbloqueada: ${ip}`);
            }, BAN_DURATION);

        } else {
            // Notificar fallo simple (sin ban todavía)
            sendDiscordNotification(`⚠️ **Petición rechazada** (${failedApiKeyLog[ip]}/${MAX_API_KEY_FAILURES}): API Key inválida desde ${ip} para \`${req.method} ${req.url}\``);
        }

        return res.status(401).json({ error: 'API Key inválida o no proporcionada' });
    }

    // Si la API Key es válida, resetear el contador de fallos para esta IP (por si acaso)
    delete failedApiKeyLog[ip];
    next();
};

// ── Inicialización de Tablas (Web Metrics) ──
async function initDatabase() {
    try {
        await pool.query(`
            CREATE TABLE IF NOT EXISTS web_metrics (
                id SERIAL PRIMARY KEY,
                event_type VARCHAR(50) NOT NULL,
                ip VARCHAR(45),
                user_agent TEXT,
                created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
            );
            CREATE INDEX IF NOT EXISTS idx_web_metrics_event ON web_metrics(event_type);
            CREATE INDEX IF NOT EXISTS idx_web_metrics_date ON web_metrics(created_at);
        `);
        console.log('✅ Base de datos verificada (web_metrics ok)');
    } catch (err) {
        console.error('❌ Error inicializando base de datos:', err);
    }
}
initDatabase();

app.use('/api', validateApiKey);

// ── Endpoint de salud (Health Check) ──
// Endpoint simple que responde "ok" sin consultar la base de datos.
// Se usa desde la app Flutter para verificar si el servidor está vivo
// antes de intentar operaciones más complejas (login, registro, etc.).
// También útil para monitorizar el servidor con herramientas externas.
app.get('/api/health', (req, res) => {
    res.json({ status: 'ok', message: 'Backend Alzibus alcanzable' });
});

// ── Proxy para Tiempos de Bus (Bypass CORS para Web) ──
// Este endpoint actúa como un puente entre la App Web (Frontend) y el servidor
// de Autocares Lozano. Los navegadores bloquean peticiones directas por CORS,
// pero el servidor (Backend) puede hacerlas sin restricciones.
app.get('/api/proxy/bus-times', async (req, res) => {
    const stopId = req.query.id;
    if (!stopId) return res.status(400).json({ error: 'stopId is required' });

    const https = require('https');
    const targetUrl = `https://servidor.autocareslozano.es/Alzira/webtiempos/PopupPoste.aspx?id=${stopId}`;

    console.log(`[Proxy] Solicitando tiempos para parada ${stopId}...`);

    https.get(targetUrl, (proxyRes) => {
        let data = '';
        proxyRes.on('data', (chunk) => { data += chunk; });
        proxyRes.on('end', () => {
            res.setHeader('Content-Type', 'text/html');
            res.send(data);
        });
    }).on('error', (err) => {
        console.error('[Proxy] Error:', err.message);
        res.status(500).json({ error: 'Error al contactar con el servidor de transporte' });
    });
});


// ── Rutas públicas para cumplimiento de Google Play ──
// Google Play requiere que las apps tengan una URL pública accesible para:
// 1. Política de privacidad: obligatoria para publicar en Play Store.
// 2. Eliminación de cuenta: obligatoria desde 2023 para cumplir con las
//    políticas de datos de usuario (los usuarios deben poder borrar su cuenta).
// Estas rutas sirven archivos HTML/Markdown estáticos sin requerir autenticación.


// Página web pública donde el usuario puede solicitar la eliminación de su cuenta
app.get('/delete-account', (req, res) => {
    res.sendFile(path.join(__dirname, 'delete-account.html'));
});

// Página web pública con la política de privacidad de la app
app.get('/privacy-policy', (req, res) => {
    const fs = require('fs');
    const marked = require('marked');
    res.sendFile(path.join(__dirname, 'POLITICA_PRIVACIDAD_ALZITRANS.md'));
});

// ── app-ads.txt para verificación de AdMob ──
// Google AdMob requiere que el archivo app-ads.txt esté accesible en la raíz
// del dominio del desarrollador para autorizar fuentes de anuncios.
// Debe ser público (sin autenticación ni API Key).
app.get('/app-ads.txt', (req, res) => {
    res.type('text/plain').send('google.com, pub-5215993257564469, DIRECT, f08c47fec0942fa0\n');
});

// ── Middleware de logging de peticiones API ──
// Registra cada petición en la tabla 'api_logs' de PostgreSQL.
// Guarda: endpoint (ruta), método HTTP y tiempo de respuesta en ms.
// Esto alimenta las gráficas de estadísticas del panel de administración
// (uso diario, horas pico, rendimiento de endpoints, etc.).
// Se excluyen las rutas /api/stats para no crear un bucle infinito de logs.
app.use((req, res, next) => {
    const start = Date.now(); // Marca de tiempo al inicio de la petición
    // El evento 'finish' se dispara cuando la respuesta se ha enviado completamente
    res.on('finish', () => {
        const duration = Date.now() - start; // Calcular duración total en milisegundos
        // Excluir peticiones de estadísticas para no inflar los números de uso
        if (!req.path.startsWith('/api/stats')) {
            pool.query(
                'INSERT INTO api_logs (endpoint, method, duration_ms) VALUES ($1, $2, $3)',
                [req.path, req.method, duration]
            ).catch(err => console.error('Error logging API request:', err));
        }
    });
    next();
});

// Puerto en el que escuchará el servidor. Se lee de .env o usa 4000 por defecto.
const PORT = process.env.PORT || 4000;

// ── CONEXIÓN DE MÓDULOS DE ARQUITECTURA HEXAGONAL ──
app.use('/api', require('./src/routes/auth.routes'));
app.use('/api', require('./src/routes/user.routes'));
app.use('/api', require('./src/routes/notice.routes'));
app.use('/api', require('./src/routes/stop.routes'));
app.use('/api', require('./src/routes/trip.routes'));
app.use('/api', require('./src/routes/feedback.routes'));
app.use('/api', require('./src/routes/stat.routes'));


// ── Endpoint de diagnóstico para WebSockets ──
// Permite que la app móvil reporte si recibió un evento correctamente a través de Discord.
app.post('/api/debug/mobile-log', async (req, res) => {
    const { message, data } = req.body;
    const ip = req.ip || req.headers['x-forwarded-for'];
    console.log(`[DEBUG MOBILE] (${ip}): ${message}`);
    
    sendDiscordNotification({
        embeds: [{
            title: '🛠 Diagnóstico Móvil',
            description: message,
            color: 0x9B59B6, // Púrpura
            fields: [
                { name: 'IP', value: ip || 'Desconocida', inline: true },
                { name: 'Data', value: JSON.stringify(data || {}), inline: false }
            ],
            footer: { text: 'Alzitrans Debug Bridge' }
        }]
    });
    res.json({ success: true });
});

// ── Reporte diario automático a Discord ──
let lastReportDate = '';

setInterval(async () => {
    const now = new Date();
    const todayStr = now.toISOString().split('T')[0];

    if (now.getHours() === 0 && lastReportDate !== todayStr) {
        lastReportDate = todayStr;
        try {
            const yesterday = new Date(now);
            yesterday.setDate(yesterday.getDate() - 1);
            const yStr = yesterday.toISOString().split('T')[0];

            const usersRes = await pool.query("SELECT COUNT(*) FROM users WHERE created_at::date = $1", [yStr]);
            const tripsRes = await pool.query("SELECT COUNT(*) FROM trips WHERE timestamp::date = $1", [yStr]);
            const lineRes = await pool.query(
                "SELECT line, COUNT(*) as cnt FROM trips WHERE timestamp::date = $1 GROUP BY line ORDER BY cnt DESC LIMIT 1",
                [yStr]
            );

            const userCount = usersRes.rows[0].count;
            const tripCount = tripsRes.rows[0].count;
            const topLine = lineRes.rows[0]?.line || 'Ninguna';

            const activeRes = await pool.query("SELECT COUNT(DISTINCT id) FROM users WHERE last_access::date = $1", [yStr]);
            const totalRes = await pool.query("SELECT COUNT(*) FROM users WHERE is_verified = true");
            const activeCount = activeRes.rows[0].count;
            const totalUsers = totalRes.rows[0].count;

            const message = `📊 **RESUMEN DIARIO (${yStr})**\n` +
                `━━━━━━━━━━━━━━━━━━━━\n` +
                `👤 **Usuarios nuevos**: \`${userCount}\`\n` +
                `👥 **Usuarios activos ayer**: \`${activeCount}\`\n` +
                `📱 **Total registrados**: \`${totalUsers}\`\n` +
                `🎫 **Viajes validados**: \`${tripCount}\`\n` +
                `🚌 **Línea estrella**: \`${topLine}\`\n` +
                `━━━━━━━━━━━━━━━━━━━━`;

            sendDiscordNotification(message);
        } catch (e) {
            console.error('[Dashboard] Fallo al generar reporte diario:', e);
        }
    }
}, 300000); 

// ── MANEJADOR GLOBAL DE ERRORES (Arquitectura Hexagonal) ──
const errorHandler = require('./src/middlewares/errorHandler');
app.use(errorHandler);

// ── Iniciar el servidor HTTP ──
// Escucha en todas las interfaces de red ('0.0.0.0') para aceptar
// conexiones tanto locales como remotas (importante para la Raspberry Pi).
// El puerto se lee de la variable de entorno PORT o usa 4000 por defecto.
server.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Servidor y WebSockets corriendo en puerto ${PORT}`);
});
