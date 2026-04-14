-- ==========================================
-- init.sql — Esquema inicial de la base de datos Alzibus
-- ==========================================
-- Este archivo se ejecuta AUTOMÁTICAMENTE la primera vez que se crea
-- el contenedor de PostgreSQL (vía docker-compose.yml, montado en
-- /docker-entrypoint-initdb.d/init.sql).
--
-- Contiene:
--   1. Creación de tablas (CREATE TABLE IF NOT EXISTS)
--   2. Migraciones incrementales (ALTER TABLE ADD COLUMN IF NOT EXISTS)
--   3. Índices para optimizar consultas frecuentes
--
-- Las migraciones con ALTER TABLE son idempotentes: si la columna ya
-- existe, PostgreSQL ignora la sentencia sin dar error. Esto permite
-- que el archivo se ejecute múltiples veces sin problemas.

-- ─── TABLA: users ───
-- Almacena la información de los usuarios registrados en la app.
-- Campos principales:
--   - email: identificador único del usuario (se usa para login).
--   - password_hash: contraseña encriptada con bcrypt (nunca texto plano).
--   - active: si está desactivado, no puede iniciar sesión (controlado por admin).
--   - is_verified: TRUE cuando el usuario confirma su email con el código OTP.
--   - verification_code: código de 6 dígitos para verificar email.
--   - otp_*: campos de seguridad para limitar intentos y reenvíos de OTP.
--   - is_premium: TRUE si el usuario ha pagado la suscripción Premium.
--   - last_access: última vez que se llamó al endpoint /heartbeat (indica actividad).
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    active BOOLEAN DEFAULT TRUE,
    last_access TIMESTAMPTZ,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Migraciones incrementales para la tabla users.
-- Se añaden columnas nuevas que no existían en la versión original del esquema.
-- ADD COLUMN IF NOT EXISTS evita errores si ya se aplicó la migración.
ALTER TABLE users ADD COLUMN IF NOT EXISTS active BOOLEAN DEFAULT TRUE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_access TIMESTAMPTZ;
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS verification_code VARCHAR(10);
ALTER TABLE users ADD COLUMN IF NOT EXISTS otp_expires_at TIMESTAMPTZ;       -- Cuándo expira el código OTP actual
ALTER TABLE users ADD COLUMN IF NOT EXISTS otp_attempts INTEGER DEFAULT 0;    -- Intentos fallidos de verificación
ALTER TABLE users ADD COLUMN IF NOT EXISTS otp_resend_count INTEGER DEFAULT 0; -- Veces que se ha reenviado el OTP
ALTER TABLE users ADD COLUMN IF NOT EXISTS otp_penalty_until TIMESTAMPTZ;     -- Penalización temporal tras muchos reenvíos
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_premium BOOLEAN DEFAULT FALSE;  -- Estado de suscripción Premium

-- ─── TABLA: stops ───
-- Paradas de autobús de las líneas de Alzira.
-- Cada parada tiene coordenadas GPS y un array JSONB con las líneas que pasan por ella.
-- Ejemplo de 'lines': ["L1", "L2"] → esta parada pertenece a las líneas L1 y L2.
CREATE TABLE IF NOT EXISTS stops (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    lat DOUBLE PRECISION NOT NULL,
    lng DOUBLE PRECISION NOT NULL,
    lines JSONB DEFAULT '[]'::jsonb
);

-- ─── TABLA: api_logs ───
-- Registro de cada petición HTTP que recibe el servidor.
-- Se usa para calcular estadísticas: endpoints más usados, horas pico,
-- tiempo medio de respuesta, uso semanal, etc.
-- El campo duration_ms se calcula en el middleware de logging de server.js.
CREATE TABLE IF NOT EXISTS api_logs (
    id SERIAL PRIMARY KEY,
    endpoint VARCHAR(500),
    method VARCHAR(10),
    duration_ms INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ─── TABLA: trips ───
-- Historial de viajes de los usuarios.
-- Cada vez que un usuario confirma que ha cogido un bus, se guarda un registro.
-- ON DELETE CASCADE: si se elimina un usuario, se borran automáticamente sus viajes.
-- 'confirmed' distingue viajes confirmados manualmente vs detectados por proximidad.
CREATE TABLE IF NOT EXISTS trips (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    line VARCHAR(20) NOT NULL,         -- Línea de autobús (ej: "L1")
    destination VARCHAR(255) NOT NULL, -- Destino del viaje (ej: "Hospital")
    stop_name VARCHAR(255) NOT NULL,   -- Nombre de la parada de subida
    stop_id INTEGER NOT NULL,          -- ID de la parada en la tabla stops
    timestamp TIMESTAMPTZ NOT NULL,    -- Momento exacto del viaje
    confirmed BOOLEAN DEFAULT FALSE,   -- Si el usuario lo confirmó manualmente
    payment_method VARCHAR(20),        -- Método de pago (ej: "card", "cash")
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP -- Cuándo se guardó el registro
);

-- Migraciones para la tabla trips:
ALTER TABLE trips ADD COLUMN IF NOT EXISTS payment_method VARCHAR(20);

-- Índices para optimizar consultas frecuentes sobre viajes:
-- idx_trips_user_id: acelera la búsqueda de viajes por usuario (WHERE user_id = X)
-- idx_trips_timestamp: acelera la ordenación por fecha (ORDER BY timestamp DESC)
CREATE INDEX IF NOT EXISTS idx_trips_user_id ON trips(user_id);
CREATE INDEX IF NOT EXISTS idx_trips_timestamp ON trips(timestamp DESC);

-- ─── TABLA: notices ───
-- Avisos e incidencias del servicio de autobuses.
-- Los administradores crean avisos desde el panel web y la app los muestra.
-- Un aviso puede estar asociado a una línea específica o ser general (line = NULL).
-- 'expires_at' permite que un aviso se desactive automáticamente pasada una fecha.
CREATE TABLE IF NOT EXISTS notices (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,       -- Título del aviso (ej: "Retraso Línea L2")
    body TEXT NOT NULL,                -- Descripción detallada del aviso
    line VARCHAR(20),                  -- Línea afectada (NULL = todas las líneas)
    active BOOLEAN DEFAULT TRUE,       -- Si el aviso está visible para los usuarios
    expires_at TIMESTAMPTZ,            -- Fecha de expiración automática (opcional)
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP -- Cuándo se creó el aviso
);

-- Índices para optimizar la consulta de avisos activos y no expirados:
-- La app hace esta consulta cada vez que se abre la pantalla de avisos.
CREATE INDEX IF NOT EXISTS idx_notices_active ON notices(active);
-- ─── TABLA: qr_scans ───
-- Registro de cada vez que se escanea el QR físico de las paradas.
-- Permite telemetría detallada independiente de Discord.
CREATE TABLE IF NOT EXISTS qr_scans (
    id SERIAL PRIMARY KEY,
    ip VARCHAR(45),                    -- IP del usuario (soporta IPv6)
    user_agent TEXT,                   -- User-Agent completo del navegador
    device VARCHAR(100),               -- Dispositivo detectado (ej: "iPhone", "Android")
    source VARCHAR(100) DEFAULT 'qr_paradas', -- Origen del escaneo (por si hay varios QR)
    stop_id INTEGER,                   -- ID de la parada de la tabla stops
    stop_name VARCHAR(255),            -- Nombre de la parada escaneada
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Índice para búsquedas rápidas por fecha
CREATE INDEX IF NOT EXISTS idx_qr_scans_created ON qr_scans(created_at DESC);

-- ─── MIGRACIONES: Avisos personales y respuestas ───
-- Permite dirigir un aviso a un usuario concreto (NULL = general para todos).
ALTER TABLE notices ADD COLUMN IF NOT EXISTS target_email VARCHAR(255);
CREATE INDEX IF NOT EXISTS idx_notices_target_email ON notices(target_email);

-- ─── TABLA: notice_replies ───
-- Almacena las respuestas que los usuarios envían a los avisos personales.
-- Solo los avisos con target_email pueden recibir respuestas.
CREATE TABLE IF NOT EXISTS notice_replies (
    id SERIAL PRIMARY KEY,
    notice_id INTEGER NOT NULL REFERENCES notices(id) ON DELETE CASCADE,
    user_email VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_replies_notice ON notice_replies(notice_id);
