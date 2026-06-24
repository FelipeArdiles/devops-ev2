#!/usr/bin/env bash
# Despliegue EP3: etapa_1 (ECR) + etapa_3 (ECS Fargate + ALB)
# Uso:
#   ./scripts/deploy-evaluacion.sh deploy
#   ./scripts/deploy-evaluacion.sh destroy
#   ./scripts/deploy-evaluacion.sh status

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ETAPA1_DIR="${ROOT_DIR}/infra/etapa_1"
ETAPA3_DIR="${ROOT_DIR}/infra/etapa_3"

[[ -f "${SCRIPT_DIR}/deploy.env" ]] && source "${SCRIPT_DIR}/deploy.env"
[[ -f "${ROOT_DIR}/.env" ]] && source "${ROOT_DIR}/.env"

AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${PROJECT_NAME:-devops-u2}"
CLUSTER_NAME="${CLUSTER_NAME:-devops-u2-cluster}"
DB_PASSWORD="${DB_PASSWORD:-root}"
DB_NAME="${DB_NAME:-proyecto_db}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }

need_cmd() { command -v "$1" >/dev/null || { err "Falta: $1"; exit 1; }; }

check_prereqs() {
  need_cmd aws
  need_cmd terraform
  need_cmd docker
  aws sts get-caller-identity --region "${AWS_REGION}" >/dev/null
  log "Cuenta: $(aws sts get-caller-identity --query Account --output text)"
}

tf_apply_etapa3() {
  (cd "${ETAPA3_DIR}" && terraform init -input=false)
  (cd "${ETAPA3_DIR}" && terraform apply -auto-approve \
    -var="db_password=${DB_PASSWORD}" \
    -var="db_name=${DB_NAME}" \
    -var="project_name=${PROJECT_NAME}")
}

tf_destroy_all() {
  for dir in "${ETAPA3_DIR}" "${ETAPA1_DIR}"; do
    [[ -d "${dir}" ]] || continue
    (cd "${dir}" && terraform init -input=false)
    if [[ "${dir}" == *etapa_3* ]]; then
      (cd "${dir}" && terraform destroy -auto-approve \
        -var="db_password=${DB_PASSWORD}" \
        -var="db_name=${DB_NAME}" \
        -var="project_name=${PROJECT_NAME}") || warn "Destroy etapa_3 con advertencias"
    else
      (cd "${dir}" && terraform destroy -auto-approve) || warn "Destroy etapa_1 con advertencias"
    fi
  done
}

ecr_login_build_push() {
  local account registry
  account="$(aws sts get-caller-identity --query Account --output text)"
  registry="${account}.dkr.ecr.${AWS_REGION}.amazonaws.com"
  aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${registry}"

  for svc in ventas despachos; do
    log "Build backend-${svc}..."
    docker build --platform linux/amd64 -t "${registry}/${PROJECT_NAME}-backend-${svc}:latest" "${ROOT_DIR}/backend/${svc}"
    docker push "${registry}/${PROJECT_NAME}-backend-${svc}:latest"
  done
  log "Build frontend..."
  docker build --platform linux/amd64 -t "${registry}/${PROJECT_NAME}-frontend:latest" "${ROOT_DIR}/frontend"
  docker push "${registry}/${PROJECT_NAME}-frontend:latest"
}

ecs_redeploy() {
  local mysql="${PROJECT_NAME}-mysql"
  local services=("${PROJECT_NAME}-frontend" "${PROJECT_NAME}-backend-ventas" "${PROJECT_NAME}-backend-despachos")
  log "Esperando MySQL estable..."
  aws ecs wait services-stable --cluster "${CLUSTER_NAME}" --services "${mysql}" --region "${AWS_REGION}" || true
  for s in "${services[@]}"; do
    aws ecs update-service --cluster "${CLUSTER_NAME}" --service "${s}" --force-new-deployment --region "${AWS_REGION}" >/dev/null
  done
  log "Redespliegue iniciado en ${CLUSTER_NAME}"
}

cmd_deploy() {
  check_prereqs
  log "=== Etapa 1: ECR ==="
  (cd "${ETAPA1_DIR}" && terraform init -input=false && terraform apply -auto-approve)
  log "=== Etapa 3: ECS + ALB ==="
  tf_apply_etapa3
  log "=== Im?genes + ECS ==="
  ecr_login_build_push
  ecs_redeploy
  local alb
  alb="$(cd "${ETAPA3_DIR}" && terraform output -raw alb_dns_name 2>/dev/null || true)"
  echo ""
  log "URL aplicaci?n: http://${alb:-<terraform output alb_dns_name>}/"
  warn "Configura secret ECS_ALB_DNS_NAME=${alb} en GitHub para el pipeline deploy.yml"
}

cmd_destroy() { check_prereqs; tf_destroy_all; log "Infra eliminada."; }

cmd_status() {
  check_prereqs
  aws ecs describe-services --cluster "${CLUSTER_NAME}" --region "${AWS_REGION}" \
    --services "${PROJECT_NAME}-frontend" "${PROJECT_NAME}-backend-ventas" "${PROJECT_NAME}-backend-despachos" "${PROJECT_NAME}-mysql" \
    --query 'services[].{name:serviceName,running:runningCount,desired:desiredCount}' --output table
  alb="$(cd "${ETAPA3_DIR}" && terraform output -raw application_url 2>/dev/null || echo '?')"
  echo "URL: ${alb}"
}

case "${1:-}" in
  deploy)  cmd_deploy ;;
  destroy) cmd_destroy ;;
  status)  cmd_status ;;
  *) echo "Uso: $0 {deploy|destroy|status}"; exit 1 ;;
esac
