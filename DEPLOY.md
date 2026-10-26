# Despliegue (Raspberry Pi)

Proyecto en la Pi: `~/Alzi/Alzibus` (clon de git).

## ⚠️ Hay DOS docker-compose — usa el correcto
- `docker-compose.yml` (raíz, en git) → **NO lo uses para el stack**. Está divergente y NO carga `.env` (deja `JWT_SECRET` en blanco → rompería la auth).
- `backend/docker-compose.yml` (**NO está en git**, vive solo en la Pi) → **ESTE es el real**. Usa `env_file: - .env`, build `context: .`, imagen `backend-backend`. Postgres aquí está en `127.0.0.1:5433:5432` (solo localhost, por seguridad).

## Comandos

**Backend (código nuevo):**
```bash
cd ~/Alzi/Alzibus && git pull origin main
cd backend && docker compose up -d --build backend
```
(carga `.env` por `env_file` → `JWT_SECRET` ok; las sesiones no se pierden)

**Web (estática, solo pull):**
```bash
cd ~/Alzi/Alzibus && git pull origin main
# si no refresca: docker compose -f backend/docker-compose.yml restart website
```

**Base de datos:** los datos viven en el volumen externo `backend_pgdata`. Recrear el contenedor NO borra datos. NUNCA uses `docker compose down -v` ni `docker volume rm backend_pgdata`.

## Variables en `backend/.env`
- Requeridas: `JWT_SECRET`, `DB_PASSWORD` (que NO sea la por defecto `alzibus_password`), `API_KEY`, SMTP (`EMAIL_*`), `DISCORD_WEBHOOK_URL`.
- Ingresos (AdMob/AdSense): `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REFRESH_TOKEN` (el refresh token de Google caduca a los 7 días si la app OAuth está en Testing).
- Aviso de actualizar (opcional): `APP_LATEST_VERSION`, `APP_MIN_VERSION`, `APP_STORE_URL`.

## Pendiente de limpieza
Igualar o borrar el `docker-compose.yml` de la raíz para no volver a mezclar los dos.
