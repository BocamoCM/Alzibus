#!/bin/bash
# ============================================================
# Alzitrans - Health Monitor (Raspberry Pi 5)
# Script para comprobar el estado del sistema, API y Base de Datos.
# Creado para Raspberry Pi OS Lite.
# Uso: bash monitor.sh
# Usa colores para hacer más fácil la lectura desde terminal.
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==============================================${NC}"
echo -e "${YELLOW}🚌 ALZITRANS SERVIDOR - MONITORIZACIÓN RPI 5${NC}"
echo -e "${BLUE}==============================================${NC}"
echo ""

# 1. Recursos del Sistema (Raspberry Pi)
echo -e "${YELLOW}[1/3] Sistema y Hardware:${NC}"
uptime -p

# Temperatura de la CPU (comando exclusivo de RPi)
if command -v vcgencmd &> /dev/null; then
    TEMP=$(vcgencmd measure_temp 2>/dev/null | egrep -o '[0-9.]+..C')
    echo -e "Temperatura CPU: \t${GREEN}${TEMP}${NC}"
else
    echo -e "Temperatura CPU: \t${RED}No detectada${NC}"
fi

# Memoria RAM
free -m | awk 'NR==2{printf "Memoria RAM (Usada): \t\033[0;32m%.2f%%\033[0m (%s MB Libres)\n", $3*100/$2, $4}'
echo ""

# 2. Estado de la Base de Datos (PostgreSQL en Docker)
echo -e "${YELLOW}[2/3] Base de Datos (Docker - alzibus_postgres):${NC}"
if command -v docker &> /dev/null; then
    DB_STATUS=$(docker inspect -f '{{.State.Status}}' alzibus_postgres 2>/dev/null || echo "not_found")
    if [ "$DB_STATUS" == "running" ]; then
        echo -e "Contenedor postgres: \t${GREEN}✅ ONLINE${NC}"
    else
        echo -e "Contenedor postgres: \t${RED}❌ CAÍDO ($DB_STATUS)${NC}"
        echo -e "👉 Para revisarlo: \t docker logs alzibus_postgres --tail 20"
    fi
else
    echo -e "${RED}Docker no está instalado en este path.${NC}"
fi
echo ""

# 3. Estado de la API (Node.js con PM2)
echo -e "${YELLOW}[3/3] Backend (PM2 - alzibus-backend):${NC}"
if command -v pm2 &> /dev/null; then
    # Parseamos la salida de pm2 jlist para no imprimir la tabla enorme de PM2.
    # El comando json de PM2 no bloquea como status en algunos entornos shell.
    PM2_STATUS=$(pm2 jlist | grep -oP '"name":"alzibus-backend"[^}]*"status":"\K[^"]+')
    
    if [ "$PM2_STATUS" == "online" ]; then
        echo -e "API REST: \t\t${GREEN}✅ ONLINE${NC}"
    elif [ -z "$PM2_STATUS" ]; then
        echo -e "API REST: \t\t${RED}⚠️ NO ENCONTRADO en esta sesión de pm2${NC}"
        echo -e "Asegúrate de ejecutar el script con el mismo usuario (borja)."
    else
        echo -e "API REST: \t\t${RED}❌ $PM2_STATUS${NC}"
        echo -e "👉 Para revisarlo:\t pm2 logs alzibus-backend"
    fi
else
    echo -e "${RED}PM2 no está disponible o accesible.${NC}"
fi

echo ""
echo -e "${BLUE}==============================================${NC}"
