# Multistage
# Stage 1: build React
FROM node:20-alpine AS builder
WORKDIR /build
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 2: nginx sin privilegios root
FROM nginxinc/nginx-unprivileged:alpine
USER root
RUN apk add --no-cache gettext \
  && mkdir -p /etc/nginx/templates /etc/nginx/conf.d \
  && chown -R nginx:nginx /etc/nginx
COPY nginx.conf.template /etc/nginx/templates/default.conf.template
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh \
  && chown nginx:nginx /docker-entrypoint.sh
COPY --from=builder /build/dist /usr/share/nginx/html
USER nginx
ENV BACKEND_HOST=backend-ventas
EXPOSE 8080
ENTRYPOINT ["/docker-entrypoint.sh"]
