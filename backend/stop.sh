#!/bin/bash

# Script de parada universal para Alzibus Backend
echo "🛑 Deteniendo ecosistema Alzibus..."

# 1. Definir posibles ubicaciones del backend
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

# 3. Detener el Backend
if command -v pm2 &> /dev/null
then
    echo "🔥 Deteniendo proceso en PM2..."
    pm2 stop alzibus-api 2>/dev/null && echo "✅ PM2 detenido." || echo "ℹ️ PM2 no estaba ejecutando el proceso."
else
    echo "ℹ️ PM2 no detectado."
fi

# 4. Detener la base de datos con Docker Compose
echo "📦 Deteniendo base de datos (PostgreSQL)..."
docker compose down

echo "✅ Todo se ha detenido correctamente."
