#!/bin/bash

# ==========================================
# start.sh — Script de inicio del ecosistema Alzibus
# ==========================================
# Este script automatiza el arranque completo del backend:
# 1. Busca la carpeta del backend en varias ubicaciones posibles.
# 2. Levanta PostgreSQL con Docker Compose.
# 3. Instala las dependencias de Node.js si no existen.
# 4. Inicia el servidor con PM2 (producción) o npm (desarrollo).
#
# Diseñado para ejecutarse en la Raspberry Pi del servidor de producción.
# PM2 es un gestor de procesos que reinicia el servidor automáticamente
# si se cae y guarda logs rotativos.
#
# Uso: bash start.sh
# ==========================================

echo "🚀 Iniciando ecosistema Alzibus..."

# 1. Definir posibles ubicaciones del backend.
# El script puede estar en distintos sitios según cómo se haya clonado
# el repositorio, así que busca en varias rutas comunes.
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
POSSIBLE_PATHS=(
    "$SCRIPT_DIR"                           # La propia carpeta donde está el script
    "$SCRIPT_DIR/Alzi/Alzibus/backend"      # Subcarpeta del repositorio
    "$HOME/Alzi/Alzibus/backend"            # Ruta absoluta en home del usuario
    "$(pwd)/backend"                        # Ruta relativa desde el directorio actual
)

# Buscar cuál de las rutas contiene package.json (indicador del proyecto Node.js)
BACKEND_DIR=""

for path in "${POSSIBLE_PATHS[@]}"; do
    if [ -f "$path/package.json" ]; then
        BACKEND_DIR="$path"
        break
    fi
done

# Si no se encontró ninguna ruta válida, mostrar error y las rutas buscadas
if [ -z "$BACKEND_DIR" ]; then
    echo "❌ Error: No se pudo encontrar la carpeta 'backend' de Alzitrans."
    echo "He buscado en:"
    for path in "${POSSIBLE_PATHS[@]}"; do echo "  - $path"; done
    echo ""
    echo "Por favor, coloca este script en la carpeta 'backend' o asegúrate de que el proyecto esté en ~/Alzi/Alzibus/backend"
    exit 1
fi

# 2. Entrar en la carpeta del backend
# Si cd falla (permisos, ruta eliminada), se aborta el script con 'exit'
cd "$BACKEND_DIR" || exit
echo "📂 Trabajando en: $BACKEND_DIR"

# 3. Levantar la base de datos con Docker Compose.
# docker compose up -d arranca el contenedor de PostgreSQL en segundo plano.
# Si ya está corriendo, Docker no hace nada (es idempotente).
echo "📦 Levantando base de datos (PostgreSQL)..."
docker compose up -d

# 4. Esperar 3 segundos a que PostgreSQL termine de inicializarse.
# Sin esta espera, el servidor Node.js podría intentar conectarse
# antes de que la DB esté lista y fallar.
echo "⏳ Esperando a que la base de datos responda..."
sleep 3

# 5. Instalar dependencias de Node.js si la carpeta node_modules no existe.
# --omit=dev excluye las dependencias de desarrollo (menor tamaño en producción).
if [ ! -d "node_modules" ]; then
    echo "⬇️  Instalando dependencias de Node.js..."
    npm install --omit=dev
fi

# 6. Iniciar el servidor backend.
# Si PM2 está instalado (producción), lo usa porque ofrece:
#   - Reinicio automático si el proceso se cae.
#   - Logs rotativos y monitorización.
#   - Persistencia entre reinicios del sistema (pm2 save + pm2 startup).
# Si PM2 no está disponible (desarrollo), usa npm run dev (con nodemon).
if command -v pm2 &> /dev/null
then
    echo "🔥 Iniciando servidor con PM2 (Modo Producción)..."
    pm2 stop alzibus-api 2>/dev/null || true  # Parar instancia anterior si existe
    pm2 start server.js --name "alzibus-api"  # Iniciar con nombre identificable
    pm2 save                                   # Guardar la lista de procesos
else
    echo "⚠️  PM2 no detectado. Iniciando con NPM (Modo Desarrollo)..."
    npm run dev
fi

echo "✅ Proceso completado."
