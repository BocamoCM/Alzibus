#!/bin/bash

# ==========================================
# stop.sh — Script de parada del ecosistema Alzibus
# ==========================================
# Detiene todos los servicios del backend:
# 1. Para el servidor Node.js (PM2 si está disponible).
# 2. Detiene el contenedor de PostgreSQL (Docker Compose).
#
# Uso: bash stop.sh
# ==========================================

echo "🛑 Deteniendo ecosistema Alzibus..."

# 1. Buscar la carpeta del backend en las mismas ubicaciones que start.sh.
# Es necesario estar en el directorio correcto para que docker compose
# encuentre el archivo docker-compose.yml.
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
POSSIBLE_PATHS=(
    "$SCRIPT_DIR"
    "$SCRIPT_DIR/Alzi/Alzibus/backend"
    "$HOME/Alzi/Alzibus/backend"
    "$(pwd)/backend"
)

BACKEND_DIR=""

for path in "${POSSIBLE_PATHS[@]}"; do
    if [ -f "$path/package.json" ]; then
        BACKEND_DIR="$path"
        break
    fi
done

if [ -z "$BACKEND_DIR" ]; then
    echo "❌ Error: No se pudo localizar la carpeta 'backend' para detener los servicios."
    exit 1
fi

# 2. Entrar en la carpeta del backend
cd "$BACKEND_DIR" || exit

# 3. Detener el servidor Node.js (gestionado por PM2).
# pm2 stop detiene el proceso sin eliminarlo de la lista.
# El '2>/dev/null' suprime errores si PM2 no tiene el proceso registrado.
if command -v pm2 &> /dev/null
then
    echo "🔥 Deteniendo proceso en PM2..."
    pm2 stop alzibus-api 2>/dev/null && echo "✅ PM2 detenido." || echo "ℹ️ PM2 no estaba ejecutando el proceso."
else
    echo "ℹ️ PM2 no detectado."
fi

# 4. Detener la base de datos con Docker Compose.
# docker compose down para los contenedores y elimina las redes creadas.
# Los datos de PostgreSQL se MANTIENEN en el volumen 'pgdata' (persistente).
echo "📦 Deteniendo base de datos (PostgreSQL)..."
docker compose down

echo "✅ Todo se ha detenido correctamente."
