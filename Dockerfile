# ---------- ETAPA 1: builder ----------
FROM node:20-alpine AS builder
WORKDIR /app

# Copiamos los archivos de dependencias
COPY package*.json ./

# Instalamos solo las dependencias de producción
RUN npm ci --omit=dev

# Copiamos el resto del código fuente
COPY . .

# ---------- ETAPA 2: runtime ----------
FROM node:20-alpine AS runtime
WORKDIR /app

# Copiamos los node_modules de producción y el código fuente desde el builder
COPY --from=builder --chown=node:node /app/node_modules ./node_modules
COPY --from=builder --chown=node:node /app/package*.json ./
COPY --from=builder --chown=node:node /app/src ./src

# Configuramos el usuario sin privilegios por seguridad
USER node

# Exponemos el puerto que usa el servidor
EXPOSE 3000

# Opcional: Healthcheck (asegúrate de tener un endpoint /health en tu server.js)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://127.0.0.1:3000/health',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"

# Comando para iniciar el servidor
CMD ["node", "src/server.js"]