#!/bin/sh

echo "Esperando MySQL en $DB_ENDPOINT:$DB_PORT..."

# Espera activa
until nc -z $DB_ENDPOINT $DB_PORT; do
  echo "MySQL no disponible aún..."
  sleep 3
done

echo "MySQL disponible, iniciando backend ventas..."

java -jar app.jar
