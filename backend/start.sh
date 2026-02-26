#!/bin/bash

# Script de inicio universal para Alzibus Backend
echo "🚀 Iniciando ecosistema Alzibus..."

# 1. Definir posibles ubicaciones del backend
# Primero intenta donde está el script, luego busca en rutas comunes
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
    echo "❌ Error: No se pudo encontrar la carpeta 'backend' de Alzitrans."
    echo "He buscado en:"
    for path in "${POSSIBLE_PATHS[@]}"; do echo "  - $path"; done
    echo ""
    echo "Por favor, coloca este script en la carpeta 'backend' o asegúrate de que el proyecto esté en ~/Alzi/Alzibus/backend"
    exit 1
fi

# 2. Entrar en la carpeta del backend
cd "$BACKEND_DIR" || exit
echo "📂 Trabajando en: $BACKEND_DIR"

# 3. Levantar la base de datos con Docker Compose
echo "📦 Levantando base de datos (PostgreSQL)..."
docker compose up -d

# 4. Esperar a que la DB esté lista
echo "⏳ Esperando a que la base de datos responda..."
sleep 3

# 5. Instalar dependencias si no existen
if [ ! -d "node_modules" ]; then
    echo "⬇️  Instalando dependencias de Node.js..."
    npm install --omit=dev
fi

# 6. Iniciar el Backend
if command -v pm2 &> /dev/null
then
    echo "🔥 Iniciando servidor con PM2 (Modo Producción)..."
    pm2 stop alzibus-api 2>/dev/null || true
    pm2 start server.js --name "alzibus-api"
    pm2 save
else
    echo "⚠️  PM2 no detectado. Iniciando con NPM (Modo Desarrollo)..."
    npm run dev
fi

echo "✅ Proceso completado."
