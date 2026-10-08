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

## Sesión 2026-10-08 (parte 2) — monetización y monedas/skins

Trabajo hecho con los subagentes `flutter-nfc` (ads) y `backend-api` (monedas),
revisado y verificado antes de commitear. Commits:

- `ffac95e security(backend)`: sync de monedas/skins endurecido — `GREATEST`
  atómico (fin de la carrera read-modify-write) y validación regex + tope de
  64 en `owned_skins` (antes se podía inyectar la coma del CSV).
- `662cf70 feat(ads)`: recuperadas impresiones perdidas. Diagnóstico cruzado
  con el panel de AdMob (show rate 32,8% → 2 de cada 3 anuncios rellenados no
  se mostraban). Precarga en frío de Intersticial/App-Open, banner NFC que
  estaba muerto reactivado, y el tap de parada en el mapa ahora cuenta para el
  intersticial. No toca el diferido de 3s ni la anti-bucle de App Open.
- `e33ab06 fix(game)`: **compra de skins server-authoritative**. Antes el gasto
  se revertía por el max-wins y las skins salían gratis. Nuevo endpoint
  `POST /api/game/skins/purchase {skinId, coins}` que cobra atómicamente; coste
  en `backend/src/config/skin-catalog.js` (mantener en sync con
  `lib/models/albus_skin.dart`). Cliente adopta el saldo autoritativo.

### ⚠️ IMPORTANTE antes de publicar a Play Store
El APK con el cliente nuevo llama a `/api/game/skins/purchase`. **Hay que
desplegar primero el backend en la Pi** (`git pull` + reiniciar PM2/Docker) o
las compras de skins fallarán con "no se pudo completar" (404). El GitHub
Release que crea la CI no llega solo a usuarios, pero al subir a Play sí.

### Acciones pendientes en el PANEL de AdMob (no son código, las haces tú)
- **Mediation → crear grupo** y añadir fuentes/bidding (Meta, AppLovin, Pangle).
  Es la mayor palanca del eCPM ($0,84 ahora): solo hay "AdMob default".
- **Publisher data (BETA) → activar First-party IDs** (recupera personalización).
- Intersticial `Interstitial_Tras_NFC` tiene tope "1 impr/10 min"; vigilar que
  no estrangule ahora que se dispara más.

### AdSense web — APARCADO (decisión 2026-10-08)
alzitrans.es rechazado por "Low value content" (53 páginas de parada tipo
plantilla, ~1,1k chars). AdSense no puede monetizar el Flutter web (`/app/`),
solo páginas de contenido, y ésas son las que Google ve como finas. ROI bajo
para el tráfico actual → se deja aparcado. Si se retoma: guía de tarifas/SUMA10
+ FAQ + enriquecer/noindexar las paradas. robots.txt/ads.txt/sitemap están OK.

### Loose end
`pubspec.lock` tiene bumps transitivos (meta 1.17→1.18, test 1.30→1.31) de un
`pub get` de esta sesión; quedó SIN commitear a propósito. Commitear o revertir
según convenga.

## Pendiente / en el radar (no son tareas urgentes, solo contexto)

- **Comercialización**: se está valorando licenciar Alzitrans al Ayuntamiento de Alzira (modelo licencia + mantenimiento, sin ceder propiedad del software). Posible relevancia: contratos menores LCSP hasta 15.000€ sin licitación (primer año); separar responsable (ayuntamiento) / encargado del tratamiento (él) para RGPD si se gestionan datos de usuarios.
- Los fixes de SEO (redirects, robots.txt, sitemap) en `website/` fueron el último movimiento en GitHub — no se tocaron desde este PC, conviene revisar si quedó algo a medias ahí.

## Notas de workflow

- Se trabaja directo sobre `main`, sin feature branches (visto en el historial de commits).
- Mensajes de commit en español, formato `tipo(scope): descripción` (ej. `fix(nfc): ...`, `feat(nfc): ...`, `security(backend): ...`).

## Herramientas de Claude Code para este proyecto (2026-10-08)

Todo esto vive en el repo (viaja por USB o por `git clone`, no hay que rehacerlo en el PC nuevo salvo un paso):

- **`CLAUDE.md`** (raíz) — reglas e índice que Claude Code carga automáticamente en cada sesión de este repo (convenciones de commits, qué no tocar, dónde está cada subagente).
- **Subagentes** en `.claude/agents/`: `flutter-nfc`, `backend-api`, `release-ops` — ver sección "Subagentes" de `CLAUDE.md`.
- **Pre-commit hook** en `.githooks/pre-commit`: bloquea subir `.env`, formatea los `.dart` staged y corre `flutter analyze`/chequeo de sintaxis en `.js` staged.
  - **Paso manual una vez por máquina** (si clonas con `git clone` en vez de copiar la carpeta `.git` entera por USB):
    ```bash
    git config core.hooksPath .githooks
    ```
  - Si copias la carpeta completa (incluyendo `.git`) por USB, esta configuración ya viaja dentro de `.git/config` y no hace falta repetirlo.
- **CI** (`.github/workflows/build.yml`): nuevo job `lint-and-analyze` (corre `flutter analyze`) que debe pasar antes de `build-android`. Nota: no se añadió un check estricto de `dart format` porque ~89 de 110 archivos de `lib/` no estaban formateados con la regla por defecto y reformatearlos todos de golpe generaría un diff masivo fuera del alcance de este cambio — si se quiere ese check, hay que reformatear el repo primero en un commit dedicado.
