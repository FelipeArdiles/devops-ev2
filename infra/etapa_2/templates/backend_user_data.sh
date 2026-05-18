#!/bin/bash
set -euo pipefail

yum update -y
yum install -y docker
systemctl enable docker
systemctl start docker

until docker info >/dev/null 2>&1; do sleep 2; done

# Plugin compose v2 en Amazon Linux 2023
mkdir -p /usr/local/lib/docker/cli-plugins
curl -fsSL "https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-linux-x86_64" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
ln -sf /usr/local/lib/docker/cli-plugins/docker-compose /usr/bin/docker-compose

mkdir -p /opt/app

cat >/opt/app/docker-compose.yml <<'COMPOSE'
services:
  backend-ventas:
    image: $${IMAGE_VENTAS}
    container_name: backend-ventas
    restart: unless-stopped
    ports:
      - "8080:8080"
    environment:
      DB_ENDPOINT: $${DB_ENDPOINT}
      DB_PORT: "3306"
      DB_NAME: $${DB_NAME}
      DB_USERNAME: root
      DB_PASSWORD: $${DB_PASSWORD}

  backend-despachos:
    image: $${IMAGE_DESPACHOS}
    container_name: backend-despachos
    restart: unless-stopped
    ports:
      - "8081:8081"
    environment:
      DB_ENDPOINT: $${DB_ENDPOINT}
      DB_PORT: "3306"
      DB_NAME: $${DB_NAME}
      DB_USERNAME: root
      DB_PASSWORD: $${DB_PASSWORD}
    depends_on:
      - backend-ventas
COMPOSE

cat >/opt/app/.env <<ENV
AWS_REGION=${aws_region}
ECR_REGISTRY=${ecr_registry}
DB_ENDPOINT=${db_endpoint}
DB_NAME=${db_name}
DB_PASSWORD=${db_password}
IMAGE_VENTAS=${image_ventas}
IMAGE_DESPACHOS=${image_despachos}
ENV

cat >/opt/app/deploy.sh <<'DEPLOY'
#!/bin/bash
set -euo pipefail
cd /opt/app
source /opt/app/.env
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"
docker compose pull || true
docker compose up -d --remove-orphans
docker image prune -f
DEPLOY

chmod +x /opt/app/deploy.sh

# Primer arranque cuando ya existan imagenes en ECR (pipeline o script local)
/opt/app/deploy.sh || echo "Esperando imagenes en ECR; ejecutar pipeline o deploy-evaluacion.sh"
