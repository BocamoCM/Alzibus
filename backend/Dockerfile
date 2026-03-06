# ==========================================
# Dockerfile — Imagen Docker del backend Alzibus
# ==========================================
# Construye una imagen Docker para ejecutar el servidor Node.js.
# NOTA: Actualmente NO se usa en producción (se usa PM2 directamente).
# Está preparado por si se quiere desplegar todo en contenedores.
#
# Construcción: docker build -t alzibus-backend .
# Ejecución:    docker run -p 3000:3000 --env-file .env alzibus-backend

# Usar la imagen oficial de Node.js 18 en su variante 'slim' (más ligera).
# slim excluye herramientas de compilación innecesarias (gcc, make, etc.)
FROM node:18-slim

# Establecer el directorio de trabajo dentro del contenedor.
# Todos los comandos siguientes se ejecutan desde aquí.
WORKDIR /usr/src/app

# Copiar primero SOLO los archivos de dependencias.
# Docker cachea cada capa: si package.json no cambia, npm install no se re-ejecuta.
# Esto acelera enormemente las rebuilds cuando solo cambia el código fuente.
COPY package*.json ./

# Instalar SOLO las dependencias de producción (sin devDependencies).
# Equivale a: npm install --omit=dev
RUN npm install --production

# Copiar el resto del código fuente al contenedor.
# Se ejecuta DESPUÉS de npm install para aprovechar la caché de Docker.
COPY . .

# Declarar que el contenedor escucha en el puerto 3000.
# Esto es solo documentación: no abre el puerto, hay que usar -p al hacer docker run.
EXPOSE 3000

# Comando que se ejecuta cuando el contenedor arranca.
# Inicia el servidor Node.js directamente (sin PM2 ni nodemon dentro del contenedor).
CMD [ "node", "server.js" ]
