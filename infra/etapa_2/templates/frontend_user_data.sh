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

mkdir -p /opt/app

cat >/opt/app/docker-compose.yml <<'COMPOSE'
services:
  frontend:
    image: $${IMAGE_FRONTEND}
    container_name: frontend
    restart: unless-stopped
    ports:
      - "80:8080"
    environment:
      BACKEND_HOST: $${BACKEND_HOST}
      BACKEND_HOST_DESPACHOS: $${BACKEND_HOST_DESPACHOS}
COMPOSE

cat >/opt/app/.env <<ENV
AWS_REGION=${aws_region}
ECR_REGISTRY=${ecr_registry}
BACKEND_HOST=${backend_host}
BACKEND_HOST_DESPACHOS=${backend_host}
IMAGE_FRONTEND=${image_frontend}
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

/opt/app/deploy.sh || echo "Esperando imagen frontend en ECR; ejecutar pipeline o deploy-evaluacion.sh"
