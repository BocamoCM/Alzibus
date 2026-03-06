# Respuesta a la Rúbrica — Base de Datos y APIs del Backend Alzibus

---

## 1. Justificación del motor de base de datos

### Motor elegido: **PostgreSQL 15**

Se eligió **PostgreSQL** como sistema gestor de base de datos relacional (SGBDR) por las siguientes razones técnicas:

#### Adecuación al caso de uso
Alzibus es una aplicación de transporte público que gestiona **usuarios, viajes, paradas y avisos**. Estos datos tienen relaciones claras entre sí (un usuario tiene muchos viajes, un viaje pertenece a una parada, etc.), lo que hace ideal un modelo **relacional** frente a NoSQL.

#### Ventajas técnicas de PostgreSQL

| Ventaja | Aplicación en Alzibus |
|---|---|
| **Soporte JSONB nativo** | El campo `lines` de la tabla `stops` almacena un array JSON (`["L1", "L2"]`) como JSONB, combinando lo mejor del modelo relacional con la flexibilidad de datos semi-estructurados. |
| **TIMESTAMPTZ** | Gestión correcta de zonas horarias para `last_access`, `otp_expires_at` y `timestamp` de viajes. Fundamental para una app usada en España (UTC+1/UTC+2). |
| **Consultas avanzadas** | Se usan funciones de agregación complejas (`jsonb_array_elements_text`, `DATE_TRUNC`, `EXTRACT`) para las estadísticas del dashboard admin. |
| **Integridad referencial** | `trips.user_id REFERENCES users(id) ON DELETE CASCADE` garantiza que al eliminar un usuario se borren automáticamente sus viajes (cumplimiento RGPD). |
| **Rendimiento con índices** | Índices explícitos sobre `trips(user_id)`, `trips(timestamp DESC)`, `notices(active)` y `notices(expires_at)` para las consultas más frecuentes. |
| **ALTER TABLE IF NOT EXISTS** | Permite migraciones idempotentes: el mismo script se puede ejecutar múltiples veces sin error. |
| **Open Source y gratuito** | Sin coste de licencias, ideal para un proyecto desplegado en una Raspberry Pi con recursos limitados. |
| **Escalabilidad** | Si el proyecto crece, PostgreSQL soporta replicación, particionamiento de tablas y extensiones como PostGIS (útil para geolocalización de paradas). |

#### Limitaciones conocidas y cómo se mitigan

| Limitación | Mitigación |
|---|---|
| Mayor consumo de RAM que SQLite | Se usa **Docker con PostgreSQL 15-slim** para minimizar el footprint. Adecuado para la Raspberry Pi. |
| Configuración más compleja que SQLite/MySQL | Se automatiza completamente con `docker-compose.yml` + `init.sql`: un solo comando (`docker compose up -d`) levanta la DB lista para usar. |
| No tiene motor de búsqueda full-text tan avanzado como Elasticsearch | No es necesario para este caso de uso: las búsquedas son por ID o por campos indexados. |

#### ¿Por qué no otras alternativas?
- **MySQL**: No tiene soporte nativo de JSONB, tipos TIMESTAMPTZ ni `ADD COLUMN IF NOT EXISTS` (más difícil hacer migraciones idempotentes).
- **SQLite**: No soporta conexiones concurrentes ni es ideal para un servidor con múltiples usuarios simultáneos.
- **MongoDB**: El modelo de datos de Alzibus es claramente relacional (usuarios → viajes → paradas). Un modelo de documentos añadiría complejidad innecesaria y perdería la integridad referencial con `FOREIGN KEY`.
- **Firebase/Firestore**: Vendor lock-in (dependencia de Google) y costes operativos. Alzibus se despliega en infraestructura propia (Raspberry Pi).

---

## 2. Diseño y estructura de la base de datos

### Modelo Entidad-Relación

```
┌─────────────┐       1:N        ┌─────────────┐
│   users      │──────────────────│   trips      │
│─────────────│                  │─────────────│
│ id (PK)      │                  │ id (PK)      │
│ email (UQ)   │                  │ user_id (FK) │───→ users.id (CASCADE)
│ password_hash│                  │ line         │
│ active       │                  │ destination  │
│ is_verified  │                  │ stop_name    │
│ is_premium   │                  │ stop_id      │
│ last_access  │                  │ timestamp    │
│ verif. code  │                  │ confirmed    │
│ otp_*        │                  │ created_at   │
│ created_at   │                  └─────────────┘
└─────────────┘

┌─────────────┐                  ┌─────────────┐
│   stops      │                  │   notices    │
│─────────────│                  │─────────────│
│ id (PK)      │                  │ id (PK)      │
│ name         │                  │ title        │
│ lat          │                  │ body         │
│ lng          │                  │ line         │
│ lines (JSONB)│                  │ active       │
└─────────────┘                  │ expires_at   │
                                 │ created_at   │
┌─────────────┐                  └─────────────┘
│   api_logs   │
│─────────────│
│ id (PK)      │
│ endpoint     │
│ method       │
│ duration_ms  │
│ created_at   │
└─────────────┘
```

### Tablas del esquema

| Tabla | Propósito | Registros típicos | Relaciones |
|---|---|---|---|
| `users` | Usuarios registrados en la app | ~100-500 | 1:N con `trips` |
| `trips` | Historial de viajes confirmados | ~1.000-10.000 | N:1 con `users` (FK con CASCADE) |
| `stops` | Paradas de autobús geolocalizadas | ~60-80 (fijas) | Independiente (referenciada por `stop_id` en trips) |
| `notices` | Avisos e incidencias del servicio | ~10-50 | Independiente |
| `api_logs` | Registro de peticiones HTTP a la API | ~10.000+ | Independiente (solo para analíticas) |

### Normalización

El esquema sigue la **Tercera Forma Normal (3FN)**:

- **1FN**: Cada campo contiene valores atómicos. El campo `lines` en `stops` es JSONB (un tipo nativo de PostgreSQL diseñado para almacenar arrays/objetos), no una cadena de texto con separadores.
- **2FN**: Todas las columnas no-clave dependen de la clave primaria completa. No hay dependencias parciales.
- **3FN**: No hay dependencias transitivas. Por ejemplo, `stop_name` en `trips` es una desnormalización intencional para rendimiento (evita un JOIN con `stops` en cada consulta de historial).

### Tipos de datos utilizados con criterio

| Tipo | Uso | Justificación |
|---|---|---|
| `SERIAL` | IDs de todas las tablas | Auto-incremento nativo de PostgreSQL, eficiente para claves primarias. |
| `VARCHAR(255)` | email, nombre de parada | Longitud máxima razonable con validación a nivel de aplicación. |
| `DOUBLE PRECISION` | lat, lng (coordenadas GPS) | Precisión de 15 dígitos, suficiente para coordenadas geográficas. |
| `JSONB` | `stops.lines` | Permite almacenar arrays de líneas (`["L1","L2"]`) con indexación y consultas nativas (`jsonb_array_elements_text`). |
| `TIMESTAMPTZ` | Fechas con zona horaria | Almacena en UTC internamente y convierte automáticamente a la zona del cliente. |
| `BOOLEAN` | active, is_verified, confirmed | Tipo binario eficiente (1 byte) para flags de estado. |
| `TEXT` | body de notices | Sin límite de longitud para descripciones largas de incidencias. |
| `INTEGER` | otp_attempts, duration_ms | Para contadores y métricas numéricas enteras. |

### Índices

```sql
CREATE INDEX IF NOT EXISTS idx_trips_user_id ON trips(user_id);         -- Acelera: SELECT * FROM trips WHERE user_id = X
CREATE INDEX IF NOT EXISTS idx_trips_timestamp ON trips(timestamp DESC); -- Acelera: ORDER BY timestamp DESC (historial)
CREATE INDEX IF NOT EXISTS idx_notices_active ON notices(active);        -- Acelera: WHERE active = TRUE (avisos visibles)
CREATE INDEX IF NOT EXISTS idx_notices_expires ON notices(expires_at);   -- Acelera: WHERE expires_at > NOW()
-- users.email ya tiene índice UNIQUE implícito por la restricción UNIQUE NOT NULL
```

### Migraciones

El esquema evoluciona con migraciones idempotentes:

```sql
-- Ejemplo: añadir soporte OTP sin romper instalaciones existentes
ALTER TABLE users ADD COLUMN IF NOT EXISTS otp_expires_at TIMESTAMPTZ;
ALTER TABLE users ADD COLUMN IF NOT EXISTS otp_attempts INTEGER DEFAULT 0;
```

Además existen scripts dedicados (`db_migrate.js`, `db_migrate_premium.js`) para ejecutar migraciones programáticamente desde Node.js.

---

## 3. Conexión de la aplicación con la BBDD

### Método de conexión: **Connection Pooling con `pg` (node-postgres)**

La conexión se gestiona mediante un **pool de conexiones** implementado en `db.js`:

```javascript
const { Pool } = require('pg');

const pool = new Pool({
    user: process.env.DB_USER,
    host: process.env.DB_HOST,
    database: process.env.DB_NAME,
    password: process.env.DB_PASSWORD,
    port: process.env.DB_PORT,
});
```

#### ¿Qué es un pool y por qué se usa?

Un pool mantiene un conjunto de conexiones TCP abiertas con PostgreSQL. Cuando un endpoint necesita hacer una consulta:

1. **Pide una conexión** al pool (si hay una libre, la reutiliza; si no, crea una nueva hasta el máximo).
2. **Ejecuta la consulta** sobre esa conexión.
3. **Devuelve la conexión** al pool para que otro endpoint la reutilice.

**Sin pool** (conexión directa): cada petición HTTP abriría una conexión TCP nueva → handshake TCP + autenticación PostgreSQL → ~50-100ms de overhead por petición. Con cientos de usuarios, el servidor se saturaría.

**Con pool**: el overhead se reduce a ~0ms porque la conexión ya está abierta.

#### Configuración mediante variables de entorno

Todos los parámetros de conexión se leen del archivo `.env`, nunca están hardcodeados:

```env
DB_USER=alzibus_user
DB_HOST=localhost
DB_NAME=alzibus_db
DB_PASSWORD=alzibus_password
DB_PORT=5433
```

Esto permite cambiar de base de datos (desarrollo → producción) sin modificar ni una línea de código.

#### Gestión de errores de conexión

```javascript
pool.on('error', (err) => {
    console.error('[DATABASE] Error inesperado en el pool:', err);
    sendDiscordNotification(`🫀 **Fallo en la Base de Datos**: \`${err.message}\``);
});
```

Si PostgreSQL se cae o hay un error de red:
1. Se logga el error en consola (visible con `pm2 logs`).
2. Se envía una **alerta automática a Discord** para que el equipo actúe inmediatamente.
3. El pool intenta **reconectar automáticamente** en la siguiente consulta.

#### Consultas parametrizadas (prevención de SQL Injection)

**Todas** las consultas usan parámetros `$1, $2, $3...` en vez de concatenar strings:

```javascript
// ✅ SEGURO: consulta parametrizada
await pool.query('SELECT * FROM users WHERE email = $1', [email]);

// ❌ INSEGURO (nunca se usa): concatenación de strings
// await pool.query(`SELECT * FROM users WHERE email = '${email}'`);
```

PostgreSQL escapa automáticamente los parámetros, haciendo imposible la inyección SQL.

#### Despliegue con Docker

PostgreSQL se ejecuta en un contenedor Docker gestionado por `docker-compose.yml`:

```yaml
services:
  db:
    image: postgres:15
    container_name: alzibus_postgres
    ports:
      - "5433:5432"    # Puerto 5433 para no conflictos con PostgreSQL local
    volumes:
      - pgdata:/var/lib/postgresql/data              # Datos persistentes
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql  # Schema automático
```

El script `start.sh` automatiza todo el proceso: levanta Docker, espera a que la DB responda, instala dependencias y arranca el servidor.

---

## 4. Integración y uso de APIs

### Arquitectura de la API

El backend expone una **API REST** construida con **Express.js v5** que sirve como intermediario entre la app móvil Flutter y la base de datos PostgreSQL.

```
┌──────────────┐     HTTPS/REST      ┌──────────────┐     SQL (pool)     ┌──────────────┐
│  App Flutter  │◄──────────────────►│  Express.js   │◄──────────────────►│  PostgreSQL   │
│  (Cliente)    │     + WebSocket     │  (server.js)  │                    │  (Docker)     │
└──────────────┘                     └──────┬───────┘                    └──────────────┘
                                            │
                                     ┌──────┴───────┐
                                     │ APIs Externas │
                                     │──────────────│
                                     │ • Stripe      │ ← Pagos
                                     │ • SMTP Email  │ ← OTP
                                     │ • Discord     │ ← Alertas
                                     │ • Socket.IO   │ ← Tiempo real
                                     └──────────────┘
```

### Catálogo de endpoints (~30 rutas)

| Grupo | Método | Ruta | Auth | Descripción |
|---|---|---|---|---|
| **Health** | GET | `/api/health` | API Key | Verificar que el servidor está activo |
| **Auth** | POST | `/api/register` | API Key + Rate Limit | Registrar usuario nuevo (bcrypt + OTP) |
| | POST | `/api/verify-email` | API Key | Verificar código OTP de 6 dígitos |
| | POST | `/api/resend-otp` | API Key | Reenviar código de verificación |
| | POST | `/api/login` | API Key + Rate Limit | Iniciar sesión → devuelve JWT |
| | POST | `/api/forgot-password` | API Key | Solicitar reset de contraseña |
| | POST | `/api/reset-password` | API Key | Cambiar contraseña con código OTP |
| **User** | GET | `/api/profile` | JWT | Obtener perfil con estadísticas |
| | PUT | `/api/profile` | JWT | Actualizar email del usuario |
| | PUT | `/api/change-password` | JWT | Cambiar contraseña (requiere la actual) |
| | DELETE | `/api/delete-account` | JWT | Eliminar cuenta y datos (RGPD) |
| | POST | `/api/heartbeat` | JWT | Actualizar `last_access` (usuario activo) |
| **Trips** | GET | `/api/trips` | JWT | Historial de viajes del usuario |
| | POST | `/api/trips` | JWT | Guardar un nuevo viaje |
| | DELETE | `/api/trips/:id` | JWT | Eliminar un viaje |
| | DELETE | `/api/trips` | JWT | Borrar todo el historial |
| **Stops** | GET | `/api/stops` | API Key | Listar todas las paradas (público) |
| | POST | `/api/stops` | Admin JWT | Crear parada |
| | PUT | `/api/stops/:id` | Admin JWT | Actualizar parada |
| | DELETE | `/api/stops/:id` | Admin JWT | Eliminar parada |
| **Notices** | GET | `/api/notices` | API Key | Avisos activos (público) |
| | GET | `/api/admin/notices` | Admin JWT | Todos los avisos (admin) |
| | POST | `/api/admin/notices` | Admin JWT | Crear aviso + WebSocket emit |
| | PATCH | `/api/admin/notices/:id/toggle` | Admin JWT | Activar/desactivar aviso |
| | DELETE | `/api/admin/notices/:id` | Admin JWT | Eliminar aviso |
| **Admin** | POST | `/api/admin/login` | API Key + Rate Limit | Login del panel admin |
| | GET | `/api/admin/users` | Admin JWT | Listar todos los usuarios |
| | PATCH | `/api/admin/users/:id/toggle` | Admin JWT | Activar/desactivar usuario |
| **Stats** | GET | `/api/stats/dashboard` | Admin JWT | Dashboard completo (21 queries) |
| | GET | `/api/stats` | Admin JWT | Estadísticas generales |
| | GET | `/api/stats/usage` | API Key | Uso por día (últimos 7 días) |
| **Payments** | POST | `/api/payments/create-intent` | JWT | Crear PaymentIntent Stripe |
| | POST | `/api/payments/confirm-manual` | JWT | Confirmar pago manualmente |
| | POST | `/api/payments/webhook` | Stripe Signature | Webhook de confirmación Stripe |

### APIs externas integradas

#### 1. **Stripe** (Pagos)
```javascript
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

// Crear intención de pago (la app muestra el Payment Sheet)
const paymentIntent = await stripe.paymentIntents.create({
    amount: 299,        // 2,99€ en céntimos
    currency: 'eur',
    payment_method_types: ['card'],
    metadata: { userId: req.user.id, email: req.user.email }
});
```
- **Flujo**: App → `create-intent` → Stripe SDK → Payment Sheet → Webhook → DB update.
- **Seguridad**: Webhook verificado con firma criptográfica (`stripe.webhooks.constructEvent`).

#### 2. **Socket.IO** (Tiempo real)
```javascript
const io = socketIo(server, { cors: { origin: allowedOrigins } });

// Al crear un aviso, notificar a TODOS los clientes conectados instantáneamente
io.emit('new_notice', result.rows[0]);
```
- La app Flutter mantiene una conexión WebSocket persistente.
- Cuando el admin crea un aviso, aparece un badge de notificación en la app sin pull-to-refresh.

#### 3. **Nodemailer/SMTP** (Emails)
```javascript
const transporter = nodemailer.createTransport({
    host: process.env.EMAIL_HOST,
    port: parseInt(process.env.EMAIL_PORT) || 587,
    auth: { user: process.env.EMAIL_USER, pass: process.env.EMAIL_PASS }
});
```
- Envía códigos OTP de 6 dígitos para verificación de email y recuperación de contraseña.
- Envío no bloqueante: la respuesta HTTP no espera a que el email se envíe.

#### 4. **Discord Webhook** (Alertas al equipo)
```javascript
sendDiscordNotification(`🚀 **Nuevo usuario registrado**: \`${email}\``);
```
- Notifica: nuevos registros, intentos de fuerza bruta, fallos de DB, reportes diarios.
- Implementado con `https` nativo de Node.js (sin dependencias extra).

---

## 5. Seguridad en base de datos y APIs

### Capas de seguridad implementadas

La seguridad del backend se estructura en **7 capas** complementarias:

```
                    ┌─────────────────────────────┐
              ┌─────┤  1. Helmet (HTTP Headers)    │
              │     └─────────────────────────────┘
              │     ┌─────────────────────────────┐
              ├─────┤  2. CORS (Orígenes)          │
              │     └─────────────────────────────┘
              │     ┌─────────────────────────────┐
              ├─────┤  3. API Key (X-API-Key)      │
              │     └─────────────────────────────┘
   Petición   │     ┌─────────────────────────────┐
   ──────────►├─────┤  4. Rate Limiting            │
              │     └─────────────────────────────┘
              │     ┌─────────────────────────────┐
              ├─────┤  5. JWT Auth (Bearer Token)  │
              │     └─────────────────────────────┘
              │     ┌─────────────────────────────┐
              ├─────┤  6. Consultas parametrizadas │
              │     └─────────────────────────────┘
              │     ┌─────────────────────────────┐
              └─────┤  7. Bcrypt (Contraseñas)     │
                    └─────────────────────────────┘
```

### Detalle de cada capa

#### Capa 1: Helmet — Cabeceras HTTP de seguridad
```javascript
app.use(helmet({ crossOriginResourcePolicy: false }));
```
Establece automáticamente:
- `X-Content-Type-Options: nosniff` → Previene MIME sniffing.
- `X-Frame-Options: SAMEORIGIN` → Previene clickjacking.
- `Strict-Transport-Security` → Fuerza HTTPS.
- `X-XSS-Protection` → Protección anti-XSS del navegador.

#### Capa 2: CORS — Control de orígenes
```javascript
app.use(cors({
    origin: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-API-Key'],
    credentials: true
}));
```
Solo permite peticiones con los métodos y headers esperados.

#### Capa 3: API Key — Autenticación de la aplicación
```javascript
const validateApiKey = (req, res, next) => {
    const apiKey = req.headers['x-api-key'];
    if (!apiKey || apiKey !== process.env.API_KEY) {
        sendDiscordNotification(`⚠️ **Petición rechazada**: API Key inválida desde ${req.ip}`);
        return res.status(401).json({ error: 'API Key inválida' });
    }
    next();
};
app.use('/api', validateApiKey);
```
- **Todas** las rutas `/api/*` requieren una API Key en el header.
- Si alguien descubre la URL del servidor, no puede usarla sin la clave.
- Las peticiones rechazadas se notifican a Discord.

#### Capa 4: Rate Limiting — Anti fuerza bruta
```javascript
// Máximo 5 registros/hora por IP
const registerLimiter = rateLimit({ windowMs: 60 * 60 * 1000, max: 5 });

// Máximo 10 logins/15min por IP (con alerta Discord)
const loginLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, max: 10,
    handler: (req, res, next, options) => {
        sendDiscordNotification(`🛡️ **Brute Force bloqueado**: IP ${req.ip}`);
        res.status(429).send(options.message);
    }
});
```
- Límites diferenciados por tipo de endpoint.
- Alertas proactivas cuando se detecta un posible ataque.

#### Capa 5: JWT — Autenticación de usuario
```javascript
const authenticateToken = (req, res, next) => {
    const token = authHeader && authHeader.split(' ')[1];
    jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
        if (err) return res.status(403).json({ error: 'Token inválido o expirado' });
        req.user = user;
        next();
    });
};
```
- Tokens stateless: el servidor no almacena sesiones.
- Expiración configurable (actualmente 7 días para usuarios, 12h para admin).
- Se distinguen roles: `user` vs `admin` en el payload del JWT.

#### Capa 6: Consultas parametrizadas — Anti SQL Injection
```javascript
// TODAS las consultas usan parámetros ($1, $2, $3...)
await pool.query('SELECT * FROM users WHERE email = $1', [email]);
await pool.query('INSERT INTO trips (...) VALUES ($1, $2, $3, $4, $5, $6)', [...]);
await pool.query('DELETE FROM trips WHERE id = $1 AND user_id = $2', [id, userId]);
```
- **Nunca** se concatenan variables directamente en SQL.
- PostgreSQL escapa automáticamente los valores, haciendo imposible la inyección.
- Incluso el endpoint de DELETE verifica `AND user_id = $2` para que un usuario no pueda borrar viajes de otro.

#### Capa 7: Bcrypt — Hashing de contraseñas
```javascript
const saltRounds = 10;
const passwordHash = await bcrypt.hash(password, saltRounds);

// Verificación en login
const passwordValid = await bcrypt.compare(password, user.password_hash);
```
- Las contraseñas **nunca** se almacenan en texto plano.
- Bcrypt usa un salt aleatorio + 10 rondas de hashing.
- Dos usuarios con la misma contraseña tienen hashes **diferentes**.
- Resistente a ataques de rainbow tables y fuerza bruta.

### Seguridad adicional: Sistema OTP

```javascript
// Código de 6 dígitos con expiración
const verificationCode = Math.floor(100000 + Math.random() * 900000).toString();
const otpExpiresAt = new Date(Date.now() + 15 * 60 * 1000); // 15 minutos

// Protecciones anti-abuso:
// - Máximo 3 intentos de verificación por código
// - Máximo 5 reenvíos de código
// - Penalización de 15 minutos tras agotar reenvíos
```

### Seguridad en la base de datos

| Medida | Implementación |
|---|---|
| Credenciales en `.env` | Nunca hardcodeadas en el código |
| Puerto no estándar | PostgreSQL en puerto 5433 (no el 5432 por defecto) |
| Volumen Docker persistente | Los datos sobreviven a reinicios del contenedor |
| `ON DELETE CASCADE` | Eliminación automática de datos huérfanos (RGPD) |
| Monitorización de errores | Alertas a Discord si la DB se cae |
| Migraciones idempotentes | `IF NOT EXISTS` en todos los ALTER TABLE |
| Limpieza automática | Cuentas no verificadas se eliminan tras 5 minutos |

### Cumplimiento RGPD

```javascript
// DELETE /api/delete-account — Eliminación completa de datos
app.delete('/api/delete-account', authenticateToken, async (req, res) => {
    await pool.query('DELETE FROM users WHERE id = $1', [req.user.id]);
    // ON DELETE CASCADE borra automáticamente todos los viajes asociados
});
```
- El usuario puede eliminar su cuenta desde la app.
- Google Play requiere esta funcionalidad (política de datos de usuario 2023).
- La eliminación es irreversible y borra **todos** los datos asociados.

---

*Documento generado para el proyecto Alzibus — Backend Node.js + PostgreSQL*
*Repositorio: github.com/BocamoCM/Alzibus*
