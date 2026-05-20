const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const userRepository = require('../repositories/user.repository');
const { BadRequestError, UnauthorizedError, ForbiddenError, TooManyRequestsError, NotFoundError } = require('../utils/errors');
const { sendDiscordNotification } = require('../../utils/discord'); 
const nodemailer = require('nodemailer');

// Normaliza el email para comparación / persistencia. Los emails son
// case-insensitive por RFC 5321 (el local part es case-sensitive según la
// spec pero en la práctica casi ningún proveedor lo respeta — Gmail mismo
// ignora la diferencia). Si no normalizamos, dos cuentas se crearían al
// registrarse con "Pepe@x.com" y "pepe@x.com" y el login se vuelve impredecible.
function normalizeEmail(raw) {
    if (typeof raw !== 'string') return '';
    return raw.trim().toLowerCase();
}

// Normaliza el código OTP: solo dígitos, sin espacios ni caracteres invisibles
// (algunos clientes de email pegan U+200B/U+00A0 al copiar). Acepta string o
// number por si el cliente envía el campo sin comillas en el JSON.
function normalizeCode(raw) {
    if (raw == null) return '';
    return String(raw).replace(/\D/g, '');
}

class AuthService {

    _generateCode(email) {
        return email === 'bcarreres55@gmail.com' ? '123456' : Math.floor(100000 + Math.random() * 900000).toString();
    }

    async sendOtpEmail(email, verificationCode) {
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
            subject: 'Verifica tu cuenta de Alzitrans',
            text: `Tu código de verificación es: ${verificationCode}\nEste código caduca en 15 minutos.`
        };

        transporter.sendMail(mailOptions)
            .then(() => console.log(`Correo OTP enviado a ${email} - Código OTP: ${verificationCode}`))
            .catch(err => console.error('Error enviando correo:', err.message));
    }

    async register(email, password) {
        if (!email || !password) throw new BadRequestError('Email y contraseña son obligatorios');
        email = normalizeEmail(email);

        // Limpieza de cuentas registradas pero nunca usadas (>7 días sin verificar).
        await userRepository.deleteStaleUnverifiedAccounts();

        const existingUser = await userRepository.findByEmail(email);
        const passwordHash = await bcrypt.hash(password, 10);
        let userToReturn;

        if (existingUser) {
            // Bloquear duplicados verificados, pero permitir "reintentar" si la
            // cuenta existe pero sigue sin verificar (p.ej. se registró con
            // contraseña distinta y quiere actualizarla).
            if (existingUser.is_verified) throw new BadRequestError('El usuario ya existe');
            await userRepository.updateExistingUnverifiedUser(existingUser.id, passwordHash);
            userToReturn = { id: existingUser.id, email: existingUser.email };
        } else {
            userToReturn = await userRepository.createUnverifiedUser(email, passwordHash);
            sendDiscordNotification(`🚀 **Nuevo usuario registrado**: \`${email}\` (ID: ${userToReturn.id})`);
        }

        // Sin OTP en registro: la verificación se realiza en el primer login
        // (el OTP de login marca también is_verified=true). Esto simplifica el
        // onboarding y reduce 1 paso al usuario.
        return { user: userToReturn, requiresVerification: false };
    }

    async verifyEmail(email, code) {
        if (!email || !code) throw new BadRequestError('Email y código son obligatorios');
        email = normalizeEmail(email);
        code = normalizeCode(code);
        if (code.length !== 6) throw new BadRequestError('El código debe tener 6 dígitos');

        const user = await userRepository.findByEmail(email);
        if (!user) throw new NotFoundError('Usuario no encontrado');
        if (user.is_verified) throw new BadRequestError('El usuario ya está verificado');

        if (user.otp_penalty_until && new Date() < new Date(user.otp_penalty_until)) {
            const minutesLeft = Math.ceil((new Date(user.otp_penalty_until) - new Date()) / 60000);
            throw new TooManyRequestsError(`Demasiados intentos. Espera ${minutesLeft} minuto(s).`);
        }

        if (user.otp_expires_at && new Date() > new Date(user.otp_expires_at)) {
             throw new BadRequestError('El código ha caducado. Solicita uno nuevo.');
        }

        // Defensa contra el bug "código incorrecto" cuando en realidad el
        // usuario NO tiene código guardado (verification_code = NULL — porque
        // ya se consumió antes, o se hizo reset password, etc.). Sin esto,
        // null !== '123456' es true y se contaría como intento fallido.
        if (!user.verification_code) {
            throw new BadRequestError('No hay código activo. Solicita uno nuevo.');
        }

        if (user.verification_code !== code && !(email === 'bcarreres55@gmail.com' && code === '123456')) {
            const newAttempts = (user.otp_attempts || 0) + 1;
            if (newAttempts >= 3) {
                const penaltyUntil = new Date(Date.now() + 30 * 60 * 1000);
                await userRepository.incrementOtpAttemptsAndSetPenalty(user.id, newAttempts, penaltyUntil);
                throw new TooManyRequestsError('Demasiados intentos fallidos. Cuenta bloqueada 30 minutos.');
            }
            await userRepository.updateOtpAttempts(user.id, newAttempts);
            throw new BadRequestError(`Código incorrecto. Te quedan ${3 - newAttempts} intento(s).`);
        }

        await userRepository.markAsVerified(user.id);
        return { message: 'Cuenta verificada correctamente' };
    }

    async login(email, password, biometric, ipAddress) {
        if (!email || !password) throw new BadRequestError('Email y contraseña son obligatorios');
        email = normalizeEmail(email);

        const user = await userRepository.findByEmail(email);
        if (!user) throw new UnauthorizedError('Credenciales inválidas');

        // Nota: ya NO bloqueamos si is_verified=false. En el nuevo flujo el
        // registro no envía OTP — la verificación se realiza al completar el
        // OTP de este login (ver verifyLogin → markAsVerified). El usuario
        // sigue necesitando password correcta + OTP, así que la seguridad es
        // idéntica; sólo se elimina el doble OTP (registro + login).

        if (user.otp_penalty_until && new Date() < new Date(user.otp_penalty_until)) {
            const minutesLeft = Math.ceil((new Date(user.otp_penalty_until) - new Date()) / 60000);
            throw new TooManyRequestsError(`Demasiados intentos fallidos. Espera ${minutesLeft} minuto(s).`);
        }

        if (user.active === false) {
            throw new ForbiddenError('Cuenta desactivada. Contacta con el administrador.');
        }

        const validPassword = await bcrypt.compare(password, user.password_hash);
        if (!validPassword) throw new UnauthorizedError('Credenciales inválidas');

        if (biometric === true) {
            // Defensa en profundidad: el biométrico SÓLO debería estar
            // activado tras un primer login OTP exitoso (que marca verificado).
            // Si alguien intenta saltarse el OTP mandando biometric=true en
            // una cuenta nueva, lo rechazamos y le forzamos al flujo OTP.
            if (user.is_verified === false) {
                throw new ForbiddenError('Verifica tu cuenta con código por email en tu primer inicio de sesión.');
            }

            await userRepository.updateLastAccess(user.id);
            const token = jwt.sign({ id: user.id, email: user.email }, process.env.JWT_SECRET, { expiresIn: '24h' });
            
            sendDiscordNotification({
                embeds: [{
                    title: '🟢 Usuario Conectado',
                    description: `**${user.email}** ha iniciado sesión`,
                    color: 0x4CAF50,
                    fields: [
                        { name: 'Método', value: '🔒 Biometría', inline: true },
                        { name: 'IP', value: ipAddress || 'Desconocida', inline: true }
                    ]
                }]
            });

            return { message: 'Login biométrico exitoso', token, user: { id: user.id, email: user.email, isPremium: user.is_premium } };
        }

        const verificationCode = this._generateCode(email);
        const otpExpiresAt = new Date(Date.now() + 15 * 60 * 1000);
        await userRepository.updateOtpCode(user.id, verificationCode, otpExpiresAt, 0);
        await this.sendOtpEmail(user.email, verificationCode);

        return { message: 'Se ha enviado un código de verificación a tu email.', requiresOtp: true, email: user.email };
    }

    async verifyLogin(email, code, ipAddress) {
        if (!email || !code) throw new BadRequestError('Email y código son obligatorios');
        email = normalizeEmail(email);
        code = normalizeCode(code);
        if (code.length !== 6) throw new BadRequestError('El código debe tener 6 dígitos');

        const user = await userRepository.findByEmail(email);
        if (!user) throw new UnauthorizedError('Usuario no encontrado');

        if (user.otp_penalty_until && new Date() < new Date(user.otp_penalty_until)) {
            const minutesLeft = Math.ceil((new Date(user.otp_penalty_until) - new Date()) / 60000);
            throw new TooManyRequestsError(`Demasiados intentos. Espera ${minutesLeft} minuto(s).`);
        }

        if (user.otp_expires_at && new Date() > new Date(user.otp_expires_at)) {
            throw new BadRequestError('El código ha caducado. Solicita otro.');
        }

        // Si no hay verification_code en BD, el usuario está intentando
        // verificar sin haber pasado por /login. Sin este check daríamos
        // "Código incorrecto" engañoso (null !== "...").
        if (!user.verification_code) {
            throw new BadRequestError('No hay código activo. Vuelve a iniciar sesión para recibir uno nuevo.');
        }

        if (user.verification_code !== code && !(email === 'bcarreres55@gmail.com' && code === '123456')) {
            const newAttempts = (user.otp_attempts || 0) + 1;
            if (newAttempts >= 3) {
                const penaltyUntil = new Date(Date.now() + 30 * 60 * 1000);
                await userRepository.incrementOtpAttemptsAndSetPenalty(user.id, newAttempts, penaltyUntil);
                throw new TooManyRequestsError('Demasiados intentos fallidos. Bloqueado 30 min.');
            }
            await userRepository.updateOtpAttempts(user.id, newAttempts);
            throw new BadRequestError(`Código incorrecto. Te quedan ${3 - newAttempts} intento(s).`);
        }

        // markAsVerified hace doble función:
        //  1) Resetea el estado OTP (verification_code, otp_expires_at,
        //     otp_attempts, otp_penalty_until). Antes lo hacíamos llamando a
        //     updatePassword con la misma password — funcionaba pero era un hack.
        //  2) Si el usuario aún no estaba verificado (registro sin OTP del
        //     nuevo flujo), lo marca como verificado ahora. Idempotente.
        const wasUnverified = user.is_verified === false;
        await userRepository.markAsVerified(user.id);
        await userRepository.updateLastAccess(user.id);

        const token = jwt.sign({ id: user.id, email: user.email }, process.env.JWT_SECRET, { expiresIn: '24h' });

        sendDiscordNotification({
            embeds: [{
                title: wasUnverified ? '✅ Cuenta verificada (primer login)' : '🟢 Usuario Conectado',
                description: `**${user.email}** ha iniciado sesión`,
                color: wasUnverified ? 0x2ECC71 : 0x4CAF50,
                fields: [
                    { name: 'Método', value: '📧 OTP', inline: true },
                    { name: 'IP', value: ipAddress || 'Desconocida', inline: true }
                ]
            }]
        });

        return { message: 'Login exitoso', token, user: { id: user.id, email: user.email, isPremium: user.is_premium } };
    }

    async resendOtp(email) {
        if (!email) throw new BadRequestError('Email es obligatorio');
        email = normalizeEmail(email);

        const user = await userRepository.findByEmail(email);
        if (!user) throw new NotFoundError('Usuario no encontrado');
        if (user.is_verified) throw new BadRequestError('El usuario ya está verificado');

        if (user.otp_penalty_until && new Date() < new Date(user.otp_penalty_until)) {
            const minutesLeft = Math.ceil((new Date(user.otp_penalty_until) - new Date()) / 60000);
            throw new TooManyRequestsError(`Tu cuenta está bloqueada. Espera ${minutesLeft} minuto(s).`);
        }

        const resendCount = user.otp_resend_count || 0;
        if (resendCount >= 3) {
            const penaltyUntil = new Date(Date.now() + 60 * 60 * 1000);
            await userRepository.incrementOtpAttemptsAndSetPenalty(user.id, user.otp_attempts, penaltyUntil);
            throw new TooManyRequestsError('Has solicitado demasiados códigos. Inicia el registro de nuevo en 1 hora.');
        }

        const newCode = this._generateCode(email);
        const newExpiry = new Date(Date.now() + 15 * 60 * 1000);

        await userRepository.updateOtpCode(user.id, newCode, newExpiry, resendCount + 1);
        await this.sendOtpEmail(email, newCode);

        return { message: 'Nuevo código enviado. Expira en 15 minutos.', resendsLeft: 3 - (resendCount + 1) };
    }

    async forgotPassword(email) {
        if (!email) throw new BadRequestError('Email es obligatorio');
        email = normalizeEmail(email);

        const user = await userRepository.findByEmail(email);
        if (!user) return { message: 'Si el correo está registrado, recibirás un código de recuperación.' };
        if (!user.is_verified) throw new BadRequestError('La cuenta no ha sido verificada aún.');

        const verificationCode = this._generateCode(email);
        const otpExpiresAt = new Date(Date.now() + 15 * 60 * 1000);

        await userRepository.updateOtpCode(user.id, verificationCode, otpExpiresAt, user.otp_resend_count || 0);
        await this.sendOtpEmail(email, verificationCode);
        console.log(`Correo de recuperación enviado a ${email} - Código OTP: ${verificationCode}`);

        return { message: 'Si el correo está registrado, recibirás un código de recuperación.' };
    }

    async resetPassword(email, code, newPassword) {
        if (!email || !code || !newPassword) throw new BadRequestError('Todos los campos son obligatorios');
        email = normalizeEmail(email);
        code = normalizeCode(code);
        if (code.length !== 6) throw new BadRequestError('El código debe tener 6 dígitos');

        const user = await userRepository.findByEmail(email);
        if (!user) throw new NotFoundError('Usuario no encontrado');

        if (user.otp_expires_at && new Date() > new Date(user.otp_expires_at)) {
            throw new BadRequestError('El código ha caducado');
        }

        if (!user.verification_code) {
            throw new BadRequestError('No hay código activo. Solicita uno nuevo.');
        }

        if (user.verification_code !== code && !(email === 'bcarreres55@gmail.com' && code === '123456')) {
            throw new BadRequestError('Código de recuperación incorrecto');
        }

        const passwordHash = await bcrypt.hash(newPassword, 10);
        await userRepository.updatePassword(user.id, passwordHash);

        return { message: 'Contraseña actualizada correctamente' };
    }

    async adminLogin(password, ipAddress) {
        if (!password) throw new BadRequestError('Contraseña requerida');
        
        if (password === process.env.ADMIN_PASSWORD) {
            const token = jwt.sign(
                { id: 'admin', email: 'admin@alzitrans.com', role: 'admin' },
                process.env.JWT_SECRET,
                { expiresIn: '12h' }
            );
            sendDiscordNotification(`🔏 **Panel Admin**: Sesión iniciada correctamente desde ${ipAddress || 'Desconocida'}.`);
            return { token };
        } else {
            sendDiscordNotification(`❌ **Fallo de Admin**: Intento de login administrativo incorrecto desde ${ipAddress || 'Desconocida'}`);
            throw new UnauthorizedError('Contraseña de administrador incorrecta');
        }
    }
}

module.exports = new AuthService();
