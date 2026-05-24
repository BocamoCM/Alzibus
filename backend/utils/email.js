const nodemailer = require('nodemailer');
require('dotenv').config();

// ─────────────────────────────────────────────────────────────────────────
// TRANSPORTER SINGLETON
// ─────────────────────────────────────────────────────────────────────────
// Antes se creaba un nodemailer.createTransport() en CADA envío (login,
// registro, etc) — handshake TCP+TLS+AUTH a Brevo por cada llamada. Eso:
//   1. era lento (sumaba 200-500 ms a cada login),
//   2. saturaba conexiones simultáneas si llegaban varios logins a la vez,
//   3. multiplicaba errores transitorios.
// Con `pool: true` y `maxConnections` reusamos conexiones SMTP.
//
// IMPORTANTE: si EMAIL_HOST/USER/PASS no están definidos, NO hacemos un
// fallback silencioso a 'localhost'. Loggeamos un warning grande para que
// cualquier admin que mire los logs detecte la mala config — la causa #1
// histórica de "no me llega el código" era precisamente esto.
const emailHost = process.env.EMAIL_HOST || 'smtp-relay.brevo.com';
const emailUser = process.env.EMAIL_USER;
const emailPass = process.env.EMAIL_PASS;

if (!emailUser || !emailPass) {
    console.error('========================================================');
    console.error('[Email] ⚠️  EMAIL_USER o EMAIL_PASS no configurados en .env');
    console.error('[Email]    Los OTPs NO se enviarán hasta que se arregle.');
    console.error('========================================================');
}

const transporter = nodemailer.createTransport({
    host: emailHost,
    port: parseInt(process.env.EMAIL_PORT) || 587,
    secure: false, // false para STARTTLS
    auth: emailUser && emailPass ? { user: emailUser, pass: emailPass } : undefined,
    tls: { rejectUnauthorized: false },
    // Pool de conexiones — reusa sockets SMTP entre envíos.
    pool: true,
    maxConnections: 3,
    maxMessages: 100,
    // Timeouts agresivos: si Brevo cuelga, fallamos rápido en vez de
    // dejar la promesa pendiente para siempre.
    connectionTimeout: 10_000,
    greetingTimeout: 10_000,
    socketTimeout: 15_000,
});

// Verificación de conectividad al arrancar — útil para detectar al
// instante credenciales malas o firewall bloqueando el puerto 587.
// No bloqueamos el arranque del proceso si falla; solo logueamos.
transporter.verify()
    .then(() => console.log(`[Email] ✅ SMTP listo (${emailHost})`))
    .catch(err => console.error(`[Email] ❌ SMTP no responde (${emailHost}):`, err.message));

// FROM: por defecto usamos noreply@alzitrans.es porque es el dominio
// validado en Brevo con SPF/DKIM/DMARC. Si pones bcarreres55@gmail.com
// como FROM, Brevo firma con su propio dominio pero Gmail/Outlook/iCloud
// detectan el From: como spoofing y tiran el correo a spam *silenciosamente*.
// El admin real puede sobreescribirlo vía EMAIL_FROM en .env.
const defaultFrom = process.env.EMAIL_FROM || '"Alzitrans" <noreply@alzitrans.es>';

// ─────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────

function sleep(ms) {
    return new Promise(r => setTimeout(r, ms));
}

/**
 * Envía un email con reintentos automáticos en errores transitorios
 * (timeout, ECONNRESET, 4xx de Brevo). En el último fallo lanza un Error
 * para que el caller pueda devolver 500 al cliente — al contrario que
 * antes, que se tragaba el error y dejaba al usuario esperando un código
 * que nunca llegaba.
 *
 * @throws Error si todos los reintentos fallan
 */
async function sendEmail({ to, subject, text, html }) {
    if (!emailUser || !emailPass) {
        throw new Error('SMTP no configurado (faltan EMAIL_USER / EMAIL_PASS)');
    }

    const mailOptions = { from: defaultFrom, to, subject, text, html };
    const MAX_ATTEMPTS = 3;
    let lastErr;

    for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
        try {
            const info = await transporter.sendMail(mailOptions);
            console.log(`[Email] ✅ Enviado a ${to} (intento ${attempt}/${MAX_ATTEMPTS}): ${info.messageId}`);
            return { success: true, messageId: info.messageId };
        } catch (error) {
            lastErr = error;
            console.error(`[Email] ❌ Intento ${attempt}/${MAX_ATTEMPTS} fallido para ${to}: ${error.message}`);
            // Backoff exponencial: 500ms → 1500ms → (no hay 4º)
            if (attempt < MAX_ATTEMPTS) {
                await sleep(500 * Math.pow(3, attempt - 1));
            }
        }
    }

    // Re-lanzamos para que el caller (auth.service) propague el error al
    // controller, que devolverá 500 al cliente. Antes esto se tragaba.
    throw new Error(`Email a ${to} fallido tras ${MAX_ATTEMPTS} intentos: ${lastErr?.message}`);
}

/**
 * Envío específico de OTP. Mantiene el formato simple text (algunos
 * clientes de email tipo Gmail webmail recortan el HTML y ocultan el
 * código). Vamos a HTML+text para máxima compatibilidad.
 *
 * @throws Error si el envío falla tras los reintentos
 */
async function sendOtpEmail(to, code) {
    const subject = 'Tu código de verificación de Alzitrans';
    const text = `Tu código de verificación es: ${code}\n\nEste código caduca en 15 minutos.\n\nSi no fuiste tú quien lo solicitó, ignora este correo.`;
    const html = `
        <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; max-width: 480px; margin: 0 auto; padding: 24px; color: #333;">
            <div style="text-align: center; margin-bottom: 24px;">
                <h2 style="color: #4A1D3D; margin: 0;">🚌 Alzitrans</h2>
            </div>
            <p style="font-size: 16px; line-height: 1.5;">Tu código de verificación es:</p>
            <div style="background: #F4F1F8; border: 2px dashed #4A1D3D; border-radius: 12px; padding: 20px; text-align: center; margin: 16px 0;">
                <span style="font-family: 'Courier New', monospace; font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #4A1D3D;">${code}</span>
            </div>
            <p style="font-size: 14px; color: #666;">Este código caduca en 15 minutos.</p>
            <hr style="border: 0; border-top: 1px solid #eee; margin: 24px 0;">
            <p style="font-size: 12px; color: #999;">Si no fuiste tú quien lo solicitó, puedes ignorar este correo. Nunca compartas este código con nadie.</p>
        </div>
    `;
    return sendEmail({ to, subject, text, html });
}

/**
 * Notificación específica para el formulario de contacto
 */
async function sendContactNotification(data) {
    const { name, email, subject, message } = data;
    const adminEmail = process.env.CONTACT_NOTIFY_EMAIL || 'bcarreres55@gmail.com';

    const htmlContent = `
        <div style="font-family: sans-serif; padding: 20px; border: 1px solid #eee; border-radius: 10px; color: #333;">
            <h2 style="color: #4A1D3D;">📩 Nuevo mensaje desde la Web</h2>
            <p><strong>De:</strong> ${name} (<a href="mailto:${email}">${email}</a>)</p>
            <p><strong>Asunto:</strong> ${subject || 'Sin asunto'}</p>
            <hr style="border: 0; border-top: 1px solid #eee; margin: 20px 0;">
            <p><strong>Mensaje:</strong></p>
            <div style="background: #f9f9f9; padding: 15px; border-radius: 5px; white-space: pre-wrap;">${message}</div>
            <br>
            <p style="font-size: 12px; color: #999;">Este es un mensaje automático del sistema Alzitrans.</p>
        </div>
    `;

    return sendEmail({
        to: adminEmail,
        subject: `🌐 Contacto Web: ${subject || 'Nuevo mensaje'}`,
        text: `Nuevo mensaje de ${name} (${email}):\n\n${message}`,
        html: htmlContent
    });
}

module.exports = {
    sendEmail,
    sendOtpEmail,
    sendContactNotification,
};
