const nodemailer = require('nodemailer');
require('dotenv').config();

// Configuración del transportador SMTP (Brevo)
const transporter = nodemailer.createTransport({
    host: process.env.EMAIL_HOST || 'smtp-relay.brevo.com',
    port: parseInt(process.env.EMAIL_PORT) || 587,
    secure: false, // false para STARTTLS
    auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASS
    },
    tls: {
        rejectUnauthorized: false // Mayor compatibilidad
    }
});

/**
 * Función genérica para enviar emails
 */
async function sendEmail({ to, subject, text, html }) {
    const mailOptions = {
        from: process.env.EMAIL_FROM || '"Alzitrans Admin" <bcarreres55@gmail.com>',
        to,
        subject,
        text,
        html
    };

    try {
        const info = await transporter.sendMail(mailOptions);
        console.log(`[Email] Enviado correctamente a ${to}: ${info.messageId}`);
        return { success: true, messageId: info.messageId };
    } catch (error) {
        console.error(`[Email] Error enviando a ${to}:`, error.message);
        return { success: false, error: error.message };
    }
}

/**
 * Notificación específica para el formulario de contacto
 */
async function sendContactNotification(data) {
    const { name, email, subject, message } = data;
    const adminEmail = 'bcarreres55@gmail.com';

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
    sendContactNotification
};
