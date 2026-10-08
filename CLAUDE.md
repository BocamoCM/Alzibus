# Alzitrans/Alzibus — guía para Claude Code

Proyecto mantenido en solitario por BocamoCM (estudiante DAM, Alzira/Valencia). Tres piezas en este repo:

- **App Flutter** (`lib/`): mapa en tiempo real, lectura NFC de tarjetas MIFARE Classic 1K, SUMA10, geofencing.
- **Backend Node.js** (`backend/`): API REST en una Raspberry Pi (PM2), seguridad reforzada (bcrypt, SQL parametrizado, JWT).
- **Web** (`website/`, `admin_panel/`): landing + panel de administración.

Para contexto más detallado y el estado de la última sesión de trabajo, lee [CONTEXTO.md](CONTEXTO.md).

## Subagentes del proyecto

Hay tres subagentes definidos en `.claude/agents/` (viajan con el repo, no son de este PC):
- `flutter-nfc` — NFC, protocolo MIFARE, UI de `lib/`.
- `backend-api` — API, seguridad, BBDD del backend.
- `release-ops` — builds, versionado, CI/CD, despliegue web.

Invócalos con el Agent tool cuando la tarea caiga claramente en su dominio.

## Reglas del proyecto (no son opcionales)

- **Nunca** pongas `API_KEY` ni ningún secreto con valor por defecto en el código (Dart o JS). Siempre se inyecta por entorno (`--dart-define`, `backend/.env`).
- **Nunca** leas, muestres ni commitees `backend/.env` (está en `.gitignore`, así debe seguir).
- Único plugin NFC: `nfc_manager`. No reintroducir `flutter_nfc_kit`.
- SQL siempre parametrizado en `backend/`; nunca concatenar strings en queries.
- Commits en español, formato `tipo(scope): descripción` (ej. `fix(nfc): ...`, `feat(backend): ...`, `security(backend): ...`), coherente con el historial existente.
- Se trabaja directo sobre `main`, sin feature branches.

## Automatizaciones ya configuradas

- **Pre-commit hook** (`.githooks/pre-commit`): bloquea commits que incluyan un `.env`, formatea Dart staged y corre `flutter analyze` / chequeo de sintaxis en `.js` staged. Activarlo en una máquina nueva (una vez, si no vino ya en la copia del `.git`):
  ```bash
  git config core.hooksPath .githooks
  ```
- **CI** (`.github/workflows/build.yml`): job `lint-and-analyze` corre en cada push/PR antes de construir el APK.
