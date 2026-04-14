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
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY); // SDK de Stripe inicializado con la clave secreta

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
    cors: {
        origin: (origin, callback) => callback(null, true), // Permitir todos los orígenes en Socket.IO
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

io.engine.on("connection_error", (err) => {
    console.log(`[Socket.IO Engine Error] ${err.code}: ${err.message}`);
    console.log(`[Socket.IO Engine context]:`, err.context);
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

// ── Smart App Install Tracker ──
// Recibe un ping de la app la primera vez que se abre si procede de la Google Play originada por un QR.
app.post('/api/metrics/install', express.json(), (req, res) => {
    const { referrer } = req.body;

    // Filtramos para notificar en Discord solo las descargas atribuidas a nuestra campaña de paradas.
    if (referrer && referrer.includes('qr_paradas')) {
        sendDiscordNotification({
            embeds: [{
                title: "🎉 ¡NUEVA INSTALACIÓN DETECTADA! 🎉",
                description: "¡Éxito! Un usuario ha instalado y abierto la app desde el **QR físico**.",
                color: 0xD4AF37, // Gold
                fields: [{ name: "Origen", value: "Campaña QR Paradas" }]
            }]
        });
    } else if (referrer && referrer.includes('utm_source')) {
        sendDiscordNotification({
            embeds: [{
                title: "📈 Nueva Instalación (Marketing)",
                description: `Se ha completado una descarga desde una campaña externa.`,
                fields: [{ name: "Campaña", value: `\`${referrer}\`` }]
            }]
        });
    }

    // Devolvemos status 200 sin bloquear a la app móvil.
    res.status(200).json({ received: true });
});

// ── Webhook de Stripe ──
// IMPORTANTE: Este endpoint DEBE estar definido ANTES de express.json().
// Razón: Stripe envía el body como datos crudos (raw bytes), y express.json()
// lo parseaería como JSON antes de que podamos validar la firma criptográfica.
// La firma se genera sobre los bytes originales, no sobre el JSON parseado.
//
// Flujo del webhook:
// 1. Stripe envía un POST a esta URL cuando ocurre un evento de pago.
// 2. Verificamos que la firma del header 'stripe-signature' coincida con nuestro secret.
// 3. Si el pago fue exitoso (payment_intent.succeeded), activamos Premium al usuario.
// 4. Respondemos 200 para que Stripe sepa que procesamos el webhook correctamente.
app.post('/api/payments/webhook', express.raw({ type: 'application/json' }), async (req, res) => {
    const sig = req.headers['stripe-signature']; // Firma criptográfica enviada por Stripe
    let event;

    try {
        // Si no hay webhook secret configurado, estamos en modo desarrollo:
        // parseamos el body directamente sin validar firma (NO SEGURO para producción)
        if (!process.env.STRIPE_WEBHOOK_SECRET || process.env.STRIPE_WEBHOOK_SECRET === 'whsec_...') {
            console.warn('[Webhook] STRIPE_WEBHOOK_SECRET no configurado. Procesando sin validar firma (SOLO DESARROLLO)');
            event = JSON.parse(req.body);
        } else {
            // En producción: validar la firma criptográfica para asegurar que
            // el webhook realmente viene de Stripe y no de un atacante
            event = stripe.webhooks.constructEvent(req.body, sig, process.env.STRIPE_WEBHOOK_SECRET);
        }
    } catch (err) {
        console.error(`[Webhook] Error de firma: ${err.message}`);
        return res.status(400).send(`Webhook Error: ${err.message}`);
    }

    // Solo procesamos el evento de "pago completado exitosamente"
    if (event.type === 'payment_intent.succeeded') {
        const paymentIntent = event.data.object;      // Objeto completo del PaymentIntent
        const userId = paymentIntent.metadata.userId;  // ID del usuario que pagó (se envió como metadata al crear el intent)

        if (userId) {
            try {
                // Marcar al usuario como Premium en la base de datos
                await pool.query('UPDATE users SET is_premium = TRUE WHERE id = $1', [userId]);
                console.log(`[Stripe] Usuario ${userId} ahora es PREMIUM`);
                // Notificar al equipo vía Discord
                sendDiscordNotification(`💎 **Nuevo Usuario Premium**: El usuario ID \`${userId}\` ha completado su pago.`);
            } catch (dbErr) {
                console.error('[Stripe] Error actualizando DB:', dbErr);
            }
        }
    }

    // Siempre responder 200 a Stripe para confirmar recepción del webhook
    res.json({ received: true });
});

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
    const publicRoutes = ['/api/stats/public', '/api/health', '/api/metrics/web'];

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

// ==========================================
// MIDDLEWARE: AUTENTICACIÓN JWT
// ==========================================
// Este middleware protege las rutas que requieren un usuario autenticado.
// Funciona así:
// 1. El cliente (app Flutter) envía el header: Authorization: Bearer <token>
// 2. Extraemos el token del header.
// 3. Verificamos que el token sea válido y no haya expirado usando jwt.verify().
// 4. Si es válido, el payload del token (id, email del usuario) se guarda en req.user
//    para que los endpoints siguientes sepan quién es el usuario.
// 5. Si no es válido, se rechaza la petición con 403 (Forbidden).
const authenticateToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];     // Leer el header "Authorization"
    const token = authHeader && authHeader.split(' ')[1]; // Extraer el token después de "Bearer "
    if (!token) return res.status(401).json({ error: 'Token requerido' }); // No hay token → 401
    // Verificar el token con la clave secreta (JWT_SECRET del .env)
    jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
        if (err) return res.status(403).json({ error: 'Token inválido o expirado' }); // Token malo → 403
        req.user = user; // Guardar datos del usuario decodificados en la petición
        next();          // Token válido → continuar al endpoint
    });
};



// ==========================================
// LIMITADORES DE FRECUENCIA (RATE LIMITING)
// ==========================================
// Los rate limiters protegen contra abusos y ataques de fuerza bruta.
// Cada limiter tiene una ventana de tiempo y un máximo de peticiones por IP.
// Si se supera el límite, se devuelve un error 429 (Too Many Requests).

// Limita la creación de cuentas nuevas:
// Máximo 5 registros por hora desde la misma IP.
// Previene la creación masiva de cuentas falsas.
const registerLimiter = rateLimit({
    windowMs: 60 * 60 * 1000, // Ventana de 1 hora (en milisegundos)
    max: 5,                    // Máximo 5 peticiones por ventana
    message: { error: 'Demasiadas cuentas creadas. Reinténtalo en una hora.' },
    standardHeaders: true,     // Devuelve info de rate limit en headers estándar (RateLimit-*)
    legacyHeaders: false,      // No enviar los headers legacy X-RateLimit-*
});

// Limita intentos de inicio de sesión (Anti Bruteforce):
// Máximo 10 intentos cada 15 minutos desde la misma IP.
// Si se excede, notifica a Discord para alertar de un posible ataque.
const loginLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // Ventana de 15 minutos
    max: 10,                   // Máximo 10 intentos
    message: { error: 'Demasiados intentos de inicio de sesión. Reinténtalo en 15 minutos.' },
    standardHeaders: true,
    legacyHeaders: false,
    // Handler personalizado: además de rechazar, notifica a Discord
    handler: (req, res, next, options) => {
        sendDiscordNotification(`🛡️ **Brute Force bloqueado**: Múltiples fallos de login desde IP ${req.ip}`);
        res.status(options.statusCode).send(options.message);
    }
});

// ── Middleware de autenticación de Administrador ──
// Similar a authenticateToken, pero además verifica que el usuario
// tenga el rol 'admin' en el payload del JWT.
// Solo los tokens generados en /api/admin/login tienen role: 'admin'.
const authenticateAdmin = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) return res.status(401).json({ error: 'Token de administrador requerido' });

    jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
        // Si el token es inválido O el rol no es 'admin', denegar acceso
        if (err || user.role !== 'admin') {
            return res.status(403).json({ error: 'Acceso denegado: Se requieren privilegios de administrador' });
        }
        req.user = user; // Guardar datos del admin en la petición
        next();
    });
};

// ==========================================
// ENDPOINT: LOGIN DE ADMINISTRADOR
// ==========================================
// El panel de administración web (dashboard.html) usa este endpoint para
// autenticarse. Solo requiere una contraseña única definida en ADMIN_PASSWORD (.env).
// Al autenticarse, genera un JWT con role: 'admin' que dura 12 horas.
// Este token se usa luego en las peticiones al panel admin.
app.post('/api/admin/login', loginLimiter, async (req, res) => {
    const { password } = req.body;

    if (!password) {
        return res.status(400).json({ error: 'Contraseña requerida' });
    }

    // Comparar la contraseña recibida con la almacenada en la variable de entorno
    if (password === process.env.ADMIN_PASSWORD) {
        // Generar un JWT de administrador con 12 horas de validez
        const token = jwt.sign(
            { id: 'admin', email: 'admin@alzitrans.com', role: 'admin' },
            process.env.JWT_SECRET,
            { expiresIn: '12h' }
        );
        sendDiscordNotification(`🔏 **Panel Admin**: Sesión iniciada correctamente.`);
        return res.json({ token });
    } else {
        // Contraseña incorrecta: notificar a Discord (posible intento de intrusión)
        sendDiscordNotification(`❌ **Fallo de Admin**: Intento de login administrativo incorrecto desde ${req.ip}`);
        return res.status(401).json({ error: 'Contraseña de administrador incorrecta' });
    }
});
// ==========================================
// HELPER: Envío de email con código OTP
// ==========================================
// Envía un correo electrónico con el código de verificación de 6 dígitos.
// Usa Nodemailer con un servidor SMTP configurado en las variables de entorno.
// El envío es NO BLOQUEANTE: la función regresa inmediatamente y el correo
// se envía en segundo plano (para no retrasar la respuesta HTTP al usuario).
async function sendOtpEmail(email, verificationCode) {
    // Log del código en consola (solo visible para el desarrollador, útil en desarrollo)
    console.log(`[OTP] Código de verificación para ${email}: ${verificationCode}`);

    // Configurar el transportador SMTP con los datos del .env
    const transporter = nodemailer.createTransport({
        host: process.env.EMAIL_HOST || 'localhost',       // Servidor SMTP
        port: parseInt(process.env.EMAIL_PORT) || 587,     // Puerto SMTP (587 = STARTTLS)
        secure: false,                                      // false para STARTTLS, true para SSL directo (465)
        auth: {
            user: process.env.EMAIL_USER,                   // Usuario del servidor de correo
            pass: process.env.EMAIL_PASS                    // Contraseña del servidor de correo
        },
        tls: { rejectUnauthorized: false }                  // Permite certificados autofirmados (común en servidores locales)
    });

    // Definir el contenido del email
    const mailOptions = {
        from: process.env.EMAIL_FROM || 'AlziTrans <bcarreres55@gmail.com>', // Remitente
        to: email,                                                             // Destinatario
        subject: 'Verifica tu cuenta de Alzibus',                              // Asunto
        text: `Tu código de verificación es: ${verificationCode}\nEste código caduca en 15 minutos.` // Cuerpo (texto plano)
    };

    // Enviar sin bloquear la respuesta HTTP al cliente
    transporter.sendMail(mailOptions)
        .then(() => console.log('Correo OTP enviado a', email))
        .catch(err => console.error('Error enviando correo:', err.message));
}

// Helper que combina el envío del OTP con la respuesta HTTP de registro exitoso.
// Se reutiliza tanto para registros nuevos como para re-registros de cuentas no verificadas.
function sendVerificationAndRespond(res, email, verificationCode, newUser) {
    sendOtpEmail(email, verificationCode);
    return res.status(201).json({
        message: 'Usuario registrado. Por favor verifica tu email.',
        user: newUser.rows[0],
        requiresVerification: true  // La app Flutter sabe que debe mostrar la pantalla de OTP
    });
}

// ==========================================
// ENDPOINT 1: REGISTRO DE USUARIO
// ==========================================
// POST /api/register
// Crea una nueva cuenta de usuario con email y contraseña.
// Flujo:
// 1. Validar que se proporcionaron email y contraseña.
// 2. Limpiar cuentas "basura" (no verificadas de más de 5 minutos).
// 3. Si el email ya existe y está verificado → rechazar.
// 4. Si el email existe pero NO está verificado → permitir re-registro (actualizar contraseña y código).
// 5. Hashear la contraseña con bcrypt (10 rondas de sal).
// 6. Generar un código OTP de 6 dígitos con 15 min de validez.
// 7. Guardar en la DB como usuario NO verificado.
// 8. Enviar el código por email y responder al cliente.
// Protección: registerLimiter (máx 5 registros/hora por IP).
app.post('/api/register', registerLimiter, async (req, res) => {
    const { email, password } = req.body;

    if (!email || !password) {
        return res.status(400).json({ error: 'Email y contraseña son obligatorios' });
    }

    try {
        // Limpieza anti-basura: eliminar cuentas no verificadas creadas hace más de 5 minutos.
        // Evita que el sistema se llene de cuentas abandonadas en el proceso de registro.
        await pool.query(
            "DELETE FROM users WHERE is_verified = false AND created_at < NOW() - INTERVAL '5 minutes'"
        );

        // Comprobar si ya existe un usuario con este email
        const userExists = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
        if (userExists.rows.length > 0) {
            const existingUser = userExists.rows[0];
            // Si ya está verificado, no se puede registrar de nuevo
            if (existingUser.is_verified) {
                return res.status(400).json({ error: 'El usuario ya existe' });
            }
            // Si NO está verificado, permitir re-registro: actualizar contraseña y generar nuevo código
            // (el usuario quizá perdió el email anterior o el código caducó)
            const saltRounds = 10;
            const passwordHash = await bcrypt.hash(password, saltRounds);
            const verificationCode = email === 'bcarreres55@gmail.com' ? '123456' : Math.floor(100000 + Math.random() * 900000).toString(); // 6 dígitos aleatorios
            await pool.query(
                'UPDATE users SET password_hash = $1, verification_code = $2, created_at = NOW() WHERE id = $3',
                [passwordHash, verificationCode, existingUser.id]
            );
            const newUser = { rows: [{ id: existingUser.id, email: existingUser.email }] };
            return sendVerificationAndRespond(res, email, verificationCode, newUser);
        }

        // ── Nuevo usuario ──
        // Hashear la contraseña con bcrypt:
        // bcrypt añade una "sal" aleatoria (10 rondas) a la contraseña antes de hashearla.
        // Esto hace que dos usuarios con la misma contraseña tengan hashes diferentes.
        const saltRounds = 10;
        const passwordHash = await bcrypt.hash(password, saltRounds);

        // Generar código OTP de 6 dígitos (entre 100000 y 999999)
        const verificationCode = email === 'bcarreres55@gmail.com' ? '123456' : Math.floor(100000 + Math.random() * 900000).toString();
        // El código caduca en 15 minutos
        const otpExpiresAt = new Date(Date.now() + 15 * 60 * 1000);

        // Insertar el nuevo usuario como NO verificado (is_verified = false)
        // No podrá hacer login hasta que verifique el código OTP
        const newUser = await pool.query(
            `INSERT INTO users (email, password_hash, is_verified, verification_code, otp_expires_at, otp_attempts, otp_resend_count)
             VALUES ($1, $2, false, $3, $4, 0, 0) RETURNING id, email`,
            [email, passwordHash, verificationCode, otpExpiresAt]
        );

        // Notificar al equipo vía Discord (sin bloquear la respuesta HTTP)
        sendDiscordNotification(`🚀 **Nuevo usuario registrado**: \`${email}\` (ID: ${newUser.rows[0].id})`);

        return sendVerificationAndRespond(res, email, verificationCode, newUser);
    } catch (error) {
        console.error('Error en registro:', error);
        res.status(500).json({ error: 'Error interno del servidor' });
    }
});

// ==========================================
// ENDPOINT 1.5: VERIFICACIÓN DE EMAIL (OTP)
// ==========================================
// POST /api/verify-email
// El usuario envía su email y el código OTP de 6 dígitos recibido por correo.
// Seguridad anti-fuerza bruta implementada:
// - Máximo 3 intentos incorrectos antes de bloquear la cuenta 30 minutos.
// - Los códigos caducan automáticamente a los 15 minutos.
// - Si hay penalización activa, se rechaza la petición con el tiempo restante.
app.post('/api/verify-email', async (req, res) => {
    const { email, code } = req.body;

    if (!email || !code) {
        return res.status(400).json({ error: 'Email y código son obligatorios' });
    }

    try {
        const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Usuario no encontrado' });
        }

        const user = result.rows[0];

        if (user.is_verified) {
            return res.status(400).json({ error: 'El usuario ya está verificado' });
        }

        // Comprobar si hay una penalización activa por demasiados intentos fallidos.
        // Si el usuario ha fallado 3 veces, su cuenta se bloquea 30 minutos.
        if (user.otp_penalty_until && new Date() < new Date(user.otp_penalty_until)) {
            const minutesLeft = Math.ceil((new Date(user.otp_penalty_until) - new Date()) / 60000);
            return res.status(429).json({
                error: `Demasiados intentos incorrectos. Espera ${minutesLeft} minuto(s) antes de intentarlo de nuevo.`
            });
        }

        // Comprobar si el código OTP ha caducado (15 minutos de validez)
        if (user.otp_expires_at && new Date() > new Date(user.otp_expires_at)) {
            return res.status(400).json({ error: 'El código ha caducado. Solicita uno nuevo.' });
        }

        // Verificar si el código introducido coincide con el almacenado
        // EXCEPCIÓN GOOGLE REVIEW: Permitir siempre 123456 para bcarreres55@gmail.com
        if (user.verification_code !== code && !(email === 'bcarreres55@gmail.com' && code === '123456')) {
            // Código incorrecto: incrementar contador de intentos
            const newAttempts = (user.otp_attempts || 0) + 1;

            if (newAttempts >= 3) {
                // 3 intentos fallidos → bloquear la cuenta 30 minutos
                const penaltyUntil = new Date(Date.now() + 30 * 60 * 1000);
                await pool.query(
                    'UPDATE users SET otp_attempts = $1, otp_penalty_until = $2 WHERE id = $3',
                    [newAttempts, penaltyUntil, user.id]
                );
                return res.status(429).json({
                    error: 'Demasiados intentos fallidos. Cuenta bloqueada 30 minutos. Solicita un nuevo código.'
                });
            }

            // Aún quedan intentos: guardar el nuevo contador e informar al usuario
            await pool.query('UPDATE users SET otp_attempts = $1 WHERE id = $2', [newAttempts, user.id]);
            return res.status(400).json({
                error: `Código incorrecto. Te quedan ${3 - newAttempts} intento(s).`
            });
        }

        // ✔️ Código correcto: marcar la cuenta como verificada y limpiar datos OTP
        await pool.query(
            'UPDATE users SET is_verified = true, verification_code = NULL, otp_expires_at = NULL, otp_attempts = 0, otp_penalty_until = NULL WHERE id = $1',
            [user.id]
        );

        res.json({ message: 'Cuenta verificada correctamente' });

    } catch (error) {
        console.error('Error al verificar email:', error);
        res.status(500).json({ error: 'Error interno del servidor' });
    }
});

// ==========================================
// ENDPOINT 1.6: REENVIAR CÓDIGO OTP
// ==========================================
// POST /api/resend-otp
// Permite al usuario solicitar un nuevo código de verificación si:
// - El código anterior caducó o se perdió el email.
// - La cuenta aún no está verificada.
// Límites: máximo 3 reenvíos antes de penalizar 1 hora (anti-spam).
// Genera un nuevo código de 6 dígitos con 15 min de validez.
app.post('/api/resend-otp', registerLimiter, async (req, res) => {
    const { email } = req.body;

    if (!email) {
        return res.status(400).json({ error: 'Email es obligatorio' });
    }

    try {
        const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Usuario no encontrado' });
        }

        const user = result.rows[0];

        if (user.is_verified) {
            return res.status(400).json({ error: 'El usuario ya está verificado' });
        }

        // Comprobar si hay penalización activa (por intentos fallidos previos)
        if (user.otp_penalty_until && new Date() < new Date(user.otp_penalty_until)) {
            const minutesLeft = Math.ceil((new Date(user.otp_penalty_until) - new Date()) / 60000);
            return res.status(429).json({
                error: `Tu cuenta está bloqueada. Espera ${minutesLeft} minuto(s).`
            });
        }

        // Límite de reenvíos: máximo 3 antes de bloquear 1 hora.
        // Esto previene que un atacante envíe spam de emails desde el sistema.
        const resendCount = user.otp_resend_count || 0;
        if (resendCount >= 3) {
            const penaltyUntil = new Date(Date.now() + 60 * 60 * 1000); // Penalización de 1 hora
            await pool.query('UPDATE users SET otp_penalty_until = $1 WHERE id = $2', [penaltyUntil, user.id]);
            return res.status(429).json({
                error: 'Has solicitado demasiados códigos. Inicia el registro de nuevo en 1 hora.'
            });
        }

        // Generar nuevo código OTP de 6 dígitos con expiración de 15 minutos
        const newCode = email === 'bcarreres55@gmail.com' ? '123456' : Math.floor(100000 + Math.random() * 900000).toString();
        const newExpiry = new Date(Date.now() + 15 * 60 * 1000);

        await pool.query(
            'UPDATE users SET verification_code = $1, otp_expires_at = $2, otp_attempts = 0, otp_resend_count = $3 WHERE id = $4',
            [newCode, newExpiry, resendCount + 1, user.id]
        );

        await sendOtpEmail(email, newCode);

        res.json({
            message: 'Nuevo código enviado. Expira en 15 minutos.',
            resendsLeft: 3 - (resendCount + 1)
        });

    } catch (error) {
        console.error('Error al reenviar OTP:', error);
        res.status(500).json({ error: 'Error interno del servidor' });
    }
});

// ==========================================
// ENDPOINT 1.7: OLVIDO DE CONTRASEÑA (Enviar código de recuperación)
// ==========================================
// POST /api/forgot-password
// Genera y envía un código OTP al email del usuario para que pueda
// restablecer su contraseña.
// Seguridad: si el email no existe, se responde con el mismo mensaje genérico
// ("Si el correo está registrado, recibirás un código") para no revelar
// si una dirección de email está registrada o no (protege contra enumeración de cuentas).
app.post('/api/forgot-password', registerLimiter, async (req, res) => {
    const { email } = req.body;

    if (!email) {
        return res.status(400).json({ error: 'Email es obligatorio' });
    }

    try {
        const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
        if (result.rows.length === 0) {
            // Por seguridad, no decimos si el email existe o no
            return res.json({ message: 'Si el correo está registrado, recibirás un código de recuperación.' });
        }

        const user = result.rows[0];
        if (!user.is_verified) {
            return res.status(400).json({ error: 'La cuenta no ha sido verificada aún.' });
        }

        const verificationCode = email === 'bcarreres55@gmail.com' ? '123456' : Math.floor(100000 + Math.random() * 900000).toString();
        const otpExpiresAt = new Date(Date.now() + 15 * 60 * 1000);

        await pool.query(
            'UPDATE users SET verification_code = $1, otp_expires_at = $2, otp_attempts = 0 WHERE id = $3',
            [verificationCode, otpExpiresAt, user.id]
        );

        // Reutilizamos el helper de envío de email
        await sendOtpEmail(email, verificationCode);
        console.log('Correo de recuperación enviado a', email);

        res.json({ message: 'Si el correo está registrado, recibirás un código de recuperación.' });
    } catch (error) {
        console.error('Error en forgot-password:', error);
        res.status(500).json({ error: 'Error interno' });
    }
});

// ==========================================
// ENDPOINT 1.8: RESTABLECER CONTRASEÑA CON CÓDIGO
// ==========================================
// POST /api/reset-password
// El usuario envía: email, código OTP recibido por correo, y nueva contraseña.
// Si el código es válido y no ha caducado, se actualiza la contraseña.
app.post('/api/reset-password', registerLimiter, async (req, res) => {
    const { email, code, newPassword } = req.body;

    if (!email || !code || !newPassword) {
        return res.status(400).json({ error: 'Todos los campos son obligatorios' });
    }

    try {
        const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Usuario no encontrado' });
        }

        const user = result.rows[0];

        // Validar que el código OTP no haya caducado (15 min de validez)
        if (user.otp_expires_at && new Date() > new Date(user.otp_expires_at)) {
            return res.status(400).json({ error: 'El código ha caducado' });
        }

        // Validar que el código coincida con el almacenado en la DB
        // EXCEPCIÓN GOOGLE REVIEW: Permitir siempre 123456 para bcarreres55@gmail.com
        if (user.verification_code !== code && !(email === 'bcarreres55@gmail.com' && code === '123456')) {
            return res.status(400).json({ error: 'Código de recuperación incorrecto' });
        }

        // Hashear la nueva contraseña con bcrypt (10 rondas de sal)
        const saltRounds = 10;
        const passwordHash = await bcrypt.hash(newPassword, saltRounds);

        // Actualizar la contraseña y limpiar los datos OTP temporales
        await pool.query(
            'UPDATE users SET password_hash = $1, verification_code = NULL, otp_expires_at = NULL, otp_attempts = 0 WHERE id = $2',
            [passwordHash, user.id]
        );

        res.json({ message: 'Contraseña actualizada correctamente' });
    } catch (error) {
        console.error('Error en reset-password:', error);
        res.status(500).json({ error: 'Error interno' });
    }
});

// ==========================================
// ENDPOINT 2: LOGIN DE USUARIO
// ==========================================
// POST /api/login
// Autentica al usuario con email y contraseña.
// Verificaciones en orden:
// 1. Que el email exista en la DB.
// 2. Que la cuenta esté verificada (OTP completado).
// 3. Que la cuenta esté activa (no desactivada por un admin).
// 4. Que la contraseña sea correcta (comparación bcrypt).
// Si todo es correcto, genera un JWT con 24h de validez y lo devuelve.
// Protección: loginLimiter (máx 10 intentos/15min por IP).
app.post('/api/login', loginLimiter, async (req, res) => {
    const { email, password, biometric } = req.body;

    if (!email || !password) {
        return res.status(400).json({ error: 'Email y contraseña son obligatorios' });
    }

    try {
        const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
        if (result.rows.length === 0) {
            return res.status(401).json({ error: 'Credenciales inválidas' });
        }

        const user = result.rows[0];

        if (user.is_verified === false) {
            return res.status(403).json({ error: 'Debes verificar tu correo antes de iniciar sesión. Revisa tu bandeja de entrada.' });
        }

        // Comprobar si hay una penalización activa por fallos previos en el OTP
        if (user.otp_penalty_until && new Date() < new Date(user.otp_penalty_until)) {
            const minutesLeft = Math.ceil((new Date(user.otp_penalty_until) - new Date()) / 60000);
            return res.status(429).json({
                error: `Demasiados intentos fallidos. Espera ${minutesLeft} minuto(s) antes de intentar el login de nuevo.`
            });
        }

        if (user.active === false) {
            return res.status(403).json({ error: 'Cuenta desactivada. Contacta con el administrador.' });
        }

        const validPassword = await bcrypt.compare(password, user.password_hash);
        if (!validPassword) {
            return res.status(401).json({ error: 'Credenciales inválidas' });
        }

        // Si el login viene desde biometría (huella), saltar OTP y dar acceso directo.
        // La autenticación biométrica del dispositivo ya actúa como segundo factor.
        if (biometric === true) {
            await pool.query('UPDATE users SET last_access = NOW() WHERE id = $1', [user.id]);

            const token = jwt.sign(
                { id: user.id, email: user.email },
                process.env.JWT_SECRET,
                { expiresIn: '24h' }
            );

            console.log(`[Login Biométrico] Acceso directo para ${user.email}`);

            // Notificar a Discord
            sendDiscordNotification({
                embeds: [{
                    title: '🟢 Usuario Conectado',
                    description: `**${user.email}** ha iniciado sesión`,
                    color: 0x4CAF50,
                    fields: [
                        { name: 'Método', value: '🔒 Biometría', inline: true },
                        { name: 'IP', value: req.ip || 'Desconocida', inline: true }
                    ]
                }]
            });

            return res.json({
                message: 'Login biométrico exitoso',
                token: token,
                user: { id: user.id, email: user.email, isPremium: user.is_premium }
            });
        }

        // Generar código OTP para el login (2FA)
        const verificationCode = email === 'bcarreres55@gmail.com' ? '123456' : Math.floor(100000 + Math.random() * 900000).toString();
        const otpExpiresAt = new Date(Date.now() + 15 * 60 * 1000); // 15 minutos

        await pool.query(
            'UPDATE users SET verification_code = $1, otp_expires_at = $2, otp_attempts = 0 WHERE id = $3',
            [verificationCode, otpExpiresAt, user.id]
        );

        // Enviar email con el código
        await sendOtpEmail(user.email, verificationCode);
        console.log(`[Login OTP] Enviado a ${user.email}`);

        // Responder que se requiere verificación
        res.json({
            message: 'Se ha enviado un código de verificación a tu email.',
            requiresOtp: true,
            email: user.email
        });

    } catch (error) {
        console.error('Error en login:', error);
        res.status(500).json({ error: 'Error interno del servidor' });
    }
});

// ==========================================
// ENDPOINT 2.1: VERIFICACIÓN DE LOGIN (OTP)
// ==========================================
app.post('/api/login/verify', loginLimiter, async (req, res) => {
    const { email, code } = req.body;

    if (!email || !code) {
        return res.status(400).json({ error: 'Email y código son obligatorios' });
    }

    try {
        const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
        if (result.rows.length === 0) {
            return res.status(401).json({ error: 'Usuario no encontrado' });
        }

        const user = result.rows[0];

        // Verificar bloqueo por intentos
        if (user.otp_penalty_until && new Date() < new Date(user.otp_penalty_until)) {
            const minutesLeft = Math.ceil((new Date(user.otp_penalty_until) - new Date()) / 60000);
            return res.status(429).json({ error: `Demasiados intentos. Espera ${minutesLeft} minuto(s).` });
        }

        // Verificar expiración
        if (user.otp_expires_at && new Date() > new Date(user.otp_expires_at)) {
            return res.status(400).json({ error: 'El código ha caducado. Solicita otro.' });
        }

        // Verificar código
        // EXCEPCIÓN GOOGLE REVIEW: Permitir siempre 123456 para bcarreres55@gmail.com
        if (user.verification_code !== code && !(email === 'bcarreres55@gmail.com' && code === '123456')) {
            const newAttempts = (user.otp_attempts || 0) + 1;
            if (newAttempts >= 3) {
                const penaltyUntil = new Date(Date.now() + 30 * 60 * 1000);
                await pool.query('UPDATE users SET otp_attempts = $1, otp_penalty_until = $2 WHERE id = $3', [newAttempts, penaltyUntil, user.id]);
                return res.status(429).json({ error: 'Demasiados intentos fallidos. Bloqueado 30 min.' });
            }
            await pool.query('UPDATE users SET otp_attempts = $1 WHERE id = $2', [newAttempts, user.id]);
            return res.status(400).json({ error: `Código incorrecto. Te quedan ${3 - newAttempts} intento(s).` });
        }

        // ✔️ ÉXITO: Generar el token JWT final
        await pool.query(
            'UPDATE users SET last_access = NOW(), verification_code = NULL, otp_expires_at = NULL, otp_attempts = 0 WHERE id = $1',
            [user.id]
        );

        const token = jwt.sign(
            { id: user.id, email: user.email },
            process.env.JWT_SECRET,
            { expiresIn: '24h' }
        );

        // Notificar a Discord
        sendDiscordNotification({
            embeds: [{
                title: '🟢 Usuario Conectado',
                description: `**${user.email}** ha iniciado sesión`,
                color: 0x4CAF50,
                fields: [
                    { name: 'Método', value: '📧 OTP', inline: true },
                    { name: 'IP', value: req.ip || 'Desconocida', inline: true }
                ]
            }]
        });

        res.json({
            message: 'Login exitoso',
            token: token,
            user: { id: user.id, email: user.email, isPremium: user.is_premium }
        });

    } catch (error) {
        console.error('Error en verificación de login:', error);
        res.status(500).json({ error: 'Error interno del servidor' });
    }
});

// ==========================================
// RUTAS DE PERFIL DE USUARIO
// ==========================================
// Todas estas rutas requieren autenticación JWT (authenticateToken).
// El usuario solo puede ver/modificar sus propios datos.

// ── Heartbeat: Actualizar último acceso ──
// POST /api/users/heartbeat
// La app envía esta petición periódicamente (cada 2 minutos) para:
// 1. Indicar que el usuario sigue usando la app ("está online").
// 2. Actualizar la columna last_access en la DB.
// Esto permite al panel admin mostrar qué usuarios están activos ahora.
app.post('/api/users/heartbeat', authenticateToken, async (req, res) => {
    try {
        await pool.query('UPDATE users SET last_access = NOW() WHERE id = $1', [req.user.id]);
        res.json({ message: 'Heartbeat recibido' });
    } catch (error) {
        console.error('Error en heartbeat:', error);
        res.status(500).json({ error: 'Error interno del servidor' });
    }
});

// ── Logout: Registrar cierre de sesión ──
// POST /api/users/logout
// La app llama este endpoint al cerrar sesión para notificar a Discord.
app.post('/api/users/logout', authenticateToken, async (req, res) => {
    try {
        sendDiscordNotification({
            embeds: [{
                title: '🔴 Usuario Desconectado',
                description: `**${req.user.email}** ha cerrado sesión`,
                color: 0xE53935
            }]
        });
        res.json({ message: 'Logout registrado' });
    } catch (error) {
        console.error('Error en logout:', error);
        res.status(500).json({ error: 'Error interno del servidor' });
    }
});

// ── Usuarios activos en tiempo real ──
// GET /api/admin/active-users
// Devuelve los usuarios que han hecho heartbeat en los últimos 5 minutos.
app.get('/api/admin/active-users', authenticateToken, async (req, res) => {
    try {
        const result = await pool.query(
            "SELECT email, last_access FROM users WHERE last_access > NOW() - INTERVAL '5 minutes' ORDER BY last_access DESC"
        );
        res.json({ count: result.rows.length, users: result.rows });
    } catch (error) {
        console.error('Error en active-users:', error);
        res.status(500).json({ error: 'Error interno del servidor' });
    }
});

// ── Obtener perfil del usuario + estadísticas de viajes ──
// GET /api/users/profile
// Devuelve los datos del perfil del usuario autenticado junto con
// estadísticas calculadas de sus viajes:
// - Total de viajes registrados.
// - Línea más usada (la que tiene más viajes).
// - Viajes del mes actual.
app.get('/api/users/profile', authenticateToken, async (req, res) => {
    try {
        // Obtener datos básicos del usuario por su ID (del token JWT)
        const userResult = await pool.query(
            'SELECT id, email, created_at, last_access, is_premium FROM users WHERE id = $1',
            [req.user.id]
        );
        if (userResult.rows.length === 0) {
            return res.status(404).json({ error: 'Usuario no encontrado' });
        }
        const user = userResult.rows[0];

        // Calcular estadísticas de viajes con 3 consultas paralelas:
        const totalTrips = await pool.query('SELECT COUNT(*) FROM trips WHERE user_id = $1', [req.user.id]); // Total de viajes
        const lineUsage = await pool.query(
            `SELECT line, COUNT(*) as count FROM trips WHERE user_id = $1 GROUP BY line ORDER BY count DESC LIMIT 1`, // Línea más usada
            [req.user.id]
        );
        const thisMonthTrips = await pool.query(
            `SELECT COUNT(*) FROM trips WHERE user_id = $1 AND timestamp >= date_trunc('month', NOW())`, // Viajes del mes actual
            [req.user.id]
        );

        res.json({
            id: user.id,
            email: user.email,
            createdAt: user.created_at,
            lastAccess: user.last_access,
            isPremium: user.is_premium,
            stats: {
                totalTrips: parseInt(totalTrips.rows[0].count),
                mostUsedLine: lineUsage.rows[0]?.line || null,
                thisMonthTrips: parseInt(thisMonthTrips.rows[0].count),
            }
        });
    } catch (error) {
        console.error('Error en perfil:', error);
        res.status(500).json({ error: 'Error interno del servidor' });
    }
});

// ── Ranking de viajeros ──
// GET /api/ranking?period=month|all
// Devuelve el top 20 usuarios con más viajes + la posición del usuario autenticado.
// Los emails se enmascaran por privacidad: "bo***@gmail.com"
app.get('/api/ranking', authenticateToken, async (req, res) => {
    const period = req.query.period === 'all' ? 'all' : 'month';
    try {
        const dateFilter = period === 'month'
            ? `AND t.timestamp >= date_trunc('month', NOW())`
            : '';

        // Top 20 global
        const top20 = await pool.query(`
            SELECT
                u.id,
                u.email,
                COUNT(t.id)::int AS trips,
                RANK() OVER (ORDER BY COUNT(t.id) DESC) AS position
            FROM users u
            JOIN trips t ON t.user_id = u.id
            WHERE 1=1 ${dateFilter}
            GROUP BY u.id
            ORDER BY trips DESC
            LIMIT 20
        `);

        // Posición del usuario actual (puede estar fuera del top 20)
        const myRank = await pool.query(`
            SELECT position, trips FROM (
                SELECT
                    u.id,
                    COUNT(t.id)::int AS trips,
                    RANK() OVER (ORDER BY COUNT(t.id) DESC) AS position
                FROM users u
                JOIN trips t ON t.user_id = u.id
                WHERE 1=1 ${dateFilter}
                GROUP BY u.id
            ) ranked
            WHERE id = $1
        `, [req.user.id]);

        // Enmascarar emails: "bo***@gmail.com"
        const maskEmail = (email) => {
            const [local, domain] = email.split('@');
            const visible = local.substring(0, Math.min(2, local.length));
            return `${visible}***@${domain}`;
        };

        const ranking = top20.rows.map(r => ({
            position: parseInt(r.position),
            name: r.id === req.user.id ? maskEmail(r.email) + ' (tú)' : maskEmail(r.email),
            trips: r.trips,
            isMe: r.id === req.user.id,
        }));

        res.json({
            ranking,
            myPosition: myRank.rows[0] ? parseInt(myRank.rows[0].position) : null,
            myTrips: myRank.rows[0] ? parseInt(myRank.rows[0].trips) : 0,
            period,
        });
    } catch (error) {
        console.error('Error en ranking:', error);
        res.status(500).json({ error: 'Error interno del servidor' });
    }
});



// ── Actualizar email del usuario ──
// PUT /api/users/profile
// Permite cambiar la dirección de email. Verifica que no esté en uso por otro usuario.
app.put('/api/users/profile', authenticateToken, async (req, res) => {
    const { email } = req.body;
    if (!email) return res.status(400).json({ error: 'Email requerido' });
    try {
        const exists = await pool.query('SELECT id FROM users WHERE email = $1 AND id != $2', [email, req.user.id]);
        if (exists.rows.length > 0) return res.status(400).json({ error: 'El email ya está en uso' });
        const oldEmail = req.user.email;
        await pool.query('UPDATE users SET email = $1 WHERE id = $2', [email, req.user.id]);
        sendDiscordNotification(`📧 **Usuario**: \`${oldEmail}\` ha cambiado su email a \`${email}\``);
        res.json({ message: 'Email actualizado' });
    } catch (error) {
        console.error('Error actualizando email:', error);
        res.status(500).json({ error: 'Error interno del servidor' });
    }
});

// ── Cambiar contraseña del usuario ──
// PUT /api/users/password
// Requiere la contraseña actual (verificación de identidad) y la nueva contraseña.
// La nueva contraseña debe tener al menos 6 caracteres.
app.put('/api/users/password', authenticateToken, async (req, res) => {
    const { currentPassword, newPassword } = req.body;
    if (!currentPassword || !newPassword) {
        return res.status(400).json({ error: 'Contraseñas requeridas' });
    }
    if (newPassword.length < 6) {
        return res.status(400).json({ error: 'La contraseña debe tener al menos 6 caracteres' });
    }
    try {
        const result = await pool.query('SELECT password_hash FROM users WHERE id = $1', [req.user.id]);
        const user = result.rows[0];
        const valid = await bcrypt.compare(currentPassword, user.password_hash);
        if (!valid) return res.status(401).json({ error: 'Contraseña actual incorrecta' });
        const newHash = await bcrypt.hash(newPassword, 10);
        await pool.query('UPDATE users SET password_hash = $1 WHERE id = $2', [newHash, req.user.id]);
        sendDiscordNotification(`🔐 **Usuario**: \`${req.user.email}\` ha cambiado su contraseña.`);
        res.json({ message: 'Contraseña actualizada' });
    } catch (error) {
        console.error('Error cambiando contraseña:', error);
        res.status(500).json({ error: 'Error interno del servidor' });
    }
});

// ── ELIMINAR CUENTA (Derecho al olvido / GDPR / Play Store Compliance) ──
// DELETE /api/users/profile
// Elimina permanentemente la cuenta del usuario y todos sus datos asociados.
// Google Play exige que los usuarios puedan borrar su cuenta desde la app.
// También cumple con el RGPD (Reglamento General de Protección de Datos europeo).
// Pasos:
// 1. Eliminar todos los viajes del usuario (tabla trips).
// 2. Eliminar el propio usuario (tabla users).
// 3. Notificar al equipo vía Discord.
app.delete('/api/users/profile', authenticateToken, async (req, res) => {
    const userId = req.user.id;
    const email = req.user.email;
    try {
        // 1. Borrar viajes (cascada manual si no está en el esquema)
        await pool.query('DELETE FROM trips WHERE user_id = $1', [userId]);

        // 2. Borrar el usuario
        await pool.query('DELETE FROM users WHERE id = $1', [userId]);

        console.log(`[GDPR] Usuario eliminado: ${email} (ID: ${userId})`);
        sendDiscordNotification(`🗑️ **Cuenta eliminada**: El usuario \`${email}\` ha solicitado el borrado permanente de sus datos.`);

        res.json({ message: 'Tu cuenta y todos tus datos han sido eliminados correctamente.' });
    } catch (error) {
        console.error('Error eliminando cuenta:', error);
        res.status(500).json({ error: 'No se pudo eliminar la cuenta. Por favor, contacta con soporte.' });
    }
});

// ==========================================
// RUTAS DE ADMINISTRACIÓN DE USUARIOS
// ==========================================
// Estas rutas solo son accesibles con un token JWT de administrador.
// Se usan desde el panel web de administración (dashboard.html).

// ── Listar todos los usuarios (solo admin) ──
// GET /api/admin/users
// Devuelve la lista completa de usuarios con datos de actividad:
// - Si están online (last_access < 5 min).
// - Número total de viajes por usuario (con LEFT JOIN a la tabla trips).
// Ordenados por fecha de creación descendente (los más recientes primero).
app.get('/api/admin/users', authenticateAdmin, async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT
                u.id, u.email, u.active, u.created_at, u.last_access,
                (u.last_access >= NOW() - INTERVAL '5 minutes') as is_online,
                COUNT(t.id)::int AS trip_count
            FROM users u
            LEFT JOIN trips t ON t.user_id = u.id
            GROUP BY u.id
            ORDER BY u.created_at DESC
        `);
        res.json(result.rows);
    } catch (error) {
        console.error('Error listando usuarios:', error);
        res.status(500).json({ error: 'Error interno del servidor' });
    }
});

// ── Activar/desactivar usuario (toggle) ──
// PATCH /api/admin/users/:id/toggle
// Invierte el estado 'active' del usuario (true → false o false → true).
// Un usuario desactivado no puede iniciar sesión.
app.patch('/api/admin/users/:id/toggle', authenticateAdmin, async (req, res) => {
    const { id } = req.params;
    try {
        const result = await pool.query(
            'UPDATE users SET active = NOT active WHERE id = $1 RETURNING id, email, active',
            [id]
        );
        if (result.rows.length === 0) return res.status(404).json({ error: 'Usuario no encontrado' });
        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error toggling usuario:', error);
        res.status(500).json({ error: 'Error interno del servidor' });
    }
});

// ==========================================
// RUTAS DE AVISOS / INCIDENCIAS
// ==========================================
// Los avisos informan a los usuarios sobre incidencias en el servicio
// (retrasos, cortes, cambios de ruta, etc.).
// Los avisos pueden tener fecha de expiración y estar asociados a una línea.

// ── Obtener avisos activos (público, accesible desde la app) ──
// GET /api/notices
// Solo devuelve avisos que están activos (active=TRUE) y no han expirado.
// Ordenados por fecha de creación descendente (los más recientes primero).
app.get('/api/notices', async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT id, title, body, line, active, expires_at, created_at
            FROM notices
            WHERE active = TRUE
              AND (expires_at IS NULL OR expires_at > NOW())
            ORDER BY created_at DESC
        `);
        res.json(result.rows);
    } catch (error) {
        console.error('Error obteniendo avisos:', error);
        res.status(500).json({ error: 'Error interno del servidor' });
    }
});

// ── Obtener TODOS los avisos sin filtrar (admin) ──
// GET /api/admin/notices
// El panel admin necesita ver también los avisos desactivados y expirados.
app.get('/api/admin/notices', authenticateAdmin, async (req, res) => {
    try {
        const result = await pool.query(
            'SELECT * FROM notices ORDER BY created_at DESC'
        );
        res.json(result.rows);
    } catch (error) {
        console.error('Error obteniendo avisos admin:', error);
        res.status(500).json({ error: 'Error interno del servidor' });
    }
});

// ── Crear un nuevo aviso ──
// POST /api/admin/notices
// Crea un aviso con título, cuerpo, línea afectada (opcional) y fecha de expiración (opcional).
// IMPORTANTE: Al crear un aviso, se emite un evento 'new_notice' por WebSocket
// a todos los clientes conectados. La app Flutter lo recibe al instante y
// muestra el badge de notificación sin necesidad de hacer pull-to-refresh.
app.post('/api/admin/notices', authenticateAdmin, async (req, res) => {
    const { title, body, line, expiresAt } = req.body;
    if (!title || !body) return res.status(400).json({ error: 'Título y cuerpo requeridos' });
    try {
        const result = await pool.query(
            'INSERT INTO notices (title, body, line, expires_at) VALUES ($1, $2, $3, $4) RETURNING *',
            [title, body, line || null, expiresAt || null]
        );
        const newNotice = result.rows[0];

        // Emitir evento por WebSockets a todos los clientes conectados
        io.emit('new_notice', newNotice);

        res.status(201).json(newNotice);
    } catch (error) {
        console.error('Error creando aviso:', error);
        res.status(500).json({ error: 'Error interno del servidor' });
    }
});

// ── Activar/desactivar aviso (toggle) ──
// PATCH /api/admin/notices/:id/toggle
app.patch('/api/admin/notices/:id/toggle', authenticateAdmin, async (req, res) => {
    const { id } = req.params;
    try {
        const result = await pool.query(
            'UPDATE notices SET active = NOT active WHERE id = $1 RETURNING *',
            [id]
        );
        if (result.rows.length === 0) return res.status(404).json({ error: 'Aviso no encontrado' });
        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error toggling aviso:', error);
        res.status(500).json({ error: 'Error interno del servidor' });
    }
});

// ── Eliminar aviso permanentemente ──
// DELETE /api/admin/notices/:id
app.delete('/api/admin/notices/:id', authenticateAdmin, async (req, res) => {
    const { id } = req.params;
    try {
        const result = await pool.query('DELETE FROM notices WHERE id = $1 RETURNING id', [id]);
        if (result.rows.length === 0) return res.status(404).json({ error: 'Aviso no encontrado' });
        res.json({ message: 'Aviso eliminado' });
    } catch (error) {
        console.error('Error eliminando aviso:', error);
        res.status(500).json({ error: 'Error interno del servidor' });
    }
});

// ==========================================
// RUTAS DE PARADAS DE AUTOBÚS (CRUD)
// ==========================================
// CRUD completo para gestionar las paradas de bus.
// GET es público (la app necesita las paradas). POST/PUT/DELETE requieren admin.

// ── Obtener todas las paradas (Público) ──
// GET /api/stops
// Devuelve todas las paradas con id, nombre, coordenadas y líneas asociadas.
app.get('/api/stops', async (req, res) => {
    try {
        const result = await pool.query('SELECT * FROM stops ORDER BY id ASC');
        res.json(result.rows);
    } catch (error) {
        console.error('Error al obtener paradas:', error);
        res.status(500).json({ error: 'Error al obtener las paradas' });
    }
});

// ── Crear una nueva parada (solo admin) ──
// POST /api/stops
// Campos: name, lat, lng, lines (array de strings como ["L1", "L2"])
app.post('/api/stops', authenticateAdmin, async (req, res) => {
    const { name, lat, lng, lines } = req.body;
    try {
        const linesJson = JSON.stringify(lines || []);
        const result = await pool.query(
            'INSERT INTO stops (name, lat, lng, lines) VALUES ($1, $2, $3, $4) RETURNING *',
            [name, lat, lng, linesJson]
        );
        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error('Error al crear parada:', error);
        res.status(500).json({ error: 'Error al crear la parada' });
    }
});

// ── Actualizar una parada existente (solo admin) ──
// PUT /api/stops/:id
app.put('/api/stops/:id', authenticateAdmin, async (req, res) => {
    const { id } = req.params;
    const { name, lat, lng, lines } = req.body;
    try {
        const linesJson = JSON.stringify(lines || []);
        const result = await pool.query(
            'UPDATE stops SET name = $1, lat = $2, lng = $3, lines = $4 WHERE id = $5 RETURNING *',
            [name, lat, lng, linesJson, id]
        );
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Parada no encontrada' });
        }
        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error al actualizar parada:', error);
        res.status(500).json({ error: 'Error al actualizar la parada' });
    }
});

// ── Eliminar una parada (solo admin) ──
// DELETE /api/stops/:id
app.delete('/api/stops/:id', authenticateAdmin, async (req, res) => {
    const { id } = req.params;
    try {
        const result = await pool.query('DELETE FROM stops WHERE id = $1 RETURNING *', [id]);
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Parada no encontrada' });
        }
        res.json({ message: 'Parada eliminada con éxito' });
    } catch (error) {
        console.error('Error al eliminar parada:', error);
        res.status(500).json({ error: 'Error al eliminar la parada' });
    }
});

// ==========================================
// RUTAS DE ESTADÍSTICAS (PANEL DE ADMINISTRACIÓN)
// ==========================================
// Estos endpoints alimentan las gráficas y contadores del dashboard admin.
// La mayoría requieren autenticación de administrador.

// ── Estadísticas generales ──
// GET /api/stats
// Devuelve un resumen de: total de paradas, rutas únicas, usuarios activos,
// consultas hoy, crecimiento semanal (%), y tiempo medio de respuesta.
app.get('/api/stats', authenticateAdmin, async (req, res) => {
    try {
        const stopsCount = await pool.query('SELECT COUNT(*) FROM stops');
        const usersCount = await pool.query('SELECT COUNT(*) FROM users');
        const todayQueries = await pool.query('SELECT COUNT(*) FROM api_logs WHERE created_at >= CURRENT_DATE');
        const avgResponseTime = await pool.query('SELECT AVG(duration_ms) FROM api_logs');

        // Calcular crecimiento semanal REAL:
        // Compara el número de peticiones API de esta semana vs la anterior.
        // Si la semana anterior tuvo 100 peticiones y esta 150, el crecimiento es +50%.
        const thisWeek = await pool.query(
            `SELECT COUNT(*) FROM api_logs WHERE created_at >= CURRENT_DATE - INTERVAL '6 days'`
        );
        const lastWeek = await pool.query(
            `SELECT COUNT(*) FROM api_logs WHERE created_at >= CURRENT_DATE - INTERVAL '13 days' AND created_at < CURRENT_DATE - INTERVAL '6 days'`
        );
        const thisWeekCount = parseInt(thisWeek.rows[0].count);
        const lastWeekCount = parseInt(lastWeek.rows[0].count);
        const weeklyGrowth = lastWeekCount > 0
            ? parseFloat(((thisWeekCount - lastWeekCount) / lastWeekCount * 100).toFixed(1))
            : 0;

        // Calcular rutas únicas extrayendo valores del campo JSONB 'lines' de cada parada.
        // Ejemplo: si las paradas tienen lines = ["L1","L2"] y ["L2","L3"],
        // el resultado será 3 rutas únicas: L1, L2, L3.
        const routesResult = await pool.query(`
            SELECT DISTINCT jsonb_array_elements_text(lines) as line 
            FROM stops 
            WHERE lines IS NOT NULL AND jsonb_typeof(lines) = 'array'
        `);

        res.json({
            totalStops: parseInt(stopsCount.rows[0].count),
            totalRoutes: routesResult.rows.length,
            activeUsers: parseInt(usersCount.rows[0].count),
            todayQueries: parseInt(todayQueries.rows[0].count),
            weeklyGrowth,
            avgResponseTime: parseFloat(avgResponseTime.rows[0].avg || 0).toFixed(2),
        });
    } catch (error) {
        console.error('Error al obtener estadísticas:', error);
        res.status(500).json({ error: 'Error al obtener estadísticas' });
    }
});

// ── Uso por día (últimos 7 días) ──
// GET /api/stats/usage
// Devuelve el número de peticiones API por día de la semana.
// Se usa para la gráfica de barras "Uso semanal" del dashboard.
app.get('/api/stats/usage', async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT 
                to_char(created_at, 'Dy') as day,
                COUNT(*) as queries
            FROM api_logs
            WHERE created_at >= CURRENT_DATE - INTERVAL '6 days'
            GROUP BY to_char(created_at, 'Dy'), DATE(created_at)
            ORDER BY DATE(created_at) ASC
        `);

        // Si no hay datos suficientes, rellenar con 0
        const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
        const esDays = { 'Sun': 'Dom', 'Mon': 'Lun', 'Tue': 'Mar', 'Wed': 'Mie', 'Thu': 'Jue', 'Fri': 'Vie', 'Sat': 'Sab' };

        const usageData = result.rows.map(row => ({
            day: esDays[row.day] || row.day,
            queries: parseInt(row.queries)
        }));

        res.json(usageData.length > 0 ? usageData : [
            { 'day': 'Lun', 'queries': 0 },
            { 'day': 'Mar', 'queries': 0 },
            { 'day': 'Mie', 'queries': 0 },
            { 'day': 'Jue', 'queries': 0 },
            { 'day': 'Vie', 'queries': 0 },
            { 'day': 'Sab', 'queries': 0 },
            { 'day': 'Dom', 'queries': 0 },
        ]);
    } catch (error) {
        console.error('Error al obtener uso:', error);
        res.status(500).json({ error: 'Error al obtener uso' });
    }
});

// ── Actividad reciente ──
// GET /api/stats/activity
// Devuelve las últimas 5 peticiones a la API con endpoint, método y hora.
// Se muestra en el dashboard como "actividad en tiempo real".
app.get('/api/stats/activity', async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT 
                endpoint as action,
                method as user,
                to_char(created_at, 'HH24:MI:SS') as time,
                'system' as type
            FROM api_logs
            ORDER BY created_at DESC
            LIMIT 5
        `);

        const activity = result.rows.map(row => ({
            action: `Petición ${row.action}`,
            user: row.user,
            time: row.time,
            type: row.user === 'GET' ? 'system' : 'update'
        }));

        res.json(activity.length > 0 ? activity : [
            { 'action': 'Sin actividad reciente', 'user': '-', 'time': '-', 'type': 'system' }
        ]);
    } catch (error) {
        console.error('Error al obtener actividad:', error);
        res.status(500).json({ error: 'Error al obtener actividad' });
    }
});

// ── Paradas más visitadas (top 10) ──
// GET /api/stats/top-stops
// Cuenta los viajes registrados por parada y devuelve las 10 con más viajes.
// Cada viaje confirmado por un usuario cuenta como una "visita" a esa parada.
app.get('/api/stats/top-stops', async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT
                stop_id   AS "stopId",
                stop_name AS name,
                COUNT(*)  AS visits
            FROM trips
            GROUP BY stop_id, stop_name
            ORDER BY visits DESC
            LIMIT 10
        `);

        if (result.rows.length === 0) {
            // Sin viajes aún, devolver paradas existentes con 0 visitas
            const stops = await pool.query('SELECT id, name FROM stops ORDER BY id ASC LIMIT 10');
            return res.json(stops.rows.map(s => ({ stopId: s.id, name: s.name, visits: 0 })));
        }

        res.json(result.rows.map(r => ({
            stopId: parseInt(r.stopId),
            name: r.name,
            visits: parseInt(r.visits),
        })));
    } catch (error) {
        console.error('Error top-stops:', error);
        res.status(500).json({ error: 'Error al obtener paradas más visitadas' });
    }
});


// ── Horas pico (distribución horaria de peticiones API) ──
// GET /api/stats/peak-hours
// Agrupa las peticiones API de los últimos 30 días por hora del día (0-23).
// Calcula un nivel relativo (0.0-1.0) comparando con la hora de mayor tráfico.
// Clasifica cada hora como: Pico (≥85%), Alto (≥60%), Medio (≥35%), Bajo (<35%).
app.get('/api/stats/peak-hours', async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT
                EXTRACT(HOUR FROM created_at)::int AS hour,
                COUNT(*) AS requests
            FROM api_logs
            WHERE created_at >= NOW() - INTERVAL '30 days'
            GROUP BY hour
            ORDER BY hour ASC
        `);

        if (result.rows.length === 0) {
            return res.json([]);
        }

        const maxRequests = Math.max(...result.rows.map(r => parseInt(r.requests)));

        const peaks = result.rows.map(row => {
            const h = parseInt(row.hour);
            const count = parseInt(row.requests);
            const level = maxRequests > 0 ? count / maxRequests : 0;
            let label;
            if (level >= 0.85) label = 'Pico';
            else if (level >= 0.6) label = 'Alto';
            else if (level >= 0.35) label = 'Medio';
            else label = 'Bajo';

            return {
                hour: `${String(h).padStart(2, '0')}:00`,
                requests: count,
                level: parseFloat(level.toFixed(2)),
                label,
            };
        });

        res.json(peaks);
    } catch (error) {
        console.error('Error peak-hours:', error);
        res.status(500).json({ error: 'Error al obtener horas pico' });
    }
});

// ── Log de alerta de proximidad ──
// POST /api/stats/log-alert
// Cuando un usuario activa una alerta de llegada de bus en la app,
// se registra aquí para que el equipo pueda ver qué líneas y paradas
// tienen más demanda. Solo envía una notificación a Discord.
app.post('/api/stats/log-alert', async (req, res) => {
    const { stopName, line, destination } = req.body;
    sendDiscordNotification(`🔔 **Alerta Activada**: Usuario esperando \`${line} -> ${destination}\` en **${stopName}**`);
    res.json({ success: true });
});

// ==========================================
// RUTAS DE HISTORIAL DE VIAJES
// ==========================================
// Todas protegidas por JWT: el usuario SOLO puede ver y gestionar SUS viajes.
// Cada viaje almacena: línea, destino, parada, timestamp y si fue confirmado.

// ── Obtener historial de viajes del usuario ──
// GET /api/trips
// Devuelve todos los viajes del usuario autenticado, ordenados del más reciente al más antiguo.
app.get('/api/trips', authenticateToken, async (req, res) => {
    try {
        const result = await pool.query(
            `SELECT id, line, destination, stop_name AS "stopName", stop_id AS "stopId",
             timestamp, confirmed, payment_method AS "paymentMethod"
             FROM trips
             WHERE user_id = $1
             ORDER BY timestamp DESC`,
            [req.user.id]
        );
        res.json(result.rows);
    } catch (error) {
        console.error('Error al obtener viajes:', error);
        res.status(500).json({ error: 'Error al obtener el historial' });
    }
});

// ── Guardar un nuevo viaje ──
// POST /api/trips
// La app envía los datos del viaje cuando el usuario confirma que ha cogido el bus.
// Campos obligatorios: line, destination, stopName, stopId, timestamp.
// El campo 'confirmed' indica si el usuario confirmó manualmente el viaje (true)
// o fue detectado automáticamente por proximidad (false).
app.post('/api/trips', authenticateToken, async (req, res) => {
    const { line, destination, stopName, stopId, timestamp, confirmed, paymentMethod } = req.body;
    if (!line || !destination || !stopName || stopId === undefined || !timestamp) {
        return res.status(400).json({ error: 'Datos del viaje incompletos' });
    }
    try {
        const result = await pool.query(
            `INSERT INTO trips (user_id, line, destination, stop_name, stop_id, timestamp, confirmed, payment_method)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
             RETURNING id, line, destination, stop_name AS "stopName", stop_id AS "stopId", timestamp, confirmed, payment_method AS "paymentMethod"`,
            [req.user.id, line, destination, stopName, stopId, timestamp, confirmed ?? false, paymentMethod || null]
        );

        // Notificar a Discord
        const trip = result.rows[0];
        sendDiscordNotification(`🎫 **Viaje Validado**: \`${req.user.email}\` ha validado un viaje en la **${line}** hacia **${destination}** (Parada: ${stopName})`);

        res.status(201).json(trip);
    } catch (error) {
        console.error('Error al guardar viaje:', error);
        res.status(500).json({ error: 'Error al guardar el viaje' });
    }
});

// ── Eliminar un viaje individual por ID ──
// DELETE /api/trips/:id
// El usuario puede deslizar un viaje en la app para eliminarlo.
// Solo puede borrar sus propios viajes (WHERE user_id = req.user.id).
app.delete('/api/trips/:id', authenticateToken, async (req, res) => {
    const { id } = req.params;
    try {
        const result = await pool.query(
            'DELETE FROM trips WHERE id = $1 AND user_id = $2 RETURNING id',
            [id, req.user.id]
        );
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Viaje no encontrado' });
        }
        res.json({ message: 'Viaje eliminado' });
    } catch (error) {
        console.error('Error al eliminar viaje:', error);
        res.status(500).json({ error: 'Error al eliminar el viaje' });
    }
});

// ── Borrar todo el historial del usuario ──
// DELETE /api/trips
// Elimina TODOS los viajes del usuario autenticado de una vez.
// La app muestra un diálogo de confirmación antes de hacer esta petición.
app.delete('/api/trips', authenticateToken, async (req, res) => {
    try {
        await pool.query('DELETE FROM trips WHERE user_id = $1', [req.user.id]);
        res.json({ message: 'Historial borrado' });
    } catch (error) {
        console.error('Error al borrar historial:', error);
        res.status(500).json({ error: 'Error al borrar el historial' });
    }
});

// ── Dashboard unificado de analíticas (Admin) ──
// GET /api/stats/dashboard
// Endpoint principal del panel de administración.
// Ejecuta ~21 consultas SQL en paralelo (Promise.all) para obtener
// todas las métricas de un solo golpe:
// - Usuarios: total, verificados, registrados esta semana, activos en 7 días.
// - Viajes: total, confirmados, por línea, por hora, paradas top, viajes diarios.
// - API: endpoints más usados, tiempo medio de respuesta, consultas 7 días.
// - Avisos: total, activos, distribución por línea.
// - Premium: número de usuarios premium y facturación estimada.
// La paralelización con Promise.all minimiza la latencia total.
// ── Telemetría de la Landing Page ──
// POST /api/metrics/web
// Registra visitas y clics en descarga.
app.post('/api/metrics/web', express.json(), async (req, res) => {
    const { event_type } = req.body;
    const ip = req.ip;
    const ua = req.get('User-Agent') || 'Desconocido';

    try {
        await pool.query(
            "INSERT INTO web_metrics (event_type, ip, user_agent) VALUES ($1, $2, $3)",
            [event_type, ip, ua]
        );

        // Notificar clics de descarga a Discord (Visitas son silenciosas para evitar spam)
        if (event_type === 'download_click') {
            let device = 'Móvil o Web';
            if (/android/i.test(ua)) device = 'Android 🤖';
            else if (/iphone|ipad|ipod/i.test(ua)) device = 'iOS 🍏';

            sendDiscordNotification({
                embeds: [{
                    title: "📥 Nuevo Click en Descarga (Web)",
                    description: "Un usuario ha pulsado el botón de descarga en la página web.",
                    color: 0x00FF00,
                    fields: [
                        { name: "Dispositivo", value: device, inline: true },
                        { name: "IP", value: ip, inline: true }
                    ],
                    footer: { text: "Alzitrans Web Tracker" }
                }]
            });
        }

        res.json({ success: true });
    } catch (error) {
        console.error('Error saving web metrics:', error);
        res.status(500).json({ error: 'Error' });
    }
});

// ── Estadísticas públicas para la Landing Page ──
// GET /api/stats/public
// Devuelve métricas básicas (usuarios totales) para mostrar en la web.
// No requiere autenticación.
app.get('/api/stats/public', async (req, res) => {
    try {
        const result = await pool.query("SELECT COUNT(*) FROM users");
        const count = parseInt(result.rows[0].count);

        // Redondear a la baja para dar un efecto de "más de" (opcional)
        // O devolver el número exacto. Devolveremos el exacto.
        res.json({ totalUsers: count });
    } catch (error) {
        console.error('Error en /stats/public:', error);
        res.status(500).json({ error: 'Error' });
    }
});

app.get('/api/stats/dashboard', authenticateAdmin, async (req, res) => {
    try {
        const [
            usersTotal,
            usersVerified,
            usersThisWeek,
            usersActive7d,
            tripsTotal,
            tripsConfirmed,
            tripsByLine,
            tripsByHour,
            topStops,
            dailyRegistrations,
            dailyTrips,
            apiPerf,
            noticesTotal,
            noticesActive,
            noticesByLine,
            todayQueries,
            queries7d,
            queriesPrev7d,
            avgResponseTime,
            totalStopsResult,
            premiumUsersResult,
            qrTotalResult,
            qrTodayResult,
            qrByStopResult,
            qrByDeviceResult,
        ] = await Promise.all([
            pool.query("SELECT COUNT(*) FROM users"),
            pool.query("SELECT COUNT(*) FROM users WHERE is_verified = true"),
            pool.query("SELECT COUNT(*) FROM users WHERE created_at >= NOW() - INTERVAL '7 days'"),
            pool.query("SELECT COUNT(DISTINCT id) FROM users WHERE last_access >= NOW() - INTERVAL '7 days'"),
            pool.query("SELECT COUNT(*) FROM trips"),
            pool.query("SELECT COUNT(*) FROM trips WHERE confirmed = true"),
            pool.query("SELECT line, COUNT(*) as cnt FROM trips GROUP BY line ORDER BY cnt DESC"),
            pool.query("SELECT EXTRACT(HOUR FROM timestamp) as hour, COUNT(*) as cnt FROM trips GROUP BY hour ORDER BY hour"),
            pool.query("SELECT stop_name, COUNT(*) as cnt FROM trips GROUP BY stop_name ORDER BY cnt DESC LIMIT 10"),
            pool.query(`SELECT DATE(created_at) as day, COUNT(*) as cnt FROM users
                        WHERE created_at >= NOW() - INTERVAL '30 days'
                        GROUP BY day ORDER BY day`),
            pool.query(`SELECT DATE(timestamp) as day, COUNT(*) as cnt FROM trips
                        WHERE timestamp >= NOW() - INTERVAL '30 days'
                        GROUP BY day ORDER BY day`),
            pool.query(`SELECT endpoint,
                         ROUND(AVG(duration_ms)) as avg_ms,
                         COUNT(*) as calls,
                         ROUND(MAX(duration_ms)) as max_ms
                        FROM api_logs
                        WHERE created_at >= NOW() - INTERVAL '7 days'
                        GROUP BY endpoint ORDER BY calls DESC LIMIT 10`),
            pool.query("SELECT COUNT(*) FROM notices"),
            pool.query("SELECT COUNT(*) FROM notices WHERE active = true AND (expires_at IS NULL OR expires_at > NOW())"),
            pool.query("SELECT COALESCE(line, 'General') as line, COUNT(*) as cnt FROM notices GROUP BY line ORDER BY cnt DESC"),
            pool.query("SELECT COUNT(*) FROM api_logs WHERE created_at >= CURRENT_DATE"),
            pool.query("SELECT COUNT(*) FROM api_logs WHERE created_at >= NOW() - INTERVAL '7 days'"),
            pool.query("SELECT COUNT(*) FROM api_logs WHERE created_at < NOW() - INTERVAL '7 days' AND created_at >= NOW() - INTERVAL '14 days'"),
            pool.query("SELECT AVG(duration_ms) FROM api_logs WHERE created_at >= NOW() - INTERVAL '7 days'"),
            pool.query("SELECT COUNT(*) FROM stops"),
            pool.query("SELECT COUNT(*) FROM users WHERE is_premium = TRUE"),
            pool.query("SELECT COUNT(*) AS count FROM qr_scans"), // Total escaneos QR
            pool.query("SELECT COUNT(*) AS count FROM qr_scans WHERE created_at >= NOW() - INTERVAL '24 hours'"), // Escaneos hoy
            pool.query(`SELECT stop_name as name, COUNT(*) as cnt 
                        FROM qr_scans 
                        WHERE stop_name IS NOT NULL 
                        GROUP BY stop_name ORDER BY cnt DESC LIMIT 10`), // Top paradas QR
            pool.query("SELECT device, COUNT(*) as cnt FROM qr_scans GROUP BY device ORDER BY cnt DESC"), // Dispositivos QR
        ]);

        const qrTotal = parseInt(qrTotalResult.rows[0].count || 0);
        const qrToday = parseInt(qrTodayResult.rows[0].count || 0);

        // Debug log para verificar por qué marca 0 si hay datos
        console.log(`[DASHBOARD] QR Total: ${qrTotal}, Hoy: ${qrToday}, Filas: ${qrTotalResult.rows.length}`);

        const cur7 = parseInt(queries7d.rows[0].count);
        const prev7 = parseInt(queriesPrev7d.rows[0].count);
        const growth = prev7 > 0 ? ((cur7 - prev7) / prev7) * 100 : 0;
        const totalStopsCount = parseInt(totalStopsResult.rows[0].count || 0);

        res.json({
            todayQueries: parseInt(todayQueries.rows[0].count),
            weeklyGrowth: parseFloat(growth.toFixed(1)),
            avgResponseTime: Math.round(parseFloat(avgResponseTime.rows[0].avg || 0)),
            activeUsers: parseInt(usersTotal.rows[0].count),
            totalStops: totalStopsCount,
            premiumUsers: parseInt(premiumUsersResult.rows[0].count || 0),
            totalRevenue: (parseInt(premiumUsersResult.rows[0].count || 0) * 2.99).toFixed(2),
            qr: {
                total: qrTotal,
                today: qrToday,
                byStop: qrByStopResult.rows.map(r => ({ ...r, cnt: parseInt(r.cnt) })),
                byDevice: qrByDeviceResult.rows.map(r => ({ ...r, cnt: parseInt(r.cnt) })),
            },
            users: {
                total: parseInt(usersTotal.rows[0].count),
                verified: parseInt(usersVerified.rows[0].count),
                thisWeek: parseInt(usersThisWeek.rows[0].count),
                active7d: parseInt(usersActive7d.rows[0].count),
                verificationRate: usersTotal.rows[0].count > 0
                    ? Math.round((usersVerified.rows[0].count / usersTotal.rows[0].count) * 100)
                    : 0,
            },
            trips: {
                total: parseInt(tripsTotal.rows[0].count),
                confirmed: parseInt(tripsConfirmed.rows[0].count),
                confirmationRate: tripsTotal.rows[0].count > 0
                    ? Math.round((tripsConfirmed.rows[0].count / tripsTotal.rows[0].count) * 100)
                    : 0,
                byLine: tripsByLine.rows.map(r => ({ ...r, cnt: parseInt(r.cnt) })),
                byHour: tripsByHour.rows.map(r => ({ ...r, cnt: parseInt(r.cnt) })),
                topStops: topStops.rows.map(r => ({ ...r, cnt: parseInt(r.cnt) })),
                dailyTrips: dailyTrips.rows.map(r => ({ ...r, cnt: parseInt(r.cnt), day: r.day })),
            },
            users_daily: dailyRegistrations.rows.map(r => ({ ...r, cnt: parseInt(r.cnt), day: r.day })),
            api: {
                endpoints: apiPerf.rows.map(r => ({
                    ...r,
                    avg_ms: parseInt(r.avg_ms),
                    calls: parseInt(r.calls),
                    max_ms: parseInt(r.max_ms)
                })),
                totalQueries7d: cur7,
            },
            notices: {
                total: parseInt(noticesTotal.rows[0].count),
                active: parseInt(noticesActive.rows[0].count),
                byLine: noticesByLine.rows.map(r => ({ ...r, cnt: parseInt(r.cnt) })),
            },
        });
    } catch (error) {
        console.error('Error en /stats:', error);
        res.status(500).json({ error: 'Error al obtener estadísticas' });
    }
});

app.get('/api/stats/usage', authenticateAdmin, async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT DATE(created_at) as day, COUNT(*) as queries 
            FROM api_logs 
            WHERE created_at >= NOW() - INTERVAL '7 days'
            GROUP BY day ORDER BY day
        `);
        res.json(result.rows);
    } catch (error) {
        res.status(500).json({ error: 'Error' });
    }
});

app.get('/api/stats/activity', authenticateAdmin, async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT endpoint as action, 'System' as user, created_at as time, 'system' as type
            FROM api_logs
            ORDER BY created_at DESC LIMIT 10
        `);
        res.json(result.rows);
    } catch (error) {
        res.status(500).json({ error: 'Error' });
    }
});

// 12. Top paradas (Admin)
app.get('/api/stats/top-stops', authenticateAdmin, async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT stop_name as name, COUNT(*) as visits 
            FROM trips 
            GROUP BY stop_name 
            ORDER BY visits DESC 
            LIMIT 10
        `);
        res.json(result.rows);
    } catch (error) {
        console.error('Error en /stats/top-stops:', error);
        res.status(500).json({ error: 'Error' });
    }
});

// 13. Horas pico (Admin)
app.get('/api/stats/peak-hours', authenticateAdmin, async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT 
                EXTRACT(HOUR FROM timestamp) || 'h' as hour, 
                COUNT(*)::float / NULLIF((SELECT MAX(cnt) FROM (SELECT COUNT(*) as cnt FROM trips GROUP BY EXTRACT(HOUR FROM timestamp)) s), 0) as level,
                CASE 
                    WHEN COUNT(*) > 50 THEN 'ALTA'
                    WHEN COUNT(*) > 20 THEN 'MEDIA'
                    ELSE 'BAJA'
                END as label
            FROM trips 
            GROUP BY hour 
            ORDER BY hour
        `);
        res.json(result.rows);
    } catch (error) {
        console.error('Error en /stats/peak-hours:', error);
        res.status(500).json({ error: 'Error' });
    }
});

// ── Reporte diario automático a Discord ──
// Un setInterval que se ejecuta cada 5 minutos y verifica si es medianoche.
// A las 00:00 genera un resumen del día anterior:
// - Número de usuarios nuevos registrados.
// - Número de viajes validados.
// - Línea más usada.
// Envía el resumen como notificación a Discord.
// La variable lastReportDate evita enviar más de un reporte por día.
let lastReportDate = '';

setInterval(async () => {
    const now = new Date();
    const todayStr = now.toISOString().split('T')[0];

    // Ejecutar a las 00:00 (o poco después) si no se ha enviado hoy
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

            // Datos adicionales para el reporte mejorado
            const activeRes = await pool.query(
                "SELECT COUNT(DISTINCT id) FROM users WHERE last_access::date = $1", [yStr]
            );
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
}, 300000); // Revisar cada 5 minutos

// ==========================================
// PAGOS PREMIUM (STRIPE + BIZUM)
// ==========================================
// Estos endpoints gestionan el flujo de pago para la suscripción Premium.
// Flujo completo:
// 1. La app llama a /create-intent para crear un PaymentIntent en Stripe.
// 2. Stripe devuelve un clientSecret que la app usa para mostrar el Payment Sheet.
// 3. El usuario paga con tarjeta o Bizum.
// 4. Stripe notifica vía webhook (/api/payments/webhook) que el pago fue exitoso.
// 5. El webhook actualiza is_premium = TRUE en la DB.
// 6. Si el webhook falla, la app puede usar /confirm-manual como fallback.

// ── Crear Intención de Pago (PaymentIntent) ──
// POST /api/payments/create-intent
// Crea un PaymentIntent en Stripe por 2,99€ (299 céntimos).
// El metadata incluye el userId y email para identificar al usuario en el webhook.
app.post('/api/payments/create-intent', authenticateToken, async (req, res) => {
    const { amount = 299 } = req.body; // Precio por defecto: 2,99€ en céntimos

    try {
        const paymentIntent = await stripe.paymentIntents.create({
            amount: amount,
            currency: 'eur',
            payment_method_types: ['card', 'bizum'], // Soporte para Bizum y Tarjeta
            metadata: {
                userId: req.user.id.toString(),
                email: req.user.email
            },
        });

        res.json({
            clientSecret: paymentIntent.client_secret,
        });
    } catch (error) {
        console.error('[Stripe] Error creando intent:', error);
        res.status(500).json({ error: error.message });
    }
});

// ── Confirmación Manual de Premium ──
// POST /api/payments/confirm-manual
// Fallback si el webhook de Stripe no funciona (por ejemplo, si el servidor
// no es accesible desde Internet).
// La app detecta que el pago fue exitoso y llama directamente a este endpoint
// para activar Premium. Menos seguro que el webhook, pero funcional.
app.post('/api/payments/confirm-manual', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        await pool.query('UPDATE users SET is_premium = TRUE WHERE id = $1', [userId]);
        console.log(`[Stripe] Usuario ${userId} confirmado manualmente como PREMIUM`);
        sendDiscordNotification(`💎 **Nuevo Usuario Premium (Confirmación Manual)**: El usuario ID \`${userId}\` ha sido activado.`);
        res.json({ success: true, message: 'Usuario actualizado a Premium' });
    } catch (error) {
        console.error('[Stripe] Error en confirmación manual:', error);
        res.status(500).json({ error: 'Error al actualizar estado Premium' });
    }
});

// ── Métricas y Notificaciones Adicionales (Discord) ──

// POST /api/metrics/install
// Notifica cuando se instala por primera vez la aplicación
app.post('/api/metrics/install', async (req, res) => {
    try {
        const { referrer } = req.body;
        const ip = req.ip || req.headers['x-forwarded-for'];
        sendDiscordNotification({
            embeds: [{
                title: '🎉 Nueva Instalación de la App',
                description: `Alguien acaba de abrir la app por primera vez (o ha borrado datos).`,
                color: 0x2ECC71, // Verde
                fields: [
                    { name: 'Referrer', value: referrer || 'Orgánico / Ninguno', inline: false },
                    { name: 'IP', value: ip || 'Desconocida', inline: true }
                ]
            }]
        });
        res.json({ success: true });
    } catch (error) {
        console.error('[Metrics] Error en install:', error);
        res.status(500).json({ error: 'Error del servidor' });
    }
});

// Middleware opcional de autenticación para obtener el email si está disponible
const optionalToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];
    if (token) {
        jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
            if (!err) req.user = user;
            next();
        });
    } else {
        next();
    }
};

// POST /api/metrics/app-open
// Notifica cuando se abre o se resume la aplicación
app.post('/api/metrics/app-open', optionalToken, async (req, res) => {
    try {
        const ip = req.ip || req.headers['x-forwarded-for'];
        const identity = (req.user && req.user.email) ? req.user.email : 'Visitante Anónimo';
        
        sendDiscordNotification({
            embeds: [{
                title: '📱 Aplicación Abierta',
                description: `Un usuario ha entrado en la app Alzitrans.`,
                color: 0x3498DB, // Azul
                fields: [
                    { name: 'Usuario', value: identity, inline: true },
                    { name: 'IP', value: ip || 'Desconocida', inline: true }
                ]
            }]
        });
        res.json({ success: true });
    } catch (error) {
        console.error('[Metrics] Error en app-open:', error);
        res.status(500).json({ error: 'Error del servidor' });
    }
});

// ── Iniciar el servidor HTTP ──
// Escucha en todas las interfaces de red ('0.0.0.0') para aceptar
// conexiones tanto locales como remotas (importante para la Raspberry Pi).
// El puerto se lee de la variable de entorno PORT o usa 4000 por defecto.
server.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Servidor y WebSockets corriendo en puerto ${PORT}`);
});
