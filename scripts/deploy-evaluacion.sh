#!/usr/bin/env bash
# Despliegue completo para evaluación EP2 (EC2 + ECR).
# Uso:
#   ./scripts/deploy-evaluacion.sh deploy    # Infra + imágenes + EC2
#   ./scripts/deploy-evaluacion.sh destroy  # Apaga todo en AWS
#   ./scripts/deploy-evaluacion.sh status    # Estado e IPs
#   ./scripts/deploy-evaluacion.sh pipeline # Solo imágenes + redespliegue EC2
#
# Requisitos: aws cli, terraform, docker, credenciales AWS del lab activas.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ETAPA1_DIR="${ROOT_DIR}/infra/etapa_1"
ETAPA2_DIR="${ROOT_DIR}/infra/etapa_2"

# shellcheck source=/dev/null
[[ -f "${SCRIPT_DIR}/deploy.env" ]] && source "${SCRIPT_DIR}/deploy.env"
# shellcheck source=/dev/null
[[ -f "${ROOT_DIR}/.env" ]] && source "${ROOT_DIR}/.env"

AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${PROJECT_NAME:-devops-u2}"
DB_USER="${DB_USER:-root}"
DB_PASSWORD="${DB_PASSWORD:-root}"
DB_NAME="${DB_NAME:-proyecto_db}"
KEY_PAIR_NAME="${KEY_PAIR_NAME:-vockey}"
SSH_KEY_PATH="${SSH_KEY_PATH:-${HOME}/.ssh/vockey.pem}"
MYSQL_READY_TIMEOUT="${MYSQL_READY_TIMEOUT:-300}"
APP_READY_TIMEOUT="${APP_READY_TIMEOUT:-600}"

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
    err "Credenciales AWS no válidas. Ejecuta aws configure o exporta las keys del lab."
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
  log "Terraform destroy en ${dir}..."
  (cd "${dir}" && terraform init -input=false)
  if [[ "${dir}" == *etapa_2* ]]; then
    # shellcheck disable=SC2046
    (cd "${dir}" && terraform destroy -auto-approve $(tf_vars_etapa2)) || warn "Destroy etapa_2 con advertencias."
  else
    (cd "${dir}" && terraform destroy -auto-approve) || warn "Destroy etapa_1 con advertencias."
  fi
}

clean_local_state() {
  warn "Eliminando terraform.tfstate local..."
  rm -f "${ETAPA1_DIR}"/terraform.tfstate "${ETAPA1_DIR}"/terraform.tfstate.backup
  rm -f "${ETAPA2_DIR}"/terraform.tfstate "${ETAPA2_DIR}"/terraform.tfstate.backup
}

get_tf_output() {
  local name="$1"
  (cd "${ETAPA2_DIR}" && terraform output -raw "${name}" 2>/dev/null) || true
}

wait_for_tcp() {
  local host="$1" port="$2" timeout="${3:-300}"
  local elapsed=0
  log "Esperando ${host}:${port} (máx ${timeout}s)..."
  while (( elapsed < timeout )); do
    if (echo >"/dev/tcp/${host}/${port}") >/dev/null 2>&1; then
      log "Puerto ${port} disponible en ${host}."
      return 0
    fi
    sleep 5
    elapsed=$((elapsed + 5))
    echo -n "."
  done
  echo ""
  return 1
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
  local registry="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

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

ssh_opts() {
  echo -o StrictHostKeyChecking=no -o ConnectTimeout=15 -i "${SSH_KEY_PATH}"
}

deploy_remote() {
  local frontend_ip="$1"
  local backend_ip="$2"

  if [[ ! -f "${SSH_KEY_PATH}" ]]; then
    err "No se encontró la llave SSH: ${SSH_KEY_PATH}"
    err "Ajusta SSH_KEY_PATH en scripts/deploy.env"
    exit 1
  fi
  chmod 600 "${SSH_KEY_PATH}" 2>/dev/null || true

  eval "$(ssh-agent -s)" >/dev/null
  ssh-add "${SSH_KEY_PATH}"

  log "Esperando cloud-init en instancias (60s)..."
  sleep 60

  log "Desplegando backends en ${backend_ip} vía bastión ${frontend_ip}..."
  local proxy_cmd="ssh -i ${SSH_KEY_PATH} -o StrictHostKeyChecking=no -W %h:%p ec2-user@${frontend_ip}"
  # shellcheck disable=SC2046
  ssh $(ssh_opts) -o "ProxyCommand=${proxy_cmd}" \
    "ec2-user@${backend_ip}" 'sudo /opt/app/deploy.sh'

  log "Desplegando frontend en ${frontend_ip} (backend ${backend_ip})..."
  # shellcheck disable=SC2046
  ssh $(ssh_opts) "ec2-user@${frontend_ip}" \
    "sudo sed -i 's/^BACKEND_HOST=.*/BACKEND_HOST=${backend_ip}/' /opt/app/.env && \
     sudo sed -i 's/^BACKEND_HOST_DESPACHOS=.*/BACKEND_HOST_DESPACHOS=${backend_ip}/' /opt/app/.env && \
     sudo /opt/app/deploy.sh"
}

wait_for_http() {
  local url="$1"
  local elapsed=0
  log "Esperando HTTP en ${url} (máx ${APP_READY_TIMEOUT}s)..."
  while (( elapsed < APP_READY_TIMEOUT )); do
    if curl -sf --connect-timeout 5 "${url}" >/dev/null 2>&1; then
      log "Aplicación lista: ${url}"
      return 0
    fi
    sleep 10
    elapsed=$((elapsed + 10))
    echo -n "."
  done
  echo ""
  warn "La app no respondió HTTP 200 a tiempo."
  return 1
}

print_github_secrets() {
  local frontend_ip backend_ip account_id
  frontend_ip="$(get_tf_output frontend_public_ip)"
  backend_ip="$(get_tf_output backend_private_ip)"
  account_id="$(aws sts get-caller-identity --query Account --output text)"

  echo ""
  log "=== Secrets para GitHub Actions (rama deploy) ==="
  echo "  AWS_ACCESS_KEY_ID          = (del lab)"
  echo "  AWS_SECRET_ACCESS_KEY      = (del lab)"
  echo "  AWS_SESSION_TOKEN          = (del lab, si aplica)"
  echo "  AWS_ACCOUNT_ID             = ${account_id}"
  echo "  EC2_SSH_PRIVATE_KEY        = contenido de ${SSH_KEY_PATH}"
  echo "  EC2_FRONTEND_HOST          = ${frontend_ip}"
  echo "  EC2_BACKEND_PRIVATE_IP     = ${backend_ip}"
  echo ""
  warn "Haz push a la rama 'deploy' para disparar el pipeline CI/CD."
}

cmd_deploy() {
  local fresh=false
  [[ "${1:-}" == "--fresh" ]] && fresh=true

  check_prereqs
  [[ "${fresh}" == "true" ]] && clean_local_state

  log "=== Etapa 1: ECR ==="
  terraform_init_apply "${ETAPA1_DIR}"

  log "=== Etapa 2: VPC + EC2 (MySQL, Backend, Frontend) ==="
  terraform_init_apply "${ETAPA2_DIR}"

  local mysql_ip backend_ip frontend_ip
  mysql_ip="$(get_tf_output mysql_private_ip)"
  backend_ip="$(get_tf_output backend_private_ip)"
  frontend_ip="$(get_tf_output frontend_public_ip)"

  wait_for_tcp "${mysql_ip}" 3306 "${MYSQL_READY_TIMEOUT}" || {
    err "MySQL no respondió. Revisa la instancia ${PROJECT_NAME}-mysql."
    exit 1
  }

  log "=== Imágenes Docker + despliegue EC2 ==="
  ecr_login
  build_and_push_images
  deploy_remote "${frontend_ip}" "${backend_ip}"
  wait_for_http "http://${frontend_ip}/" || true

  echo ""
  log "=== Resumen ==="
  echo "  Frontend (Internet): http://${frontend_ip}/"
  echo "  Backend (privado):   ${backend_ip}"
  echo "  MySQL (privado):     ${mysql_ip}"
  print_github_secrets
}

cmd_destroy() {
  check_prereqs
  log "=== Destruyendo infraestructura ==="
  terraform_destroy "${ETAPA2_DIR}"
  terraform_destroy "${ETAPA1_DIR}"
  log "Recursos eliminados."
}

cmd_pipeline() {
  check_prereqs
  local frontend_ip backend_ip
  frontend_ip="$(get_tf_output frontend_public_ip)"
  backend_ip="$(get_tf_output backend_private_ip)"
  if [[ -z "${frontend_ip}" || -z "${backend_ip}" ]]; then
    err "No hay outputs de Terraform. Ejecuta primero: ./scripts/deploy-evaluacion.sh deploy"
    exit 1
  fi
  ecr_login
  build_and_push_images
  deploy_remote "${frontend_ip}" "${backend_ip}"
  wait_for_http "http://${frontend_ip}/" || true
  log "App: http://${frontend_ip}/"
}

cmd_redeploy() {
  check_prereqs
  local frontend_ip backend_ip
  frontend_ip="$(get_tf_output frontend_public_ip)"
  backend_ip="$(get_tf_output backend_private_ip)"
  if [[ -z "${frontend_ip}" || -z "${backend_ip}" ]]; then
    err "No hay outputs de Terraform."
    exit 1
  fi
  log "Redespliegue SSH (sin rebuild Docker)..."
  deploy_remote "${frontend_ip}" "${backend_ip}"
  wait_for_http "http://${frontend_ip}/" || true
  log "App: http://${frontend_ip}/"
}

cmd_status() {
  check_prereqs
  local frontend_ip backend_ip mysql_ip
  frontend_ip="$(get_tf_output frontend_public_ip)"
  backend_ip="$(get_tf_output backend_private_ip)"
  mysql_ip="$(get_tf_output mysql_private_ip)"

  echo "Frontend público:  ${frontend_ip:-?}  -> http://${frontend_ip:-}/"
  echo "Backend privado:   ${backend_ip:-?}"
  echo "MySQL privado:     ${mysql_ip:-?}"

  if [[ -n "${frontend_ip}" && "${frontend_ip}" != "?" ]]; then
    curl -sf --connect-timeout 5 -o /dev/null -w "HTTP frontend: %{http_code}\n" \
      "http://${frontend_ip}/" || warn "Frontend no responde HTTP."
  fi
  print_github_secrets
}

main() {
  local cmd="${1:-}"
  shift || true
  case "${cmd}" in
    deploy)   cmd_deploy "$@" ;;
    destroy)  cmd_destroy ;;
    pipeline) cmd_pipeline ;;
    redeploy) cmd_redeploy ;;
    status)   cmd_status ;;
    -h|--help|help|"") usage ;;
    *)
      err "Comando desconocido: ${cmd}"
      usage 1
      ;;
  esac
}

main "$@"
