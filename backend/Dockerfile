# Usar imagen oficial de Node.js
FROM node:18-slim

# Crear directorio de app
WORKDIR /usr/src/app

# Copiar archivos de dependencias
COPY package*.json ./

# Instalar dependencias
RUN npm install --production

# Copiar el resto del código
COPY . .

# Exponer el puerto
EXPOSE 3000

# Comando para arrancar
CMD [ "node", "server.js" ]
