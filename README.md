# Proyecto Semestral - DevOps

Este es el proyecto semestral para la asignatura de DevOps.

## Arquitectura
El proyecto utiliza una arquitectura de microservicios:
- **Backend Ventas**: Spring Boot (Java 17)
- **Backend Despachos**: Spring Boot (Java 17)
- **Frontend**: Vite / React (Node 20)
- **Base de Datos**: MySQL 8

## Despliegue con Docker Compose
Para ejecutar el proyecto de forma local:

```bash
docker-compose up --build
```

Esto levantará los contenedores de los backends, frontend y la base de datos MySQL de forma orquestada.
