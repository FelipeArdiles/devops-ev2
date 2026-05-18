#!/usr/bin/env bash
# Despliegue completo para evaluación (AWS Academy / lab educativo).
# Uso:
#   ./scripts/deploy-evaluacion.sh deploy    # Infra + imágenes + ECS
#   ./scripts/deploy-evaluacion.sh destroy   # Apaga todo en AWS
#   ./scripts/deploy-evaluacion.sh status    # Estado del servicio e IP
#   ./scripts/deploy-evaluacion.sh pipeline  # Solo imágenes + redespliegue (infra ya existe)
#
# Requisitos: aws cli, terraform, docker, credenciales AWS del lab activas.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ETAPA1_DIR="${ROOT_DIR}/infra/etapa_1"
ETAPA2_DIR="${ROOT_DIR}/infra/etapa_2"

# shellcheck source=/dev/null
[[ -f "${SCRIPT_DIR}/deploy.env" ]] && source "${SCRIPT_DIR}/deploy.env"
[[ -f "${ROOT_DIR}/.env" ]] && source "${ROOT_DIR}/.env"

AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${PROJECT_NAME:-devops-u2}"
CLUSTER_NAME="${CLUSTER_NAME:-devops-u2-cluster}"
SERVICE_NAME="${SERVICE_NAME:-app}"
DB_USER="${DB_USER:-root}"
DB_PASSWORD="${DB_PASSWORD:-root}"
DB_NAME="${DB_NAME:-proyecto_db}"
KEY_PAIR_NAME="${KEY_PAIR_NAME:-vockey}"
MYSQL_READY_TIMEOUT="${MYSQL_READY_TIMEOUT:-300}"
ECS_READY_TIMEOUT="${ECS_READY_TIMEOUT:-600}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }

usage() {
  sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { err "Falta el comando: $1"; exit 1; }
}

check_prereqs() {
  need_cmd aws
  need_cmd terraform
  need_cmd docker
  if ! aws sts get-caller-identity --region "${AWS_REGION}" >/dev/null 2>&1; then
    err "Credenciales AWS no válidas. Inicia el lab y exporta keys + session token."
    exit 1
  fi
  log "Cuenta AWS: $(aws sts get-caller-identity --query Account --output text)"
}

tf_vars_etapa2() {
  echo -var="db_user=${DB_USER}" \
       -var="db_password=${DB_PASSWORD}" \
       -var="db_name=${DB_NAME}" \
       -var="key_pair_name=${KEY_PAIR_NAME}"
}

terraform_init_apply() {
  local dir="$1"
  log "Terraform init en ${dir}..."
  (cd "${dir}" && terraform init -input=false)
  log "Terraform apply en ${dir}..."
  if [[ "${dir}" == *etapa_2* ]]; then
    # shellcheck disable=SC2046
    (cd "${dir}" && terraform apply -auto-approve $(tf_vars_etapa2))
  else
    (cd "${dir}" && terraform apply -auto-approve)
  fi
}

terraform_destroy() {
  local dir="$1"
  if [[ ! -d "${dir}" ]]; then
    return 0
  fi
  log "Terraform destroy en ${dir}..."
  (cd "${dir}" && terraform init -input=false)
  if [[ "${dir}" == *etapa_2* ]]; then
    # shellcheck disable=SC2046
    (cd "${dir}" && terraform destroy -auto-approve $(tf_vars_etapa2)) || warn "Destroy etapa_2 con advertencias (puede estar vacío)."
  else
    (cd "${dir}" && terraform destroy -auto-approve) || warn "Destroy etapa_1 con advertencias (puede estar vacío)."
  fi
}

clean_local_state() {
  warn "Eliminando terraform.tfstate local (útil tras reset del lab)..."
  rm -f "${ETAPA1_DIR}"/terraform.tfstate "${ETAPA1_DIR}"/terraform.tfstate.backup
  rm -f "${ETAPA2_DIR}"/terraform.tfstate "${ETAPA2_DIR}"/terraform.tfstate.backup
}

get_mysql_private_ip() {
  aws ec2 describe-instances \
    --region "${AWS_REGION}" \
    --filters "Name=tag:Name,Values=${PROJECT_NAME}-mysql" "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' \
    --output text 2>/dev/null || true
}

wait_for_mysql() {
  local host="$1"
  local port=3306
  local elapsed=0
  log "Esperando MySQL en ${host}:${port} (máx ${MYSQL_READY_TIMEOUT}s)..."
  while (( elapsed < MYSQL_READY_TIMEOUT )); do
    if (echo >"/dev/tcp/${host}/${port}") >/dev/null 2>&1; then
      log "MySQL responde en el puerto ${port}."
      return 0
    fi
    sleep 5
    elapsed=$((elapsed + 5))
    echo -n "."
  done
  echo ""
  err "MySQL no respondió a tiempo. Revisa la EC2 ${PROJECT_NAME}-mysql en la consola."
  exit 1
}

ecr_login() {
  local account_id
  account_id="$(aws sts get-caller-identity --query Account --output text)"
  export AWS_ACCOUNT_ID="${account_id}"
  log "Login en ECR (${account_id})..."
  aws ecr get-login-password --region "${AWS_REGION}" \
    | docker login --username AWS --password-stdin \
      "${account_id}.dkr.ecr.${AWS_REGION}.amazonaws.com"
}

build_and_push_images() {
  local account_id="${AWS_ACCOUNT_ID}"
  local registry="${account_id}.dkr.ecr.${AWS_REGION}.amazonaws.com"

  log "Build y push backend ventas..."
  docker build --platform linux/amd64 \
    -t "${registry}/${PROJECT_NAME}-backend-ventas:latest" \
    "${ROOT_DIR}/back-Ventas_SpringBoot/Springboot-API-REST"
  docker push "${registry}/${PROJECT_NAME}-backend-ventas:latest"

  log "Build y push backend despachos..."
  docker build --platform linux/amd64 \
    -t "${registry}/${PROJECT_NAME}-backend-despachos:latest" \
    "${ROOT_DIR}/back-Despachos_SpringBoot/Springboot-API-REST-DESPACHO"
  docker push "${registry}/${PROJECT_NAME}-backend-despachos:latest"

  log "Build y push frontend..."
  docker build --platform linux/amd64 \
    -t "${registry}/${PROJECT_NAME}-frontend:latest" \
    "${ROOT_DIR}/front_despacho"
  docker push "${registry}/${PROJECT_NAME}-frontend:latest"
}

ecs_force_deploy() {
  log "Redespliegue forzado en ECS (${CLUSTER_NAME}/${SERVICE_NAME})..."
  aws ecs update-service \
    --region "${AWS_REGION}" \
    --cluster "${CLUSTER_NAME}" \
    --service "${SERVICE_NAME}" \
    --force-new-deployment \
    --output text \
    --query 'service.serviceName' >/dev/null
}

get_task_public_ip() {
  local task_arn eni_id
  task_arn="$(aws ecs list-tasks \
    --region "${AWS_REGION}" \
    --cluster "${CLUSTER_NAME}" \
    --service-name "${SERVICE_NAME}" \
    --desired-status RUNNING \
    --query 'taskArns[0]' \
    --output text 2>/dev/null || true)"
  [[ -z "${task_arn}" || "${task_arn}" == "None" ]] && return 1
  eni_id="$(aws ecs describe-tasks \
    --region "${AWS_REGION}" \
    --cluster "${CLUSTER_NAME}" \
    --tasks "${task_arn}" \
    --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value | [0]' \
    --output text)"
  aws ec2 describe-network-interfaces \
    --region "${AWS_REGION}" \
    --network-interface-ids "${eni_id}" \
    --query 'NetworkInterfaces[0].Association.PublicIp' \
    --output text
}

wait_for_ecs() {
  local elapsed=0
  log "Esperando task ECS healthy (máx ${ECS_READY_TIMEOUT}s)..."
  while (( elapsed < ECS_READY_TIMEOUT )); do
    local running
    running="$(aws ecs describe-services \
      --region "${AWS_REGION}" \
      --cluster "${CLUSTER_NAME}" \
      --services "${SERVICE_NAME}" \
      --query 'services[0].runningCount' \
      --output text 2>/dev/null || echo 0)"
    if [[ "${running}" == "1" ]]; then
      local health
      health="$(aws ecs describe-services \
        --region "${AWS_REGION}" \
        --cluster "${CLUSTER_NAME}" \
        --services "${SERVICE_NAME}" \
        --query 'services[0].events[0].message' \
        --output text 2>/dev/null || true)"
      local ip
      if ip="$(get_task_public_ip 2>/dev/null)" && [[ -n "${ip}" && "${ip}" != "None" ]]; then
        if curl -sf --connect-timeout 5 "http://${ip}/" >/dev/null 2>&1; then
          log "Servicio listo en http://${ip}/"
          return 0
        fi
      fi
    fi
    sleep 10
    elapsed=$((elapsed + 10))
    echo -n "."
  done
  echo ""
  warn "ECS aún no respondió HTTP 200. Revisa logs en CloudWatch: /ecs/${PROJECT_NAME}"
  return 1
}

cmd_deploy() {
  local fresh=false
  [[ "${1:-}" == "--fresh" ]] && fresh=true

  check_prereqs
  if [[ "${fresh}" == "true" ]]; then
    clean_local_state
  fi

  log "=== Etapa 1: ECR ==="
  terraform_init_apply "${ETAPA1_DIR}"

  log "=== Etapa 2: VPC + MySQL + ECS ==="
  terraform_init_apply "${ETAPA2_DIR}"

  local mysql_private
  mysql_private="$(get_mysql_private_ip)"
  if [[ -z "${mysql_private}" || "${mysql_private}" == "None" ]]; then
    err "No se obtuvo IP privada de MySQL. Revisa la instancia ${PROJECT_NAME}-mysql."
    exit 1
  fi
  wait_for_mysql "${mysql_private}"

  log "=== Imágenes Docker + ECS ==="
  ecr_login
  build_and_push_images
  ecs_force_deploy
  wait_for_ecs || true

  echo ""
  log "=== Resumen ==="
  echo "  Cluster:  ${CLUSTER_NAME}"
  echo "  Servicio: ${SERVICE_NAME}"
  echo "  MySQL EC2 (pública): $(cd "${ETAPA2_DIR}" && terraform output -raw mysql_ip 2>/dev/null || echo '?')"
  local url_ip
  url_ip="$(get_task_public_ip 2>/dev/null || echo '?')"
  echo "  App (frontend):      http://${url_ip}/"
  echo ""
  warn "Actualiza los secrets de GitHub Actions si también usarás el pipeline desde GitHub."
}

cmd_destroy() {
  check_prereqs
  log "=== Destruyendo infraestructura ==="
  terraform_destroy "${ETAPA2_DIR}"
  terraform_destroy "${ETAPA1_DIR}"
  log "Recursos eliminados. Puedes resetear el lab sin problema."
}

cmd_pipeline() {
  check_prereqs
  ecr_login
  build_and_push_images
  ecs_force_deploy
  wait_for_ecs || true
  local ip
  ip="$(get_task_public_ip 2>/dev/null || echo '?')"
  log "App: http://${ip}/"
}

cmd_status() {
  check_prereqs
  local running desired
  running="$(aws ecs describe-services \
    --region "${AWS_REGION}" \
    --cluster "${CLUSTER_NAME}" \
    --services "${SERVICE_NAME}" \
    --query 'services[0].runningCount' \
    --output text 2>/dev/null || echo '?')"
  desired="$(aws ecs describe-services \
    --region "${AWS_REGION}" \
    --cluster "${CLUSTER_NAME}" \
    --services "${SERVICE_NAME}" \
    --query 'services[0].desiredCount' \
    --output text 2>/dev/null || echo '?')"
  echo "ECS ${CLUSTER_NAME}/${SERVICE_NAME}: ${running}/${desired} tasks"
  aws ecs describe-services \
    --region "${AWS_REGION}" \
    --cluster "${CLUSTER_NAME}" \
    --services "${SERVICE_NAME}" \
    --query 'services[0].events[0:3].message' \
    --output table 2>/dev/null || true
  local ip
  if ip="$(get_task_public_ip 2>/dev/null)"; then
    echo "URL: http://${ip}/"
    curl -sf --connect-timeout 5 -o /dev/null -w "HTTP: %{http_code}\n" "http://${ip}/" || true
  else
    warn "No hay task RUNNING con IP pública."
  fi
}

main() {
  local cmd="${1:-}"
  shift || true
  case "${cmd}" in
    deploy)   cmd_deploy "$@" ;;
    destroy)  cmd_destroy ;;
    pipeline) cmd_pipeline ;;
    status)   cmd_status ;;
    -h|--help|help|"") usage ;;
    *)
      err "Comando desconocido: ${cmd}"
      usage 1
      ;;
  esac
}

main "$@"
