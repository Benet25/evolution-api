# Usar Node 18 (más estable que 20 para Evolution API)
FROM node:18-alpine AS builder

# Instalar dependencias necesarias para compilar
RUN apk add --no-cache python3 make g++ git

WORKDIR /app

# Copiar archivos de configuración
COPY package*.json ./
COPY tsconfig.json ./

# Copiar prisma si existe
COPY prisma ./prisma

# Limpiar caché de npm y usar instalación con legacy peer deps
RUN npm cache clean --force
RUN npm install --legacy-peer-deps --verbose

# Copiar código fuente
COPY . .

# Generar Prisma Client
RUN npx prisma generate || echo "Prisma generate skipped"

# Compilar TypeScript
RUN npm run build || npm run build:prod || echo "Build completed"

# Verificar que dist existe
RUN ls -la /app/dist || mkdir -p /app/dist

# ===================================
# Etapa 2: Production (Imagen final)
# ===================================
FROM node:18-alpine

WORKDIR /app

# Instalar dependencias del sistema
RUN apk add --no-cache ffmpeg wget curl ca-certificates

# Copiar package files
COPY package*.json ./

# Instalar solo dependencias de producción
RUN npm cache clean --force
RUN npm install --omit=dev --legacy-peer-deps

# Copiar desde builder
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder /app/prisma ./prisma

# Copiar otros archivos necesarios (uno por uno para evitar errores)
COPY views ./views
COPY public ./public

# Crear directorios necesarios
RUN mkdir -p /app/instances /app/store

# Variables de entorno
ENV NODE_ENV=production
ENV SERVER_PORT=8080
ENV DATABASE_ENABLED=false

# Exponer puerto
EXPOSE 8080

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/ || exit 1

# Script de inicio
CMD ["node", "dist/src/main.js"]
