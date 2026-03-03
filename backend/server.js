const express = require('express');
const { sendDiscordNotification } = require('./utils/discord');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const rateLimit = require('express-rate-limit');
const nodemailer = require('nodemailer');
const helmet = require('helmet');
const pool = require('./db');
require('dotenv').config();

const app = express();
const server = http.createServer(app);

// Configuración de CORS dinámica
const allowedOrigins = process.env.ALLOWED_ORIGINS ? process.env.ALLOWED_ORIGINS.split(',') : ['*'];

const io = socketIo(server, {
    cors: {
        origin: allowedOrigins,
        methods: ["GET", "POST"]
    }
});

// Middleware de depuración: Registrar TODAS las peticiones entrantes
app.use((req, res, next) => {
    console.log(`[DEBUG] ${req.method} ${req.url} desde ${req.ip}`);
    next();
});

// Middlewares
// Desactivamos helmet temporalmente o lo configuramos para permitir CORS
app.use(helmet({
    crossOriginResourcePolicy: false,
}));
app.use(cors({
    origin: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-API-Key'],
    credentials: true,
    preflightContinue: false,
    optionsSuccessStatus: 204
}));
app.use(express.json()); // Para poder leer JSON en el body de las peticiones

// ==========================================
// MIDDLEWARE: VALIDACIÓN DE API KEY
// ==========================================
// Todas las rutas /api/* requieren el header X-API-Key correcto.
const validateApiKey = (req, res, next) => {
    // Las peticiones OPTIONS (preflight de CORS) no llevan headers personalizados
    // y deben permitirse para que el navegador pueda validar la conexión.
    if (req.method === 'OPTIONS') {
        return next();
    }

    const apiKey = req.headers['x-api-key'];
    if (!apiKey || apiKey !== process.env.API_KEY) {
        console.warn(`[API Key] Petición rechazada desde ${req.ip}`);
        sendDiscordNotification(`⚠️ **Petición rechazada**: API Key inválida desde ${req.ip} para \`${req.method} ${req.url}\``);
        return res.status(401).json({ error: 'API Key inválida o no proporcionada' });
    }
    next();
};

app.use('/api', validateApiKey);

// Endpoint de salud para verificar conectividad sin base de datos
app.get('/api/health', (req, res) => {
    res.json({ status: 'ok', message: 'Backend Alzibus alcanzable' });
});

// Middleware para registrar las peticiones a la API
app.use((req, res, next) => {
    const start = Date.now();
    res.on('finish', () => {
        const duration = Date.now() - start;
        // No registrar las peticiones de stats para no inflar los números
        if (!req.path.startsWith('/api/stats')) {
            pool.query(
                'INSERT INTO api_logs (endpoint, method, duration_ms) VALUES ($1, $2, $3)',
                [req.path, req.method, duration]
            ).catch(err => console.error('Error logging API request:', err));
        }
    });
    next();
});

const PORT = process.env.PORT || 4000;

// ==========================================
// MIDDLEWARE: AUTENTICACIÓN JWT
// ==========================================
// Protege rutas que requieren usuario autenticado.
const authenticateToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1]; // Bearer <token>
    if (!token) return res.status(401).json({ error: 'Token requerido' });
    jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
        if (err) return res.status(403).json({ error: 'Token inválido o expirado' });
        req.user = user;
        next();
    });
};



// ==========================================
// LIMITADORES DE FRECUENCIA (SECURITY)
// ==========================================

// Limita creación de cuentas
const registerLimiter = rateLimit({
    windowMs: 60 * 60 * 1000, // 1 hora
    max: 5,
    message: { error: 'Demasiadas cuentas creadas. Reinténtalo en una hora.' },
    standardHeaders: true,
    legacyHeaders: false,
});

// Limita intentos de login (Anti Bruteforce)
const loginLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutos
    max: 10,
    message: { error: 'Demasiados intentos de inicio de sesión. Reinténtalo en 15 minutos.' },
    standardHeaders: true,
    legacyHeaders: false,
    handler: (req, res, next, options) => {
        sendDiscordNotification(`🛡️ **Brute Force bloqueado**: Múltiples fallos de login desde IP ${req.ip}`);
        res.status(options.statusCode).send(options.message);
    }
});

const authenticateAdmin = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) return res.status(401).json({ error: 'Token de administrador requerido' });

    jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
        if (err || user.role !== 'admin') {
            return res.status(403).json({ error: 'Acceso denegado: Se requieren privilegios de administrador' });
        }
        req.user = user;
        next();
    });
};

// ==========================================
// ENDPOINT: LOGIN ADMINISTRADOR
// ==========================================
app.post('/api/admin/login', loginLimiter, async (req, res) => {
    const { password } = req.body;

    if (!password) {
        return res.status(400).json({ error: 'Contraseña requerida' });
    }

    // Comparamos con la contraseña de admin en .env
    if (password === process.env.ADMIN_PASSWORD) {
        const token = jwt.sign(
            { id: 'admin', email: 'admin@alzitrans.com', role: 'admin' },
            process.env.JWT_SECRET,
            { expiresIn: '12h' }
        );
        sendDiscordNotification(`🔏 **Panel Admin**: Sesión iniciada correctamente.`);
        return res.json({ token });
    } else {
        sendDiscordNotification(`❌ **Fallo de Admin**: Intento de login administrativo incorrecto desde ${req.ip}`);
        return res.status(401).json({ error: 'Contraseña de administrador incorrecta' });
    }
});
// ==========================================
// HELPER: Enviar email de verificación y responder al cliente
// ==========================================
async function sendOtpEmail(email, verificationCode) {
    // Log del código para desarrollo
    console.log(`[OTP] Código de verificación para ${email}: ${verificationCode}`);

    const transporter = nodemailer.createTransport({
        host: process.env.EMAIL_HOST || 'localhost',
        port: parseInt(process.env.EMAIL_PORT) || 587,
        secure: false,
        auth: {
            user: process.env.EMAIL_USER,
            pass: process.env.EMAIL_PASS
        },
        tls: { rejectUnauthorized: false }
    });

    const mailOptions = {
        from: process.env.EMAIL_FROM || 'AlziTrans <bcarreres55@gmail.com>',
        to: email,
        subject: 'Verifica tu cuenta de Alzibus',
        text: `Tu código de verificación es: ${verificationCode}\nEste código caduca en 15 minutos.`
    };

    // Enviar sin bloquear
    transporter.sendMail(mailOptions)
        .then(() => console.log('Correo OTP enviado a', email))
        .catch(err => console.error('Error enviando correo:', err.message));
}

function sendVerificationAndRespond(res, email, verificationCode, newUser) {
    sendOtpEmail(email, verificationCode);
    return res.status(201).json({
        message: 'Usuario registrado. Por favor verifica tu email.',
        user: newUser.rows[0],
        requiresVerification: true
    });
}

// 1. Registro de usuario
app.post('/api/register', registerLimiter, async (req, res) => {
    const { email, password } = req.body;

    if (!email || !password) {
        return res.status(400).json({ error: 'Email y contraseña son obligatorios' });
    }

    try {
        // Limpiar cuentas no verificadas de más de 5 minutos (anti-basura)
        await pool.query(
            "DELETE FROM users WHERE is_verified = false AND created_at < NOW() - INTERVAL '5 minutes'"
        );

        // Verificar si el usuario ya existe
        const userExists = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
        if (userExists.rows.length > 0) {
            const existingUser = userExists.rows[0];
            // Si ya está verificado, rechazar
            if (existingUser.is_verified) {
                return res.status(400).json({ error: 'El usuario ya existe' });
            }
            // Si NO está verificado, permitir re-registro (actualizar contraseña y código)
            const saltRounds = 10;
            const passwordHash = await bcrypt.hash(password, saltRounds);
            const verificationCode = Math.floor(100000 + Math.random() * 900000).toString();
            await pool.query(
                'UPDATE users SET password_hash = $1, verification_code = $2, created_at = NOW() WHERE id = $3',
                [passwordHash, verificationCode, existingUser.id]
            );
            // Enviar nuevo correo (más abajo)
            const newUser = { rows: [{ id: existingUser.id, email: existingUser.email }] };
            // Saltar al envío de email ↓
            return sendVerificationAndRespond(res, email, verificationCode, newUser);
        }

        // Encriptar la contraseña (10 rondas de sal)
        const saltRounds = 10;
        const passwordHash = await bcrypt.hash(password, saltRounds);

        // Generar código OTP y fecha de expiración (15 minutos)
        const verificationCode = Math.floor(100000 + Math.random() * 900000).toString();
        const otpExpiresAt = new Date(Date.now() + 15 * 60 * 1000);

        // Guardar en la base de datos de manera INACTIVA y con el código
        const newUser = await pool.query(
            `INSERT INTO users (email, password_hash, is_verified, verification_code, otp_expires_at, otp_attempts, otp_resend_count)
             VALUES ($1, $2, false, $3, $4, 0, 0) RETURNING id, email`,
            [email, passwordHash, verificationCode, otpExpiresAt]
        );

        // Notificar a Discord (sin bloquear la respuesta)
        sendDiscordNotification(`🚀 **Nuevo usuario registrado**: \`${email}\` (ID: ${newUser.rows[0].id})`);

        return sendVerificationAndRespond(res, email, verificationCode, newUser);
    } catch (error) {
        console.error('Error en registro:', error);
        res.status(500).json({ error: 'Error interno del servidor' });
    }
});

// 1.5. Verificación de Correo (OTP)
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

        // Comprobar penalización por demasiados intentos fallidos
        if (user.otp_penalty_until && new Date() < new Date(user.otp_penalty_until)) {
            const minutesLeft = Math.ceil((new Date(user.otp_penalty_until) - new Date()) / 60000);
            return res.status(429).json({
                error: `Demasiados intentos incorrectos. Espera ${minutesLeft} minuto(s) antes de intentarlo de nuevo.`
            });
        }

        // Comprobar si el código ha caducado
        if (user.otp_expires_at && new Date() > new Date(user.otp_expires_at)) {
            return res.status(400).json({ error: 'El código ha caducado. Solicita uno nuevo.' });
        }

        // Comprobar si el código es correcto
        if (user.verification_code !== code) {
            const newAttempts = (user.otp_attempts || 0) + 1;

            if (newAttempts >= 3) {
                // Penalizar durante 30 minutos
                const penaltyUntil = new Date(Date.now() + 30 * 60 * 1000);
                await pool.query(
                    'UPDATE users SET otp_attempts = $1, otp_penalty_until = $2 WHERE id = $3',
                    [newAttempts, penaltyUntil, user.id]
                );
                return res.status(429).json({
                    error: 'Demasiados intentos fallidos. Cuenta bloqueada 30 minutos. Solicita un nuevo código.'
                });
            }

            await pool.query('UPDATE users SET otp_attempts = $1 WHERE id = $2', [newAttempts, user.id]);
            return res.status(400).json({
                error: `Código incorrecto. Te quedan ${3 - newAttempts} intento(s).`
            });
        }

        // Marcar como verificado y limpiar el código
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

// 1.6. Reenviar código OTP
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

        // Comprobar penalización activa (por intentos fallidos)
        if (user.otp_penalty_until && new Date() < new Date(user.otp_penalty_until)) {
            const minutesLeft = Math.ceil((new Date(user.otp_penalty_until) - new Date()) / 60000);
            return res.status(429).json({
                error: `Tu cuenta está bloqueada. Espera ${minutesLeft} minuto(s).`
            });
        }

        // Máximo 3 reenvíos antes de penalizar 1 hora
        const resendCount = user.otp_resend_count || 0;
        if (resendCount >= 3) {
            const penaltyUntil = new Date(Date.now() + 60 * 60 * 1000); // 1 hora
            await pool.query('UPDATE users SET otp_penalty_until = $1 WHERE id = $2', [penaltyUntil, user.id]);
            return res.status(429).json({
                error: 'Has solicitado demasiados códigos. Inicia el registro de nuevo en 1 hora.'
            });
        }

        // Generar nuevo código con nueva expiración
        const newCode = Math.floor(100000 + Math.random() * 900000).toString();
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

// 1.7. Olvido de contraseña - Enviar código
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

        const verificationCode = Math.floor(100000 + Math.random() * 900000).toString();
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

// 1.8. Restablecer contraseña con código
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

        // Validar expiración
        if (user.otp_expires_at && new Date() > new Date(user.otp_expires_at)) {
            return res.status(400).json({ error: 'El código ha caducado' });
        }

        // Validar código
        if (user.verification_code !== code) {
            return res.status(400).json({ error: 'Código de recuperación incorrecto' });
        }

        // Encriptar nueva contraseña
        const saltRounds = 10;
        const passwordHash = await bcrypt.hash(newPassword, saltRounds);

        // Actualizar y limpiar tokens
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

// 2. Login de usuario
app.post('/api/login', loginLimiter, async (req, res) => {
    const { email, password } = req.body;

    if (!email || !password) {
        return res.status(400).json({ error: 'Email y contraseña son obligatorios' });
    }

    try {
        const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
        if (result.rows.length === 0) {
            return res.status(401).json({ error: 'Credenciales inválidas' });
        }

        const user = result.rows[0];

        // Verificar si confirmó el correo (OTP)
        if (user.is_verified === false) {
            return res.status(403).json({ error: 'Debes verificar tu correo antes de iniciar sesión. Revisa tu bandeja de entrada.' });
        }

        // Verificar que la cuenta está activa
        if (user.active === false) {
            return res.status(403).json({ error: 'Cuenta desactivada. Contacta con el administrador.' });
        }

        const validPassword = await bcrypt.compare(password, user.password_hash);
        if (!validPassword) {
            return res.status(401).json({ error: 'Credenciales inválidas' });
        }

        // Actualizar last_access (no bloqueante — puede fallar si columna aún no existe)
        pool.query('UPDATE users SET last_access = NOW() WHERE id = $1', [user.id])
            .catch(err => console.warn('[Login] No se pudo actualizar last_access:', err.message));

        const token = jwt.sign(
            { id: user.id, email: user.email },
            process.env.JWT_SECRET,
            { expiresIn: '24h' }
        );

        res.json({
            message: 'Login exitoso',
            token: token,
            user: { id: user.id, email: user.email }
        });
    } catch (error) {
        console.error('Error en login:', error);
        res.status(500).json({ error: 'Error interno del servidor' });
    }
});

// ==========================================
// RUTAS DE PERFIL DE USUARIO
// ==========================================

// 16. Heartbeat: Actualizar last_access (vía polling desde la app)
app.post('/api/users/heartbeat', authenticateToken, async (req, res) => {
    try {
        await pool.query('UPDATE users SET last_access = NOW() WHERE id = $1', [req.user.id]);
        res.json({ message: 'Heartbeat recibido' });
    } catch (error) {
        console.error('Error en heartbeat:', error);
        res.status(500).json({ error: 'Error interno del servidor' });
    }
});

// 17. Obtener perfil del usuario + estadísticas de viajes
app.get('/api/users/profile', authenticateToken, async (req, res) => {
    try {
        const userResult = await pool.query(
            'SELECT id, email, created_at, last_access FROM users WHERE id = $1',
            [req.user.id]
        );
        if (userResult.rows.length === 0) {
            return res.status(404).json({ error: 'Usuario no encontrado' });
        }
        const user = userResult.rows[0];

        // Stats de viajes
        const totalTrips = await pool.query('SELECT COUNT(*) FROM trips WHERE user_id = $1', [req.user.id]);
        const lineUsage = await pool.query(
            `SELECT line, COUNT(*) as count FROM trips WHERE user_id = $1 GROUP BY line ORDER BY count DESC LIMIT 1`,
            [req.user.id]
        );
        const thisMonthTrips = await pool.query(
            `SELECT COUNT(*) FROM trips WHERE user_id = $1 AND timestamp >= date_trunc('month', NOW())`,
            [req.user.id]
        );

        res.json({
            id: user.id,
            email: user.email,
            createdAt: user.created_at,
            lastAccess: user.last_access,
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

// 17. Actualizar email del usuario
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

// 18. Cambiar contraseña del usuario
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

// ==========================================
// RUTAS DE ADMINISTRACIÓN DE USUARIOS
// ==========================================

// 19. Listar todos los usuarios (solo admin)
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

// 20. Activar/desactivar usuario (solo admin)
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

// 21. Obtener avisos activos (público)
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

// 22. Obtener TODOS los avisos (admin)
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

// 23. Crear aviso
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

// 24. Activar/desactivar aviso
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

// 25. Eliminar aviso
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
// RUTAS DE PARADAS DE AUTOBÚS
// ==========================================


// 3. Obtener todas las paradas (Público)
app.get('/api/stops', async (req, res) => {
    try {
        const result = await pool.query('SELECT * FROM stops ORDER BY id ASC');
        res.json(result.rows);
    } catch (error) {
        console.error('Error al obtener paradas:', error);
        res.status(500).json({ error: 'Error al obtener las paradas' });
    }
});

// 4. Crear una nueva parada
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

// 5. Actualizar una parada existente
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

// 6. Eliminar una parada
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
// RUTAS DE ESTADÍSTICAS (ADMIN PANEL)
// ==========================================

// 7. Obtener estadísticas generales
app.get('/api/stats', authenticateAdmin, async (req, res) => {
    try {
        const stopsCount = await pool.query('SELECT COUNT(*) FROM stops');
        const usersCount = await pool.query('SELECT COUNT(*) FROM users');
        const todayQueries = await pool.query('SELECT COUNT(*) FROM api_logs WHERE created_at >= CURRENT_DATE');
        const avgResponseTime = await pool.query('SELECT AVG(duration_ms) FROM api_logs');

        // Calcular crecimiento semanal REAL comparando esta semana vs la anterior
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

        // Calcular rutas únicas (L1, L2, L3)
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

// 8. Obtener uso por día (últimos 7 días)
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

// 9. Obtener actividad reciente
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

// 10. Paradas más visitadas (desde trips — cada viaje confirmado cuenta como visita)
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


// 11. Horas pico (desde api_logs, agrupado por hora)
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

// 11.5. Registrar alerta de proximidad (desde la App)
app.post('/api/stats/log-alert', async (req, res) => {
    const { stopName, line, destination } = req.body;
    sendDiscordNotification(`🔔 **Alerta Activada**: Usuario esperando \`${line} -> ${destination}\` en **${stopName}**`);
    res.json({ success: true });
});

// ==========================================
// RUTAS DE HISTORIAL DE VIAJES
// ==========================================
// Todas protegidas por JWT (el usuario solo ve sus propios viajes)

// 12. Obtener historial de viajes del usuario
app.get('/api/trips', authenticateToken, async (req, res) => {
    try {
        const result = await pool.query(
            `SELECT id, line, destination, stop_name AS "stopName", stop_id AS "stopId",
             timestamp, confirmed
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

// 13. Guardar un nuevo viaje
app.post('/api/trips', authenticateToken, async (req, res) => {
    const { line, destination, stopName, stopId, timestamp, confirmed } = req.body;
    if (!line || !destination || !stopName || stopId === undefined || !timestamp) {
        return res.status(400).json({ error: 'Datos del viaje incompletos' });
    }
    try {
        const result = await pool.query(
            `INSERT INTO trips (user_id, line, destination, stop_name, stop_id, timestamp, confirmed)
             VALUES ($1, $2, $3, $4, $5, $6, $7)
             RETURNING id, line, destination, stop_name AS "stopName", stop_id AS "stopId", timestamp, confirmed`,
            [req.user.id, line, destination, stopName, stopId, timestamp, confirmed ?? false]
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

// 14. Eliminar un viaje por ID
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

// 15. Borrar todo el historial del usuario
app.delete('/api/trips', authenticateToken, async (req, res) => {
    try {
        await pool.query('DELETE FROM trips WHERE user_id = $1', [req.user.id]);
        res.json({ message: 'Historial borrado' });
    } catch (error) {
        console.error('Error al borrar historial:', error);
        res.status(500).json({ error: 'Error al borrar el historial' });
    }
});

// ANALYTICS: Dashboard de estadísticas (Admin Only)
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
        ]);

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

// Reporte diario a medianoche
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

            const message = `📊 **RESUMEN DIARIO (${yStr})**\n` +
                `━━━━━━━━━━━━━━━━━━━━\n` +
                `👤 **Usuarios nuevos**: \`${userCount}\` \n` +
                `🎫 **Viajes validados**: \`${tripCount}\` \n` +
                `🚌 **Línea estrella**: \`${topLine}\` \n` +
                `━━━━━━━━━━━━━━━━━━━━`;

            sendDiscordNotification(message);
        } catch (e) {
            console.error('[Dashboard] Fallo al generar reporte diario:', e);
        }
    }
}, 300000); // Revisar cada 5 minutos

// Iniciar el servidor
server.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Servidor y WebSockets corriendo en puerto ${PORT}`);
});
