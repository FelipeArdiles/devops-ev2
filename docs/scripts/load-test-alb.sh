#!/usr/bin/env bash
# Simula carga HTTP contra el ALB para evidenciar autoscaling en ECS.
# Uso: ./scripts/load-test-alb.sh <dns-del-alb> [duracion_segundos]

set -euo pipefail

ALB_DNS="${1:?Uso: $0 <dns-alb> [segundos]}"
DURATION="${2:-120}"
BASE_URL="http://${ALB_DNS}"

echo "Simulando carga en ${BASE_URL} durante ${DURATION}s..."
echo "Monitorea autoscaling en: ECS > Clusters > devops-u2-cluster > Services"

END=$((SECONDS + DURATION))
REQUESTS=0

while [ "$SECONDS" -lt "$END" ]; do
  curl -sf "${BASE_URL}/api/v1/ventas" > /dev/null &
  curl -sf "${BASE_URL}/api/v1/despachos" > /dev/null &
  curl -sf "${BASE_URL}/" > /dev/null &
  REQUESTS=$((REQUESTS + 3))
  sleep 0.5
done

wait
echo "Completado: ${REQUESTS} solicitudes enviadas."
echo "Revisa CloudWatch > Container Insights y ECS Service Auto Scaling."
