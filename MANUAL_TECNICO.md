# Manual Técnico — Alzitrans v3.0

**Proyecto:** Aplicación de transporte público urbano para Alzira (Valencia)  
**Plataforma:** Android (Flutter) + Backend Node.js + Panel de Administración (Flutter Web)  
**Versión:** 3.0.0+3  
**Última actualización:** Marzo 2026

---

## Índice

1. [Visión General del Proyecto](#1-visión-general-del-proyecto)
2. [Arquitectura del Sistema](#2-arquitectura-del-sistema)
3. [Requisitos del Entorno de Desarrollo](#3-requisitos-del-entorno-de-desarrollo)
4. [Estructura del Repositorio](#4-estructura-del-repositorio)
5. [Backend — Node.js / Express](#5-backend--nodejs--express)
   - 5.1 Dependencias y Configuración
   - 5.2 Base de Datos (PostgreSQL)
   - 5.3 Autenticación y Seguridad
   - 5.4 Catálogo de Endpoints API REST
   - 5.5 WebSockets (Socket.IO)
   - 5.6 Integraciones Externas
   - 5.7 Sistema de Logs y Monitorización
6. [Aplicación Móvil — Flutter](#6-aplicación-móvil--flutter)
   - 6.1 Dependencias Principales
   - 6.2 Punto de Entrada y Secuencia de Inicialización
   - 6.3 Estructura de Carpetas
   - 6.4 Modelos de Datos
   - 6.5 Servicios (Capa de Lógica de Negocio)
   - 6.6 Páginas y Pantallas
   - 6.7 Widgets Personalizados
   - 6.8 Internacionalización (i18n)
   - 6.9 Tema y Diseño Visual
   - 6.10 Accesibilidad (Modo Personas Mayores)
   - 6.11 Servicio en Segundo Plano
7. [Panel de Administración — Flutter Web](#7-panel-de-administración--flutter-web)
8. [Infraestructura y Despliegue](#8-infraestructura-y-despliegue)
   - 8.1 Docker Compose
   - 8.2 Despliegue en Producción (Raspberry Pi)
   - 8.3 Scripts de Arranque y Parada
9. [Configuración de Android](#9-configuración-de-android)
10. [Flujos de Datos Principales](#10-flujos-de-datos-principales)
11. [Integración con API de Renfe](#11-integración-con-api-de-renfe)
12. [Lectura de Tarjetas NFC](#12-lectura-de-tarjetas-nfc)
13. [Variables de Entorno](#13-variables-de-entorno)
14. [Guía de Mantenimiento](#14-guía-de-mantenimiento)
15. [Solución de Problemas Frecuentes](#15-solución-de-problemas-frecuentes)

---

## 1. Visión General del Proyecto

**Alzitrans** es una aplicación de transporte público para la ciudad de Alzira (Valencia), diseñada para facilitar el uso del servicio de autobuses urbanos. El sistema consta de tres componentes:

| Componente | Tecnología | Función |
|---|---|---|
| **App Móvil** | Flutter (Android) | Usuarios finales: mapa interactivo, horarios, NFC, alertas |
| **Backend API** | Node.js + Express + PostgreSQL | Servidor REST, WebSockets, autenticación |
| **Panel Admin** | Flutter Web | Gestión de paradas, rutas, usuarios, avisos, estadísticas |

**Líneas de autobús:** L1, L2 y L3, con un total de 52 paradas distribuidas por Alzira.

**Funcionalidades principales:**
- Mapa interactivo con posición simulada de autobuses en tiempo real
- Lectura de tarjetas NFC de transporte (MIFARE Classic 1K)
- Alertas de proximidad a paradas (con vibración y notificación)
- Horarios de trenes Cercanías Renfe (línea C2 Alzira)
- Historial de viajes con estadísticas
- Avisos de servicio en tiempo real vía WebSockets
- Modo de accesibilidad para personas mayores (texto ampliado, TTS)
- Servicio en segundo plano para alertas incluso con la app minimizada
- Multiidioma: Español, Inglés, Valenciano/Catalán

---

## 2. Arquitectura del Sistema

```
┌─────────────────────────────────────────────────────────┐
│                    USUARIOS FINALES                      │
│                                                          │
│  ┌──────────────┐          ┌───────────────────────┐    │
│  │  App Android  │◄────────►│  Backend (Node.js)    │    │
│  │  (Flutter)    │  REST +  │  Puerto 4000          │    │
│  │              │  Socket.IO│                       │    │
│  └──────┬───────┘          │  ┌─────────────────┐  │    │
│         │                   │  │  PostgreSQL 15  │  │    │
│         │ NFC               │  │  Puerto 5433    │  │    │
│  ┌──────▼───────┐          │  └─────────────────┘  │    │
│  │ Tarjeta Bus  │          │                       │    │
│  │ MIFARE 1K    │          └───────────┬───────────┘    │
│  └──────────────┘                      │                │
│                                        │                │
│  ┌──────────────┐          ┌───────────▼───────────┐    │
│  │ Renfe GTFS-RT│◄─────────│  Panel Admin          │    │
│  │ (API pública)│          │  (Flutter Web)        │    │
│  └──────────────┘          └───────────────────────┘    │
│                                                          │
│           SERVICIOS EXTERNOS                             │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐                │
│  │Nodemailer│ │ Discord  │ │  Sentry  │                │
│  │ (email)  │ │(webhooks)│ │ (errors) │                │
│  └──────────┘ └──────────┘ └──────────┘                │
└─────────────────────────────────────────────────────────┘
```

**Comunicación entre componentes:**

| Origen → Destino | Protocolo | Puerto | Autenticación |
|---|---|---|---|
| App → Backend | HTTP REST | 4000 | API Key + JWT Bearer |
| App → Backend | WebSocket (Socket.IO) | 4000 | Ninguna (público) |
| Admin → Backend | HTTP REST | 4000 | API Key + JWT Admin |
| App → Renfe | HTTP GET | 443 (HTTPS) | Ninguna (API pública) |
| Backend → PostgreSQL | TCP (pg Pool) | 5433 | Usuario/contraseña |
| Backend → Discord | HTTPS Webhook | 443 | URL con token |
| Backend → Email | SMTP | 587 | Credenciales Gmail |

---

## 3. Requisitos del Entorno de Desarrollo

### Software necesario

| Herramienta | Versión mínima | Uso |
|---|---|---|
| **Flutter SDK** | 3.6.0+ | App móvil y panel admin |
| **Dart SDK** | 2.18.0 – 4.0.0 | Incluido con Flutter |
| **Node.js** | 18+ | Backend API |
| **npm** | 9+ | Gestión de paquetes backend |
| **Docker** + **Docker Compose** | 20+ / 2.0+ | Contenedor PostgreSQL |
| **Android Studio** / **VS Code** | Última versión | IDE de desarrollo |
| **Android SDK** | API 36 (compileSdk) | Compilación Android |
| **JDK** | 17 | Compilación Android (Gradle) |
| **Git** | 2.0+ | Control de versiones |

### Configuración inicial

```bash
# 1. Clonar el repositorio
git clone https://github.com/BocamoCM/Alzibus.git
cd Alzibus

# 2. Instalar dependencias de Flutter
flutter pub get

# 3. Instalar dependencias del backend
cd backend
npm install
cd ..

# 4. Instalar dependencias del admin panel
cd admin_panel
flutter pub get
cd ..

# 5. Levantar PostgreSQL con Docker
cd backend
docker compose up -d
cd ..
```

### Archivo `.env` del backend

Crear `backend/.env` con las variables necesarias (ver [Sección 13](#13-variables-de-entorno)).

---

## 4. Estructura del Repositorio

```
Alzibus/
├── lib/                          # Código fuente de la app Flutter
│   ├── main.dart                 # Punto de entrada (882 líneas)
│   ├── constants/                # Configuración centralizada
│   │   ├── app_config.dart       # URLs, API keys, timeouts, IDs AdMob
│   │   └── line_colors.dart      # Colores por línea de bus
│   ├── models/                   # Modelos de datos
│   │   ├── bus_stop.dart         # Parada de bus
│   │   ├── bus_card.dart         # Tarjeta NFC
│   │   └── trip_record.dart      # Registro de viaje + estadísticas
│   ├── services/                 # Lógica de negocio (21 servicios)
│   │   ├── auth_service.dart     # Autenticación JWT
│   │   ├── stops_service.dart    # Carga de paradas (API + fallback local)
│   │   ├── renfe_service.dart    # Horarios Renfe C2
│   │   ├── socket_service.dart   # WebSocket (avisos en tiempo real)
│   │   ├── bus_simulation_service.dart  # Motor de simulación de buses
│   │   ├── foreground_service.dart      # Servicio en segundo plano
│   │   ├── nfc_service.dart      # Lectura de tarjetas NFC
│   │   ├── notification_service.dart    # Notificaciones locales
│   │   ├── bus_alert_service.dart       # Alertas de proximidad
│   │   ├── location_service.dart        # Proveedor GPS
│   │   ├── tts_service.dart      # Text-to-speech
│   │   └── ... (10 servicios más)
│   ├── pages/                    # Páginas principales (11 archivos)
│   ├── screens/                  # Pantallas secundarias (5 archivos)
│   ├── widgets/                  # Widgets reutilizables (5 archivos)
│   ├── providers/                # Proveedores de estado
│   │   └── elderly_mode_provider.dart
│   ├── theme/                    # Tema visual
│   │   └── app_theme.dart
│   └── l10n/                     # Traducciones (es, en, ca)
├── assets/                       # Recursos estáticos
│   ├── stops.json                # 52 paradas (fallback local)
│   ├── routes/                   # Rutas GPS de líneas (L1, L2, L3)
│   └── icon/                     # Iconos de la app
├── backend/                      # Servidor Node.js
│   ├── server.js                 # API REST principal (1755 líneas)
│   ├── db.js                     # Pool de conexiones PostgreSQL
│   ├── init.sql                  # Esquema de la base de datos
│   ├── docker-compose.yml        # Infraestructura Docker
│   ├── Dockerfile                # Imagen del servidor (no usado en prod)
│   ├── start.sh / stop.sh        # Scripts de despliegue
│   ├── utils/discord.js          # Webhooks de Discord
│   ├── import_stops.js           # Importación de paradas
│   ├── db_migrate.js             # Migraciones de seguridad OTP
│   ├── check.js                  # Inspección del esquema DB
│   ├── dashboard.html            # Dashboard web del admin
│   └── package.json              # Dependencias Node.js
├── admin_panel/                  # Panel de administración (Flutter Web)
│   ├── lib/
│   │   ├── main.dart             # Punto de entrada admin
│   │   ├── screens/              # 8 pantallas (dashboard, CRUD, stats)
│   │   ├── services/api_service.dart  # Cliente API
│   │   └── theme/admin_theme.dart
│   └── web/                      # Assets web
├── android/                      # Configuración nativa Android
├── ios/                          # Configuración iOS (no desplegada)
├── tools/                        # Herramientas auxiliares (NFC, GPX)
├── pubspec.yaml                  # Dependencias Flutter
├── l10n.yaml                     # Configuración de localización
└── analysis_options.yaml         # Reglas de lint
```

---

## 5. Backend — Node.js / Express

### 5.1 Dependencias y Configuración

El backend está en `backend/` y usa Express 5 como framework web.

**Dependencias principales (`package.json`):**

| Paquete | Versión | Propósito |
|---|---|---|
| `express` | ^5.2.1 | Framework REST |
| `socket.io` | ^4.8.3 | WebSockets en tiempo real |
| `pg` | ^8.18.0 | Cliente PostgreSQL (pool) |
| `bcrypt` | ^6.0.0 | Hash de contraseñas (salt rounds: 10) |
| `jsonwebtoken` | ^9.0.3 | Tokens JWT (expiración: 24h) |
| `nodemailer` | ^8.0.1 | Envío de correos OTP |
| `helmet` | ^8.1.0 | Cabeceras de seguridad HTTP |
| `cors` | ^2.8.6 | Control de origen cruzado |
| `express-rate-limit` | ^8.2.1 | Límite de peticiones |
| `dotenv` | ^17.3.1 | Variables de entorno |
| `marked` | ^17.0.4 | Renderizado Markdown (política privacidad) |

**Scripts:**
- `npm start` → `node server.js` (producción)
- `npm run dev` → `nodemon server.js` (desarrollo con hot-reload)

### 5.2 Base de Datos (PostgreSQL)

**Motor:** PostgreSQL 15 (contenedor Docker)  
**Puerto:** 5433 (mapeado desde el 5432 interno del contenedor)  
**Credenciales por defecto:** `alzibus_user` / `alzibus_password` / `alzibus_db`

#### Esquema de tablas (`init.sql`)

```sql
-- Tipos enumerados
CREATE TYPE user_role AS ENUM ('user', 'admin');

-- 1. USERS — Usuarios registrados
CREATE TABLE users (
    id              SERIAL PRIMARY KEY,
    email           VARCHAR(255) UNIQUE NOT NULL,
    password_hash   VARCHAR(255) NOT NULL,
    role            user_role DEFAULT 'user',
    active          BOOLEAN DEFAULT true,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_access     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_verified     BOOLEAN DEFAULT false,
    verification_code VARCHAR(6),
    otp_expires_at  TIMESTAMP,
    otp_attempts    INTEGER DEFAULT 0,
    otp_resend_count INTEGER DEFAULT 0,
    otp_penalty_until TIMESTAMP,
);

-- 2. STOPS — Paradas de autobús
CREATE TABLE stops (
    id    SERIAL PRIMARY KEY,
    name  VARCHAR(255) NOT NULL,
    lat   DOUBLE PRECISION NOT NULL,
    lng   DOUBLE PRECISION NOT NULL,
    lines JSONB DEFAULT '[]'
);

-- 3. API_LOGS — Registro de peticiones
CREATE TABLE api_logs (
    id          SERIAL PRIMARY KEY,
    endpoint    VARCHAR(255),
    method      VARCHAR(10),
    duration_ms INTEGER,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. TRIPS — Historial de viajes
CREATE TABLE trips (
    id          SERIAL PRIMARY KEY,
    user_id     INTEGER REFERENCES users(id) ON DELETE CASCADE,
    line        VARCHAR(10),
    destination VARCHAR(255),
    stop_name   VARCHAR(255),
    stop_id     INTEGER,
    timestamp   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    confirmed   BOOLEAN DEFAULT false
);

-- 5. NOTICES — Avisos de servicio
CREATE TABLE notices (
    id         SERIAL PRIMARY KEY,
    title      VARCHAR(255) NOT NULL,
    body       TEXT,
    line       VARCHAR(10),
    active     BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP
);
```

**Índices de rendimiento:**

| Índice | Tabla | Columna(s) | Justificación |
|---|---|---|---|
| `idx_trips_user_id` | trips | user_id | Consultas de historial por usuario |
| `idx_trips_timestamp` | trips | timestamp | Ordenación cronológica |
| `idx_notices_active` | notices | active | Filtrado de avisos vigentes |
| `idx_notices_expires` | notices | expires_at | Limpieza de avisos expirados |

**Diagrama Entidad-Relación simplificado:**

```
USERS ──────1:N────── TRIPS
  │                     │
  │ (id)          (user_id FK)
  │
  └── role, email, password_hash, OTP fields...

STOPS (independiente)
  └── id, name, lat, lng, lines (JSONB)

NOTICES (independiente)
  └── id, title, body, line, active, expires_at

API_LOGS (independiente)
  └── endpoint, method, duration_ms, created_at
```

#### Conexión (`db.js`)

```javascript
const pool = new Pool({
    user: process.env.DB_USER,
    host: process.env.DB_HOST,
    database: process.env.DB_NAME,
    password: process.env.DB_PASSWORD,
    port: process.env.DB_PORT,  // 5433
});

pool.on('error', (err) => {
    sendDiscordNotification(`🫀 Fallo en la Base de Datos: ${err.message}`);
});
```

El pool de `pg` gestiona automáticamente la creación/reutilización de conexiones. Todas las consultas usan **parámetros posicionales** (`$1`, `$2`...) para prevenir inyección SQL.

### 5.3 Autenticación y Seguridad

El sistema implementa **7 capas de seguridad:**

#### Capa 1 — Helmet (cabeceras HTTP)
Aplica cabeceras de seguridad estándar (X-Frame-Options, X-Content-Type-Options, etc.) con `crossOriginResourcePolicy: false` para permitir cargas desde la app.

#### Capa 2 — CORS
Orígenes permitidos configurables por variable de entorno (`ALLOWED_ORIGINS`). Permite métodos GET, POST, PUT, DELETE, PATCH, OPTIONS. Acepta credenciales y cabeceras personalizadas.

#### Capa 3 — API Key
Middleware `validateApiKey` valida la cabecera `X-API-Key` en todas las rutas `/api`. Las peticiones sin clave válida se rechazan con 401 y se notifican por Discord.

#### Capa 4 — Rate Limiting
- **General:** 100 peticiones / 15 minutos por IP
- **Login:** 10 intentos / 15 minutos por IP
- **Registro:** 5 intentos / hora por IP
- **OTP:** 3 intentos / 15 minutos por IP

#### Capa 5 — JWT (JSON Web Tokens)
Middleware `authenticateToken`:
1. Extrae token del header `Authorization: Bearer <token>`
2. Verifica firma con `JWT_SECRET`
3. Decodifica payload (`{ id, email }`)
4. Inyecta `req.user` para uso en endpoints
5. Expiración: **24 horas**

#### Capa 6 — Bcrypt (hash de contraseñas)
Todas las contraseñas se almacenan como hash bcrypt con **salt rounds = 10**. Nunca se almacena texto plano.

#### Capa 7 — Protección OTP
El sistema de verificación por código OTP (correo electrónico) incluye:
- Códigos de 6 dígitos aleatorios
- Expiración automática (10 minutos)
- Máximo 3 intentos por código
- Límite de reenvíos con penalización progresiva
- Bloqueo temporal al alcanzar el límite

### 5.4 Catálogo de Endpoints API REST

#### Endpoints Públicos (sin JWT)

| Método | Ruta | Descripción |
|---|---|---|
| `GET` | `/api/health` | Estado del servidor |
| `POST` | `/api/register` | Registro de usuario (email + password) |
| `POST` | `/api/verify-otp` | Verificación de código OTP |
| `POST` | `/api/resend-otp` | Reenvío de código OTP |
| `POST` | `/api/login` | Login (devuelve JWT) |
| `POST` | `/api/forgot-password` | Solicitud de reset de contraseña |
| `POST` | `/api/reset-password` | Resetear contraseña con token |
| `GET` | `/api/stops` | Listado de todas las paradas |
| `GET` | `/api/notices` | Avisos de servicio activos |
| `GET` | `/delete-account` | Página de eliminación de cuenta (GDPR) |
| `GET` | `/privacy-policy` | Política de privacidad |

#### Endpoints Autenticados (requieren JWT)

| Método | Ruta | Descripción |
|---|---|---|
| `POST` | `/api/users/heartbeat` | Latido de actividad (cada 2min) |
| `GET` | `/api/users/profile` | Perfil + estadísticas de viajes |
| `PUT` | `/api/users/profile` | Actualizar email |
| `PUT` | `/api/users/password` | Cambiar contraseña |
| `DELETE` | `/api/users/profile` | Eliminar cuenta (GDPR) |
| `GET` | `/api/trips` | Historial de viajes del usuario |
| `POST` | `/api/trips` | Registrar nuevo viaje |
| `DELETE` | `/api/trips/:id` | Eliminar viaje |

#### Endpoints de Administración

| Método | Ruta | Descripción |
|---|---|---|
| `POST` | `/api/admin/login` | Login de administrador |
| `GET` | `/api/admin/users` | Listado de todos los usuarios |
| `PUT` | `/api/admin/users/:id/toggle-active` | Activar/desactivar usuario |
| `DELETE` | `/api/admin/users/:id` | Eliminar usuario |
| `POST` | `/api/admin/stops` | Crear parada |
| `PUT` | `/api/admin/stops/:id` | Editar parada |
| `DELETE` | `/api/admin/stops/:id` | Eliminar parada |
| `POST` | `/api/admin/notices` | Crear aviso |
| `PUT` | `/api/admin/notices/:id` | Editar aviso |
| `DELETE` | `/api/admin/notices/:id` | Eliminar aviso |
| `GET` | `/api/stats/*` | Múltiples endpoints de estadísticas |

### 5.5 WebSockets (Socket.IO)

Socket.IO se inicializa sobre el mismo servidor HTTP de Express (puerto 4000). Se utiliza para:

1. **Avisos en tiempo real:** Cuando un administrador crea un aviso, el backend emite el evento `new_notice` a todos los clientes conectados.

2. **Alertas de proximidad:** Los clientes pueden emitir su ubicación y recibir alertas cuando un bus se acerca a su parada.

**Configuración del servidor:**
```javascript
const server = http.createServer(app);
const io = socketIo(server, {
    cors: { origin: allowedOrigins, methods: ['GET', 'POST'] }
});
```

**Eventos:**

| Evento | Dirección | Datos |
|---|---|---|
| `new_notice` | Server → Client | `{ title, body, line }` |
| `connection` | Client → Server | Handshake automático |
| `disconnect` | Client → Server | Desconexión automática |

### 5.6 Integraciones Externas

#### Nodemailer (correo electrónico)
- **Uso:** Envío de códigos OTP para verificar cuentas y resetear contraseñas
- **Proveedor SMTP:** Gmail (configurable vía variables de entorno)
- **Transporter:** Con `secure: false` y `requireTLS: true` en puerto 587

#### Discord (webhooks de notificación)
- **Uso:** Alertas operativas para los desarrolladores
- **Eventos notificados:** Registros nuevos, errores de BD, intentos de acceso no autorizado, cuentas eliminadas, informes diarios
- **Implementación:** Módulo nativo `https` de Node.js, sin dependencias externas

#### Sentry (monitorización de errores)
- **Uso:** Captura de errores en la app Flutter
- **Configuración:** DSN inyectado vía `--dart-define=SENTRY_DSN=...`

### 5.7 Sistema de Logs y Monitorización

**Logs de peticiones API:**
Cada petición a `/api` (excepto `/api/stats`) se registra en la tabla `api_logs` con:
- Endpoint solicitado
- Método HTTP
- Duración en milisegundos
- Timestamp

**Log de consola:**
Middleware de debug imprime en consola: `[DEBUG] MÉTODO /ruta - IP_Cliente`

**Cron de limpieza:**
Tarea programada diaria que elimina registros de `api_logs` con más de 30 días.

---

## 6. Aplicación Móvil — Flutter

### 6.1 Dependencias Principales

| Categoría | Paquetes |
|---|---|
| **Mapas y Ubicación** | `flutter_map ^7.0.2`, `latlong2 ^0.9.1`, `geolocator ^13.0.2`, `permission_handler ^11.3.1` |
| **NFC** | `flutter_nfc_kit ^3.5.0`, `nfc_manager ^4.0.0` |
| **Notificaciones** | `flutter_local_notifications ^18.0.1` |
| **Publicidad** | `google_mobile_ads ^5.1.0` |
| **Red** | `http ^1.2.2`, `socket_io_client ^3.1.4` |
| **Segundo plano** | `flutter_background_service ^5.0.10` |
| **Accesibilidad** | `flutter_tts ^4.2.2`, `vibration ^2.0.0` |
| **Persistencia** | `shared_preferences ^2.3.3` |
| **Internacionalización** | `flutter_localizations`, `intl ^0.20.1` |
| **Monitorización** | `sentry_flutter ^8.0.0` |
| **Otros** | `device_info_plus`, `url_launcher`, `home_widget`, `package_info_plus`, `html` |

### 6.2 Punto de Entrada y Secuencia de Inicialización

El archivo `lib/main.dart` (882 líneas) contiene toda la lógica de arranque:

```
main()
  ├── WidgetsFlutterBinding.ensureInitialized()
  ├── Inicializar ElderlyModeProvider
  ├── Leer versión de PackageInfo
  ├── Inicializar Sentry (DSN, release, environment)
  ├── Cargar SharedPreferences
  ├── Verificar sesión vía AuthService
  ├── Configurar AdService (AdMob)
  ├── Lanzar AlzitransApp
  └── Carga diferida (Future.microtask):
      ├── ForegroundService
      ├── BusAlertService
      ├── AssistantService
      ├── SocketService (WebSocket)
      ├── TtsService (Text-to-Speech)
      ├── Cargar paradas (StopsService)
      ├── Registrar rutas L1, L2, L3
      ├── Iniciar BusSimulationService
      └── Solicitar permisos (notificación, ubicación)
```

**Widget `AlzitransApp`:**
- `MaterialApp` con tema personalizado (AlzitransTheme)
- Gestión de locale (es/en/ca) persistida en SharedPreferences
- Modo personas mayores: escala texto x1.6 y agranda botones
- Observador de navegación para Sentry
- Pantalla inicial: `LoginPage` si no hay sesión, `HomePage` si hay JWT válido

**Widget `HomePage` (navegación principal):**
5 pestañas con `BottomNavigationBar`:
1. **Mapa** → `MapPage`
2. **Rutas** → `RoutesPage`
3. **NFC** → `NfcPage`
4. **Avisos** → `NoticesScreen`
5. **Perfil** → `ProfileScreen`

Timer de heartbeat cada 2 minutos enviando latido al servidor.

### 6.3 Estructura de Carpetas

```
lib/
├── main.dart            # Entrada + AlzitransApp + HomePage
├── constants/           # Configuración centralizada
│   ├── app_config.dart  # URL API, API Key, Sentry DSN, AdMob IDs
│   └── line_colors.dart # Mapeo de colores por línea
├── models/              # Clases de datos
├── services/            # Lógica de negocio (21 servicios)
├── pages/               # Páginas con navegación (11 archivos)
├── screens/             # Pantallas auxiliares (5 archivos)
├── widgets/             # Componentes reutilizables (5 archivos)
├── providers/           # Gestión de estado
├── theme/               # Tema visual
└── l10n/                # Traducciones
```

### 6.4 Modelos de Datos

#### `BusStop` — Parada de autobús
```dart
class BusStop {
  final int id;           // ID único
  final String name;      // Nombre de la parada
  final double lat, lng;  // Coordenadas GPS
  final List<String> lines; // Líneas que pasan ["L1", "L2"]
}
```

#### `TripRecord` — Registro de viaje
```dart
class TripRecord {
  final int? serverId;
  final String line;        // "L1", "L2", "L3"
  final String destination;
  final String stopName;
  final int? stopId;
  final DateTime timestamp;
  final bool confirmed;     // Confirmado por el usuario
}
```
Incluye `TripStats` con cálculos de uso por línea, parada, hora del día, día de la semana, y `MonthlyStats` para gráficas mensuales.

#### `BusCard` — Tarjeta NFC de transporte
```dart
class BusCard {
  final String uid;          // UID hexadecimal de la tarjeta
  final int balance;         // Saldo en céntimos
  final int trips;           // Viajes restantes
  final String cardType;     // "Bono 10", "Mensual", etc.
  final bool isUnlimited;   // Tarjeta ilimitada
  final DateTime? lastUse;
  final List<TripRecord> tripHistory;
}
```
Parsea datos raw de bloques MIFARE Classic y también soporta formato Flipper Zero.

### 6.5 Servicios (Capa de Lógica de Negocio)

Los 21 servicios de la app se organizan por responsabilidad:

| Servicio | Patrón | Descripción |
|---|---|---|
| **AuthService** | Instancia | Login, registro, JWT, sesión persistida en SharedPreferences |
| **StopsService** | Instancia | Carga paradas: API primero → fallback `assets/stops.json` → caché SharedPreferences |
| **RenfeService** | Estático | Horarios Cercanías C2: GTFS estático + retrasos GTFS-RT |
| **SocketService** | Singleton | WebSocket Socket.IO para avisos en tiempo real |
| **BusSimulationService** | Singleton | Motor de simulación de posición de buses en las rutas |
| **BusTimesService** | Instancia | Horarios programados de buses |
| **BusAlertService** | Instancia | Detección de proximidad bus-parada |
| **ForegroundService** | Top-level | Servicio Android en segundo plano, check cada 30s |
| **BackgroundService** | Instancia | Gestión del ciclo de vida del servicio background |
| **LocationService** | Instancia | Proveedor de ubicación GPS |
| **NfcService** | Instancia | Lectura/parseo de tarjetas NFC MIFARE |
| **NotificationService** | Instancia | Notificaciones locales Android |
| **NoticesService** | Instancia | API de avisos de servicio |
| **TripHistoryService** | Instancia | CRUD de viajes contra la API |
| **FavoriteStopsService** | Instancia | Paradas favoritas persistidas localmente |
| **RoutingService** | Instancia | Cálculo de rutas |
| **GpsTrackService** | Instancia | Grabación de trazas GPS |
| **AdService** | Instancia | Google AdMob (banner, interstitial, native) |
| **AssistantService** | Instancia | Asistente de navegación con atajos |
| **TtsService** | Instancia | Text-to-Speech para accesibilidad |

#### Patrón de comunicación con API

Todos los servicios HTTP siguen el mismo patrón:

```dart
final response = await http.get(
  Uri.parse('${AppConfig.baseUrl}/endpoint'),
  headers: AppConfig.headers,  // Incluye X-API-Key
).timeout(AppConfig.httpTimeout);

if (response.statusCode == 200) {
  final data = json.decode(response.body);
  // Procesar datos...
}
```

- URL base centralizada en `AppConfig.baseUrl`
- API Key incluida automáticamente en `AppConfig.headers`
- Timeout configurable (`AppConfig.httpTimeout`)
- JWT añadido manualmente en endpoints autenticados

### 6.6 Páginas y Pantallas

#### Páginas principales (`lib/pages/`)

| Archivo | Descripción |
|---|---|
| `map_page.dart` | Mapa interactivo OpenStreetMap con paradas, buses simulados y rutas |
| `routes_page.dart` | Visualizador de rutas L1/L2/L3 con todas las paradas |
| `nfc_page.dart` | Lector de tarjetas NFC MIFARE Classic 1K |
| `login_page.dart` | Pantalla de login con email y contraseña |
| `register_page.dart` | Registro con validación de email |
| `otp_verification_page.dart` | Verificación por código OTP de email |
| `forgot_password_page.dart` | Recuperación de contraseña |
| `reset_password_page.dart` | Reseteo de contraseña con token |
| `settings_page.dart` | Ajustes: notificaciones distancia, TTS, idioma, modo mayores |
| `splash_page.dart` | Pantalla de carga inicial |

#### Pantallas auxiliares (`lib/screens/`)

| Archivo | Descripción |
|---|---|
| `active_alerts_screen.dart` | Alertas activas de buses cercanos |
| `notices_screen.dart` | Avisos de servicio con filtro por línea |
| `profile_screen.dart` | Perfil del usuario con stats |
| `trip_history_screen.dart` | Historial de viajes con estadísticas |
| `battery_permission_screen.dart` | Solicitud de permiso de batería |

### 6.7 Widgets Personalizados

| Widget | Descripción |
|---|---|
| `animated_bus_marker.dart` | Marcador de bus animado sobre el mapa (rotación según heading) |
| `stop_info_sheet.dart` | Bottom sheet con info de parada: líneas, horarios, próximo bus, Renfe |
| `line_filter.dart` | Filtro visual de líneas (chips L1/L2/L3) |
| `multi_line_stop_marker.dart` | Marcador de parada con indicador de múltiples líneas |
| `simple_map_widget.dart` | Widget de mapa simplificado para reutilización |

### 6.8 Internacionalización (i18n)

**Idiomas soportados:** Español (es, template), Inglés (en), Valenciano/Catalán (ca)

**Configuración (`l10n.yaml`):**
```yaml
arb-dir: lib/l10n
template-arb-file: app_es.arb
output-localization-file: app_localizations.dart
nullable-getter: false
```

**Archivos:**
- `lib/l10n/app_es.arb` — Plantilla con todas las cadenas
- `lib/l10n/app_en.arb` — Traducciones al inglés
- `lib/l10n/app_ca.arb` — Traducciones al valenciano

**Uso en código:**
```dart
AppLocalizations.of(context).welcomeMessage
```

**Generación:** Las clases `AppLocalizations*` se generan automáticamente con `flutter gen-l10n`.

### 6.9 Tema y Diseño Visual

Definido en `lib/theme/app_theme.dart`:

**Paleta de colores (`AlzitransColors`):**
- **Primary (Burgundy):** `#8B1A4A` — Color principal de la marca
- **Accent (Coral):** `#E85D75` — Acentos e interacciones
- **Background:** Blanco/gris claro
- **Surface:** Blanco para tarjetas y superficies

**Colores por línea de bus:**
- L1: Color específico definido en `line_colors.dart`
- L2: Color específico
- L3: Color específico

### 6.10 Accesibilidad (Modo Personas Mayores)

Gestionado por `ElderlyModeProvider` (ValueNotifier persistido en SharedPreferences):

**Cuando está activado:**
- Factor de escala de texto: **x1.6** (mediante `MediaQuery.textScalerOf`)
- Botones e iconos más grandes
- Contraste mejorado
- Compatible con TTS (Text-to-Speech) para lectura de paradas y horarios
- Vibración al recibir alertas de proximidad

### 6.11 Servicio en Segundo Plano

Implementado en `lib/services/foreground_service.dart`:

**Arquitectura:**
- Usa `flutter_background_service` para mantener un proceso Dart activo
- Función top-level `onStart` con `@pragma('vm:entry-point')`
- Canal de notificación: `alzibus_alerts` (prioridad alta, con sonido y vibración)

**Ciclo de vida:**
1. La app principal inicia el servicio foreground
2. El servicio ejecuta `_checkLocationStatic()` cada **30 segundos**
3. Obtiene la ubicación GPS del usuario
4. Carga paradas desde caché (SharedPreferences `stops_cache`)
5. Calcula distancia a cada parada
6. Si está dentro del radio configurado → notificación local + vibración
7. Actualiza widget de pantalla de inicio (`home_widget`)
8. El servicio se detiene al recibir el evento `stop` de la app principal

---

## 7. Panel de Administración — Flutter Web

### Tecnología
- **Framework:** Flutter Web
- **Dependencias:** `fl_chart` (gráficas), `data_table_2` (tablas avanzadas), `http`, `shared_preferences`, `intl`
- **SDK mínimo:** 3.6.0

### Comunicación con Backend
Clase `ApiService` (singleton) en `admin_panel/lib/services/api_service.dart`:
- URL base: `http://149.74.26.171:4000/api`
- API Key en cabecera `X-API-Key`
- Token admin JWT persistido en SharedPreferences
- Caché en memoria para paradas y rutas
- Timeout: 10 segundos
- Auto-logout en respuestas 401/403

### Pantallas

| Pantalla | Descripción |
|---|---|
| **LoginScreen** | Acceso con contraseña de administrador |
| **DashboardScreen** | KPIs generales: usuarios activos, viajes hoy, estadísticas |
| **StopsScreen** | CRUD de paradas con coordenadas y líneas |
| **RoutesScreen** | Gestión de rutas de cada línea |
| **StatsScreen** | Estadísticas con gráficos (fl_chart): uso por hora, línea, día |
| **UsersScreen** | Listado de usuarios, activar/desactivar, eliminar |
| **NoticesAdminScreen** | CRUD de avisos de servicio (push por Socket.IO) |
| **SettingsScreen** | Configuración del panel |

### Navegación
Barra lateral `NavigationRail` responsiva (se expande cuando el ancho > 800px). Soporta tema claro/oscuro con toggle.

---

## 8. Infraestructura y Despliegue

### 8.1 Docker Compose

Archivo `backend/docker-compose.yml`:

```yaml
services:
  postgres:
    image: postgres:15
    container_name: alzibus_postgres
    environment:
      POSTGRES_USER: alzibus_user
      POSTGRES_PASSWORD: alzibus_password
      POSTGRES_DB: alzibus_db
    ports:
      - "5433:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    networks:
      - alzibus-net

volumes:
  pgdata:

networks:
  alzibus-net:
    driver: bridge
```

**Puntos clave:**
- Puerto **5433** externo para evitar conflicto con PostgreSQL local
- Volumen `pgdata` persistente (los datos sobreviven a `docker compose down`)
- `init.sql` se ejecuta automáticamente en la primera creación del contenedor
- Para reiniciar la BD desde cero: `docker compose down -v` (elimina el volumen)

### 8.2 Despliegue en Producción (Raspberry Pi)

El servidor de producción es una **Raspberry Pi** accesible en la IP `149.74.26.171:4000`.

**Stack de producción:**
- **Docker:** Contenedor PostgreSQL 15
- **PM2:** Process manager para Node.js (reinicio automático, logs)
- **Node.js 18:** Runtime del backend

**No se usa** el `Dockerfile` del backend en producción. PM2 ejecuta `server.js` directamente en el sistema host de la Raspberry Pi.

### 8.3 Scripts de Arranque y Parada

#### `start.sh` (arranque)
```bash
# 1. Auto-detecta la ruta del directorio backend
# 2. Levanta PostgreSQL: docker compose up -d
# 3. Espera 3 segundos para la BD
# 4. Instala dependencias si no existen: npm install --omit=dev
# 5. Modo producción (PM2): pm2 start server.js --name "alzibus-api"
# 6. Modo desarrollo (si no hay PM2): npm run dev
```

#### `stop.sh` (parada)
```bash
# 1. Auto-detecta la ruta del directorio backend
# 2. Detiene PM2: pm2 stop alzibus-api
# 3. Detiene Docker: docker compose down
```

**Uso:**
```bash
cd backend
chmod +x start.sh stop.sh
./start.sh   # Arrancar todo
./stop.sh    # Parar todo
```

---

## 9. Configuración de Android

### `android/app/build.gradle`

| Parámetro | Valor |
|---|---|
| **Namespace** | `com.alzitrans.app` |
| **compileSdk** | 36 |
| **minSdkVersion** | 24 (Android 7.0 Nougat) |
| **targetSdk** | 35 (Android 15) |
| **ndkVersion** | 27.0.12077973 |
| **Java target** | JavaVersion.VERSION_17 |
| **AGP (Android Gradle Plugin)** | 8.9.1 |
| **Kotlin** | 2.1.0 |

### Firma de release
Configurada en `android/key.properties` (excluido del repositorio por seguridad):
```properties
storePassword=***
keyPassword=***
keyAlias=upload
storeFile=ruta/al/keystore.jks
```

### ProGuard
Activo en release con `minifyEnabled true` y `shrinkResources true`. Reglas personalizadas en `proguard-rules.pro`.

### Desugaring
`coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'` — permite usar APIs de Java 8+ en versiones antiguas de Android.

### Compilar APK/AAB
```bash
# APK de debug
flutter build apk --debug

# APK de release
flutter build apk --release \
  --dart-define=API_KEY=tu-api-key \
  --dart-define=SENTRY_DSN=tu-sentry-dsn

# Bundle para Google Play
flutter build appbundle --release \
  --dart-define=API_KEY=tu-api-key \
  --dart-define=SENTRY_DSN=tu-sentry-dsn
```

---

## 10. Flujos de Datos Principales

### Flujo de carga de paradas

```
App inicia
  └── StopsService.loadStops()
        ├── GET /api/stops (Backend)
        │     └── SELECT * FROM stops (PostgreSQL)
        │           └── Respuesta: [{id, name, lat, lng, lines}, ...]
        │     └── Guardar en SharedPreferences (caché)
        │     └── Mapear a List<BusStop>
        │
        └── [Si falla la API] → rootBundle.loadString('assets/stops.json')
              └── Cargar fallback local (52 paradas)
              └── Guardar en SharedPreferences (caché para background)
```

### Flujo de autenticación

```
Usuario introduce email + contraseña
  └── POST /api/login {email, password}
        ├── Verificar email existe en DB
        ├── Verificar cuenta verificada (OTP completado)
        ├── Verificar cuenta activa
        ├── bcrypt.compare(password, hash)
        ├── Generar JWT {id, email} (24h)
        └── Respuesta: {token, user: {id, email}}
              └── App guarda: jwt_token, user_email, user_id en SharedPreferences
              └── Configura Sentry User
              └── Navega a HomePage
```

### Flujo de simulación de buses

```
BusSimulationService (Singleton)
  ├── Timer cada 500ms: actualiza posiciones interpoladas
  ├── Timer de tracking: consulta BusTimesService
  ├── Calcula progreso entre paradas
  ├── Interpola posición sobre el track GPS
  └── Emite StreamController → MapPage escucha y repinta marcadores
```

### Flujo de avisos en tiempo real

```
Admin Panel → POST /api/admin/notices {title, body, line}
  └── Backend guarda en DB
  └── io.emit('new_notice', data)  ← Socket.IO broadcast
        └── App recibe evento 'new_notice'
              └── Muestra AlertDialog con título, cuerpo y línea afectada
```

---

## 11. Integración con API de Renfe

**Servicio:** `lib/services/renfe_service.dart`  
**Línea:** C2 Cercanías Valencia  
**Estación:** Alzira (ID GTFS: `64104`)

### Fuentes de datos

| Fuente | URL / Ubicación | Tipo |
|---|---|---|
| **Horarios estáticos** | Hardcoded en `_scheduledTrains` | GTFS static (extraído manualmente) |
| **Retrasos en tiempo real** | `https://gtfsrt.renfe.com/trip_updates.json` | GTFS-RT (API pública Renfe) |

### Modelo de datos

```dart
// Horario programado
class TrainSchedule {
  final String tripId;        // "4062V24000C2"
  final String time;          // "05:55"
  final String destination;   // "València Nord"
  final String direction;     // "valencia" o "moixent"
}

// Llegada con retraso
class TrainArrival {
  final String scheduledTime;  // Hora programada
  final String destination;
  final String direction;
  final int delayMinutes;      // Retraso en minutos
  final String line;           // "C2"
  
  String get actualTime => ...;  // Hora real = programada + retraso
  String get statusText => ...;  // "Puntual" o "+5 min"
}
```

### Lógica de obtención

1. `getNextTrains(limit)` filtra trenes cuya hora > hora actual
2. Ordena por hora ascendente
3. Llama a `_fetchDelays()` → GET `gtfsrt.renfe.com/trip_updates.json`
4. Parsea JSON de GTFS-RT, filtra entidades con `tripId` que contenga `"C2"`
5. Extrae `delay` (segundos) y convierte a minutos
6. Combina horario + retraso → devuelve `List<TrainArrival>`

### Mantenimiento

> **IMPORTANTE:** Los horarios estáticos están hardcoded para **días laborables**. Si Renfe modifica los horarios de la C2, es necesario actualizar manualmente la lista `_scheduledTrains` con los nuevos datos del GTFS estático.

---

## 12. Lectura de Tarjetas NFC

**Servicio:** `lib/services/nfc_service.dart`  
**Modelo:** `lib/models/bus_card.dart`  
**Tecnología:** MIFARE Classic 1K (tarjetas de transporte)

### Estructura de la tarjeta

| Bloque | Contenido |
|---|---|
| **Bloque 5** | Tipo de tarjeta (1 byte) + flag ilimitado |
| **Bloque 8** | Saldo (Value Block, Little-Endian) |
| **Bloques 20-26** | Historial de viajes |

### Tipos de tarjeta

| Código | Tipo |
|---|---|
| `0x01` | Bono 10 viajes |
| `0x02` | Bono 20 viajes |
| `0x03` | Mensual |
| `0x04` | Estudiante |
| `0xFF` | Ilimitado |

### Cálculo de viajes restantes

```dart
// Tarifa: 1.50 € por viaje
// Balance en céntimos
trips = balance ~/ 150;  // División entera
```

### Formato Flipper Zero

El modelo `BusCard` también soporta parseo de dumps de Flipper Zero (formato texto con bloques hexadecimales), útil para depuración.

---

## 13. Variables de Entorno

### Backend (`backend/.env`)

| Variable | Descripción | Ejemplo |
|---|---|---|
| `PORT` | Puerto del servidor | `4000` |
| `DB_USER` | Usuario PostgreSQL | `alzibus_user` |
| `DB_HOST` | Host PostgreSQL | `localhost` |
| `DB_NAME` | Nombre de la base de datos | `alzibus_db` |
| `DB_PASSWORD` | Contraseña PostgreSQL | `alzibus_password` |
| `DB_PORT` | Puerto PostgreSQL | `5433` |
| `JWT_SECRET` | Clave secreta para firmar JWT | `cadena-secreta-larga` |
| `API_KEY` | Clave API para validar peticiones | `alzibus-secret-key-2024` |
| `EMAIL_USER` | Email para envío de OTP | `tuemail@gmail.com` |
| `EMAIL_PASS` | Contraseña de aplicación Gmail | `xxxx xxxx xxxx xxxx` |
| `DISCORD_WEBHOOK_URL` | URL del webhook de Discord | `https://discord.com/api/webhooks/...` |
| `ALLOWED_ORIGINS` | Orígenes CORS permitidos | `http://localhost:3000,http://149.74.26.171` |
| `ADMIN_PASSWORD` | Contraseña del panel admin | `contraseña-admin` |

### App Flutter (inyectadas en compilación)

| Variable | Flag de compilación | Descripción |
|---|---|---|
| `API_KEY` | `--dart-define=API_KEY=...` | Clave API |
| `SENTRY_DSN` | `--dart-define=SENTRY_DSN=...` | DSN de Sentry |

Estas variables se leen en `lib/constants/app_config.dart`:
```dart
static const String apiKey = String.fromEnvironment('API_KEY', defaultValue: 'alzibus-secret-key-2024');
static const String sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');
```

---

## 14. Guía de Mantenimiento

### Tareas periódicas

| Tarea | Frecuencia | Cómo |
|---|---|---|
| **Actualizar horarios Renfe** | Cuando Renfe cambie horarios | Editar `_scheduledTrains` en `renfe_service.dart` |
| **Actualizar paradas** | Cuando cambien rutas | Panel Admin → Paradas, y actualizar `assets/stops.json` |
| **Limpiar logs API** | Automático (cron diario) | Se eliminan registros >30 días |
| **Actualizar dependencias Flutter** | Trimestral | `flutter pub upgrade` + probar |
| **Actualizar dependencias Node.js** | Trimestral | `npm update` + probar |
| **Renovar keystore Android** | Antes de expiración | Regenerar y actualizar `key.properties` |
| **Backup de base de datos** | Semanal | `docker exec alzibus_postgres pg_dump -U alzibus_user alzibus_db > backup.sql` |

### Añadir una nueva parada

1. **Panel Admin:** Crear parada con nombre, coordenadas y líneas
2. **Base de datos:** Se guarda automáticamente en tabla `stops`
3. **Fallback local:** Actualizar `assets/stops.json` con la nueva parada
4. **Recompilar app** para incluir el nuevo JSON de fallback

### Añadir un nuevo idioma

1. Crear `lib/l10n/app_XX.arb` (copiar `app_es.arb` como plantilla)
2. Traducir todas las cadenas
3. Añadir el locale en `main.dart` → `supportedLocales`
4. Ejecutar `flutter gen-l10n`
5. Añadir opción en `settings_page.dart`

### Añadir un nuevo endpoint API

1. Definir la ruta en `backend/server.js`
2. Decidir si requiere autenticación (`authenticateToken`)
3. Implementar la lógica con consultas parametrizadas
4. Crear el servicio correspondiente en `lib/services/`
5. Probar con herramientas como Postman o curl

### Modificar el esquema de base de datos

1. Crear script de migración en `backend/` (ej: `db_migrate_xxx.js`)
2. Usar `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` para idempotencia
3. Actualizar `init.sql` para nuevas instalaciones
4. Ejecutar migración en producción: `node db_migrate_xxx.js`

---

## 15. Solución de Problemas Frecuentes

### La app no conecta con el backend

| Causa | Solución |
|---|---|
| Backend no arrancado | Ejecutar `./start.sh` en `backend/` |
| IP incorrecta | Verificar `AppConfig.baseUrl` en `app_config.dart` |
| API Key no coincide | Comparar `API_KEY` en `.env` y `app_config.dart` |
| Firewall bloquea puerto 4000 | Abrir puerto en el router/firewall |
| PostgreSQL no arrancado | `docker compose up -d` en `backend/` |

### Error "Connection refused" en PostgreSQL

```bash
# Verificar que el contenedor está corriendo
docker ps | grep alzibus_postgres

# Si no está, levantarlo
cd backend
docker compose up -d

# Verificar conectividad
docker exec alzibus_postgres pg_isready -U alzibus_user
```

### Las paradas no se cargan

1. Verificar que el backend responde: `curl http://IP:4000/api/stops`
2. Si la API falla, la app usa `assets/stops.json` (fallback)
3. Si el fallback también falla, verificar que el asset está declarado en `pubspec.yaml`

### Los horarios de Renfe están desactualizados

Los horarios están hardcoded en `renfe_service.dart`. Hay que:
1. Consultar el GTFS estático de Renfe para la C2
2. Actualizar la lista `_scheduledTrains` con los nuevos horarios
3. Recompilar la app

### Error al compilar la app

```bash
# Limpiar caché de build
flutter clean
flutter pub get

# Si hay problemas con Gradle
cd android
./gradlew clean
cd ..
flutter build apk
```

### El servicio en segundo plano no funciona

1. Verificar que la app tiene permisos de ubicación en segundo plano
2. Desactivar optimización de batería para Alzitrans en ajustes del dispositivo
3. En Xiaomi/Huawei: añadir a lista blanca de autostart
4. Verificar que las notificaciones no están bloqueadas

### Resetear la base de datos completamente

```bash
cd backend
docker compose down -v    # Elimina contenedor Y volumen de datos
docker compose up -d      # Recrea con init.sql limpio
node import_stops.js      # Reimportar paradas
```

### Logs del servidor

```bash
# Con PM2
pm2 logs alzibus-api

# Logs del contenedor PostgreSQL
docker logs alzibus_postgres

# Estado general
pm2 status
docker ps
```

---

**Fin del Manual Técnico**

*Alzitrans v3.0 — Transporte público urbano de Alzira*  
*Repositorio: github.com/BocamoCM/Alzibus*  
*Rama principal: main*
