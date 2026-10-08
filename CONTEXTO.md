# Contexto del proyecto — Alzitrans/Alzibus

> Archivo de continuidad para retomar el desarrollo desde otro PC. Última actualización: 2026-10-08.

## Qué es

Alzitrans: app de transporte público para Alzira (Valencia). Desarrollador único: BocamoCM.
Repo: https://github.com/BocamoCM/Alzibus

Tres componentes en este mismo repo:
- **App móvil (Flutter)** — `lib/`. Mapa en tiempo real (OpenStreetMap), lectura NFC de tarjetas MIFARE Classic 1K (saldo, viajes, tarjetas SUMA10), validación de viajes, notificaciones por geofencing.
- **Backend (Node.js)** — `backend/`. Desplegado en una Raspberry Pi con PM2. API REST, Helmet, CORS, validación por API Key.
- **Panel de administración (web)** — `admin_panel/` y `website/`.

Versión actual app: `5.2.13+44` (ver `pubspec.yaml`).

## Estado al cerrar esta sesión

- `git status` limpio, `main` sincronizada con `origin/main` (se hizo `git pull --ff-only` para traer 2 commits que ya estaban en GitHub pero no en este PC: fixes de SEO/redirects en `Caddyfile`, `website/nginx.conf`, `website/robots.txt`, `website/sitemap.xml`).
- **No había cambios locales pendientes de subir** — todo lo de la sesión anterior (NFC) ya estaba en GitHub.
- Último bloque de trabajo real: **pila de tarjetas NFC estilo Google Wallet** (Alzira + SUMA10), swipe animado con spring physics, franjas SUMA respetando `borderRadius`, fix de flicker de 1 frame al completar el swap, y luego un ajuste para "hacer más fácil el cambio de tarjeta" (commit `ce33380`, el más reciente de esa serie).
- Antes de eso: ronda de seguridad — bcrypt cost 12, SQL parametrizado, escape XSS en backend; JWT en secure storage y biometría sin password en el cliente; permiso `AD_ID` + `RequestConfiguration` con flags COPPA en ads.

## Cómo levantar el entorno en el PC nuevo

```bash
git clone https://github.com/BocamoCM/Alzibus.git
cd Alzibus
flutter pub get
```

**Importante — API_KEY**: desde la auditoría de seguridad, `API_KEY` ya NO tiene `defaultValue` en `lib/constants/app_config.dart`. Hay que inyectarla con `--dart-define` o el header `X-API-Key` viaja vacío y el backend responde 401.

Orden de búsqueda que usan los scripts (`build_release.ps1`, `build_web.ps1`):
1. Variable de entorno `$env:ALZITRANS_API_KEY`
2. Línea `API_KEY=...` en `backend/.env` (no está en git, hay que recrearlo a mano en el PC nuevo)
3. Si no se encuentra ninguna, el build falla con error explícito.

Para correr la app en desarrollo con la key:
```bash
flutter run --dart-define=API_KEY=<valor>
```

Backend (si se va a tocar/levantar local):
```bash
cd backend
npm install
# crear backend/.env con API_KEY, PORT, DATABASE_URL (ver README.md)
node server.js
```

## Dónde está cada cosa

- `lib/core/providers/nfc_controller.dart` — lógica NFC (único plugin usado: `nfc_manager`; `flutter_nfc_kit` fue eliminado).
- `MANUAL_TECNICO.md`, `MANUAL_USUARIO.md` — documentación existente del proyecto.
- `RESPUESTA_RUBRICA_BBDD.md` — relacionado con la entrega/evaluación académica (DAM).
- `backend/POLITICA_PRIVACIDAD_ALZITRANS.md` — política de privacidad ya redactada.
- `build_release.ps1`, `build_web.ps1` — scripts de build con inyección de API_KEY.

## Pendiente / en el radar (no son tareas urgentes, solo contexto)

- **Comercialización**: se está valorando licenciar Alzitrans al Ayuntamiento de Alzira (modelo licencia + mantenimiento, sin ceder propiedad del software). Posible relevancia: contratos menores LCSP hasta 15.000€ sin licitación (primer año); separar responsable (ayuntamiento) / encargado del tratamiento (él) para RGPD si se gestionan datos de usuarios.
- Los fixes de SEO (redirects, robots.txt, sitemap) en `website/` fueron el último movimiento en GitHub — no se tocaron desde este PC, conviene revisar si quedó algo a medias ahí.

## Notas de workflow

- Se trabaja directo sobre `main`, sin feature branches (visto en el historial de commits).
- Mensajes de commit en español, formato `tipo(scope): descripción` (ej. `fix(nfc): ...`, `feat(nfc): ...`, `security(backend): ...`).
