// ──────────────────────────────────────────────────────────────────────────
// feedbackUploads.js — configuración segura de subida de adjuntos de tickets
// ──────────────────────────────────────────────────────────────────────────
// Reglas de seguridad (defensa en profundidad):
//
//   1. Whitelist de MIME types. Nada de SVG (puede llevar JS), nada de zips,
//      nada de ejecutables.
//   2. Tamaño máximo 5 MB por archivo, hasta 3 archivos por mensaje.
//   3. Validación por *magic bytes* (no solo por la extensión / Content-Type
//      del cliente, que son trivialmente falsificables).
//   4. El nombre del archivo en disco es un UUID — el original solo se
//      conserva en BD para mostrarlo en la UI.
//   5. La carpeta de uploads vive fuera de la raíz HTTP. Los archivos se
//      sirven por el endpoint /api/feedback/attachments/:id, que verifica
//      permisos y envía cabeceras anti-XSS (Content-Disposition: attachment
//      + X-Content-Type-Options: nosniff).
// ──────────────────────────────────────────────────────────────────────────

const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const multer = require('multer');

const UPLOADS_ROOT = process.env.UPLOADS_DIR
    ? path.resolve(process.env.UPLOADS_DIR)
    : path.resolve(__dirname, '..', '..', 'uploads');

const FEEDBACK_DIR = path.join(UPLOADS_ROOT, 'feedback');

// Crear el directorio raíz al cargar el módulo (idempotente).
try {
    fs.mkdirSync(FEEDBACK_DIR, { recursive: true });
} catch (err) {
    console.error('[feedbackUploads] No se pudo crear el directorio de uploads:', err);
}

// MIME types aceptados. Cada uno se valida luego por magic bytes en
// validateMagicBytes() — el Content-Type del cliente no es suficiente.
const ALLOWED_MIME_TYPES = new Set([
    'image/png',
    'image/jpeg',
    'image/webp',
    'application/pdf',
]);

const MIME_TO_EXT = {
    'image/png':       '.png',
    'image/jpeg':      '.jpg',
    'image/webp':      '.webp',
    'application/pdf': '.pdf',
};

const MAX_FILE_SIZE = 5 * 1024 * 1024; // 5 MB
const MAX_FILES_PER_REQUEST = 3;

// Magic bytes — los primeros bytes del archivo identifican el formato real.
// Si no coinciden, descartamos el archivo aunque el Content-Type diga otra cosa.
function detectMimeFromBuffer(buf) {
    if (!buf || buf.length < 12) return null;

    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4E && buf[3] === 0x47 &&
        buf[4] === 0x0D && buf[5] === 0x0A && buf[6] === 0x1A && buf[7] === 0x0A) {
        return 'image/png';
    }
    // JPEG: FF D8 FF
    if (buf[0] === 0xFF && buf[1] === 0xD8 && buf[2] === 0xFF) {
        return 'image/jpeg';
    }
    // WebP: "RIFF" .... "WEBP"
    if (buf[0] === 0x52 && buf[1] === 0x49 && buf[2] === 0x46 && buf[3] === 0x46 &&
        buf[8] === 0x57 && buf[9] === 0x45 && buf[10] === 0x42 && buf[11] === 0x50) {
        return 'image/webp';
    }
    // PDF: "%PDF"
    if (buf[0] === 0x25 && buf[1] === 0x50 && buf[2] === 0x44 && buf[3] === 0x46) {
        return 'application/pdf';
    }
    return null;
}

// Filtro de multer — corre ANTES de guardar a disco. Aceptamos:
//   - Cualquier MIME de la whitelist (cliente lo declara correctamente).
//   - "application/octet-stream" (cliente no especifica Content-Type; algunos
//     clientes HTTP — Dart/dio sin contentType, navegadores antiguos — lo
//     envían por defecto). En ese caso confiamos en la validación posterior
//     por magic bytes, que es la fuente real de verdad.
// Defense in depth: aunque pasemos octet-stream aquí, persistAttachment lee
// los primeros bytes del archivo y rechaza si no es PNG/JPEG/WebP/PDF.
function fileFilter(req, file, cb) {
    if (ALLOWED_MIME_TYPES.has(file.mimetype) || file.mimetype === 'application/octet-stream') {
        return cb(null, true);
    }
    cb(new Error(`Tipo no permitido: ${file.mimetype}`));
}

// Usamos memoryStorage para poder validar magic bytes ANTES de tocar el
// disco. Para 5 MB × 3 archivos × pocos uploads simultáneos no es problema
// de memoria, y nos ahorra escribir archivos que luego habría que borrar.
const upload = multer({
    storage: multer.memoryStorage(),
    limits: {
        fileSize: MAX_FILE_SIZE,
        files: MAX_FILES_PER_REQUEST,
    },
    fileFilter,
});

// Persiste un archivo recibido por multer en disco bajo /<ticketId>/<uuid>.<ext>
// Devuelve los metadatos necesarios para guardar en BD.
async function persistAttachment(ticketId, multerFile) {
    const detectedMime = detectMimeFromBuffer(multerFile.buffer);
    if (!detectedMime || !ALLOWED_MIME_TYPES.has(detectedMime)) {
        const e = new Error('El contenido del archivo no coincide con un tipo permitido');
        e.statusCode = 400;
        throw e;
    }
    // Si el cliente declaró un tipo concreto (no octet-stream) tiene que
    // coincidir con el detectado por magic bytes — un PDF haciéndose pasar
    // por imagen sería sospechoso. Si el cliente envió octet-stream
    // (cliente HTTP que no rellena Content-Type), confiamos en magic bytes.
    if (multerFile.mimetype !== 'application/octet-stream' &&
        detectedMime !== multerFile.mimetype) {
        const e = new Error('El tipo declarado no coincide con el contenido del archivo');
        e.statusCode = 400;
        throw e;
    }

    const ext = MIME_TO_EXT[detectedMime];
    const storedName = `${crypto.randomUUID()}${ext}`;
    const targetDir = path.join(FEEDBACK_DIR, String(ticketId));
    await fs.promises.mkdir(targetDir, { recursive: true });
    const targetPath = path.join(targetDir, storedName);
    await fs.promises.writeFile(targetPath, multerFile.buffer);

    return {
        originalName: multerFile.originalname,
        storedName,
        mimeType: detectedMime,
        sizeBytes: multerFile.size,
    };
}

// Resuelve la ruta física de un adjunto a partir de los metadatos en BD.
// Defensa contra path traversal: stored_name siempre es UUID + extensión
// fija, y ticketId es un número entero — los volvemos a serializar.
function resolveAttachmentPath(attachmentRow) {
    const ticketId = parseInt(attachmentRow.ticket_id, 10);
    if (!Number.isFinite(ticketId)) throw new Error('Invalid ticket_id');
    const safeStored = path.basename(attachmentRow.stored_name);
    return path.join(FEEDBACK_DIR, String(ticketId), safeStored);
}

module.exports = {
    upload,
    persistAttachment,
    resolveAttachmentPath,
    MAX_FILES_PER_REQUEST,
    MAX_FILE_SIZE,
};
