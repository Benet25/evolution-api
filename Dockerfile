# Etapa 1: Build
FROM node:20-alpine AS builder

WORKDIR /app

# Copiar archivos de dependencias
COPY package*.json ./
COPY tsconfig.json ./

# Instalar dependencias
RUN npm ci

# Copiar código fuente
COPY . .

# Generar Prisma Client y compilar
RUN npm run build

# Etapa 2: Production
FROM node:20-alpine

WORKDIR /app

# Instalar solo producción
COPY package*.json ./
RUN npm ci --only=production

# Copiar archivos compilados y necesarios
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder /app/views ./views
COPY --from=builder /app/public ./public

# Crear directorio para instancias
RUN mkdir -p /app/instances

# Variables de entorno por defecto
ENV NODE_ENV=production
ENV SERVER_PORT=8080

# Exponer puerto
EXPOSE 8080

# Comando de inicio
CMD ["node", "dist/src/main.js"]
