# Proyecto Semestral - DevOps (EP2)

Arquitectura de microservicios contenedorizados con despliegue automatizado en **AWS EC2** y pipeline en **GitHub Actions** (rama `deploy`).

## Componentes

| Servicio | Tecnología | Despliegue |
|----------|------------|------------|
| Frontend | React + Vite + nginx | EC2 **pública** (puerto 80) |
| Backend Ventas | Spring Boot | EC2 **privada** |
| Backend Despachos | Spring Boot | EC2 **privada** |
| MySQL | Docker + volumen | EC2 **privada** |

Solo el **frontend** es accesible desde Internet. Los backends y MySQL están en subred privada; el frontend se comunica con ellos por IP privada (proxy nginx).

## Desarrollo local

Crea un `.env` en la raíz (o usa variables de entorno):

```env
DB_PASSWORD=root
DB_NAME=proyecto_db
```

```bash
docker compose up --build
```

- Frontend: http://localhost:3000
- API Ventas: http://localhost:8080
- API Despachos: http://localhost:8081

## Despliegue en AWS

### 1. Credenciales

```bash
aws configure
# o exporta AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN del lab
```

### 2. Infraestructura + primera imagen

```bash
cp scripts/deploy.env.example scripts/deploy.env
# Edita SSH_KEY_PATH si tu vockey.pem está en otra ruta

chmod +x scripts/deploy-evaluacion.sh
./scripts/deploy-evaluacion.sh deploy
```

El script ejecuta Terraform (etapa_1 ECR + etapa_2 VPC/EC2), construye las imágenes, las sube a ECR y despliega en las instancias EC2.

### 3. Secrets de GitHub Actions

En el repositorio → **Settings → Secrets and variables → Actions**:

| Secret | Descripción |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | Del AWS Academy Lab |
| `AWS_SECRET_ACCESS_KEY` | Del lab |
| `AWS_SESSION_TOKEN` | Del lab (obligatorio en sesiones temporales) |
| `AWS_ACCOUNT_ID` | ID de cuenta AWS |
| `EC2_SSH_PRIVATE_KEY` | Contenido completo del archivo `.pem` (vockey) |
| `EC2_FRONTEND_HOST` | IP pública del frontend (`terraform output frontend_public_ip`) |
| `EC2_BACKEND_PRIVATE_IP` | IP privada del backend (`terraform output backend_private_ip`) |

Tras cada `terraform apply` que cambie IPs, actualiza `EC2_FRONTEND_HOST` y `EC2_BACKEND_PRIVATE_IP`.

### 4. Pipeline CI/CD (rama `deploy`)

```bash
git checkout -b deploy
git push -u origin deploy
```

Cada push a `deploy` ejecuta: build → push ECR → SSH deploy backend (vía bastión) → SSH deploy frontend.

Para integrar cambios desde `main`:

```bash
git checkout deploy
git merge main
git push origin deploy
```

## Comandos útiles

```bash
./scripts/deploy-evaluacion.sh status    # IPs y verificación HTTP
./scripts/deploy-evaluacion.sh pipeline  # Solo rebuild + redespliegue
./scripts/deploy-evaluacion.sh destroy   # Elimina recursos AWS
```

## Estructura infra

- `infra/etapa_1/` — Repositorios ECR
- `infra/etapa_2/` — VPC, subred pública/privada, NAT, 3 EC2, security groups

## Buenas prácticas implementadas (rúbrica EP2)

- Dockerfiles **multi-stage**
- Contenedores con **usuario no root**
- `docker-compose` con **redes**, **volúmenes** y healthchecks
- Persistencia MySQL con **volumen Docker** en EC2
- Pipeline: build, **ECR**, despliegue automático en **EC2**
- Rama **`deploy`** como disparador del workflow
