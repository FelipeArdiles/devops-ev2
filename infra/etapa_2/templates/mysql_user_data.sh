#!/bin/bash
set -euo pipefail

yum update -y
yum install -y docker
systemctl enable docker
systemctl start docker

until docker info >/dev/null 2>&1; do sleep 2; done

mkdir -p /usr/local/lib/docker/cli-plugins
curl -fsSL "https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-linux-x86_64" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
ln -sf /usr/local/lib/docker/cli-plugins/docker-compose /usr/bin/docker-compose

mkdir -p /opt/mysql
cat >/opt/mysql/docker-compose.yml <<'COMPOSE'
services:
  mysql:
    image: mysql:8
    container_name: mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: $${DB_PASSWORD}
      MYSQL_DATABASE: $${DB_NAME}
      MYSQL_ROOT_HOST: "%"
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 10

volumes:
  mysql_data:
COMPOSE

cat >/opt/mysql/.env <<ENV
DB_PASSWORD=${db_password}
DB_NAME=${db_name}
ENV

cd /opt/mysql
docker compose --env-file .env up -d
