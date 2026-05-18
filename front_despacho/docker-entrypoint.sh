#!/bin/sh
set -eu

BACKEND_HOST="${BACKEND_HOST:-backend-ventas}"
BACKEND_HOST_DESPACHOS="${BACKEND_HOST_DESPACHOS:-$BACKEND_HOST}"
export BACKEND_HOST BACKEND_HOST_DESPACHOS

envsubst '${BACKEND_HOST} ${BACKEND_HOST_DESPACHOS}' \
  < /etc/nginx/templates/default.conf.template \
  > /etc/nginx/conf.d/default.conf

exec nginx -g 'daemon off;'
