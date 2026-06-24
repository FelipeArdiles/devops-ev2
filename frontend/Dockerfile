# Etapa 1: build de la aplicación React
FROM node:20-alpine AS builder
WORKDIR /build
COPY package*.json ./
RUN npm ci
COPY . .
ARG VITE_API_BASE_URL=
ENV VITE_API_BASE_URL=${VITE_API_BASE_URL}
RUN npm run build

# Etapa 2: servidor nginx (usuario no root en ejecución)
FROM nginxinc/nginx-unprivileged:alpine

USER root
RUN apk add --no-cache gettext

COPY nginx.conf /etc/nginx/templates/nginx.local.conf
COPY nginx.alb.conf /etc/nginx/templates/nginx.alb.conf
COPY nginx.ec2.conf.template /etc/nginx/templates/nginx.ec2.conf.template
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

COPY --from=builder /build/dist /usr/share/nginx/html
RUN chown -R 101:101 /usr/share/nginx/html

EXPOSE 8080
ENTRYPOINT ["/docker-entrypoint.sh"]
