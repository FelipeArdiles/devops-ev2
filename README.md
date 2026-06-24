# DevOps U2 — ECS Fargate + Terraform + CI/CD

Sistema de **ventas** y **despachos** con Docker, Amazon ECR, **ECS Fargate**, **ALB** (routing por path), **NLB** interno para MySQL y **GitHub Actions**.

Repositorio: [FelipeArdiles/devops-ev2](https://github.com/FelipeArdiles/devops-ev2)

## Stack

| Capa | Tecnología |
|------|------------|
| Frontend | React + Vite + nginx |
| Backends | Spring Boot 17 (ventas :8080, despachos :8081) |
| Base de datos | MySQL 8 en ECS Fargate |
| Infra | Terraform `etapa_1` (ECR) + `etapa_3` (ECS/ALB) |
| CD | Push a rama `deploy` → build ECR → `force-new-deployment` ECS |

## Estructura

```
├── backend/ventas|despachos/
├── frontend/
├── infra/etapa_1|etapa_2|etapa_3/
├── .github/workflows/ci.yml|deploy.yml
├── docker-compose.yml
└── scripts/deploy-evaluacion.sh
```

## Local

```bash
cp .env.example .env
docker compose up --build
# http://localhost
```

## AWS (evaluación)

```bash
# 1. Start Lab + credenciales AWS en terminal
# 2. Terraform
cd infra/etapa_1 && terraform init && terraform apply
cd ../etapa_3
cp terraform.tfvars.example terraform.tfvars   # editar db_password
terraform init && terraform apply

# 3. Secret en GitHub: ECS_ALB_DNS_NAME = terraform output alb_dns_name
# 4. Push a rama deploy (o usar script)
./scripts/deploy-evaluacion.sh deploy
```

## URLs en producción

- Frontend: `http://<ALB_DNS>/`
- API ventas: `http://<ALB_DNS>/api/v1/ventas`
- API despachos: `http://<ALB_DNS>/api/v1/despachos`

## Gitflow

Ver [GITFLOW.md](GITFLOW.md): `feature/*` → `develop` → `main` → **`deploy`** (CD).

## Apagar recursos

```bash
./scripts/deploy-evaluacion.sh destroy
```
