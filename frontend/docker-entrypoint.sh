#!/bin/sh
set -e

if [ -n "$BACKEND_HOST" ]; then
  echo "Configurando nginx para EC2 con backend en ${BACKEND_HOST}"
  export BACKEND_HOST
  envsubst '$BACKEND_HOST' < /etc/nginx/templates/nginx.ec2.conf.template \
    > /etc/nginx/conf.d/default.conf
elif [ "${NGINX_COMPOSE_MODE:-}" = "1" ]; then
  echo "Configurando nginx para Docker Compose local"
  cp /etc/nginx/templates/nginx.local.conf /etc/nginx/conf.d/default.conf
else
  echo "Configurando nginx para ALB/ECS (solo estaticos; APIs en el balanceador)"
  cp /etc/nginx/templates/nginx.alb.conf /etc/nginx/conf.d/default.conf
fi

chown 101:101 /etc/nginx/conf.d/default.conf
exec /usr/sbin/nginx -g 'daemon off;'
