#!/bin/bash

echo "Esperando MySQL en $DB_ENDPOINT:$DB_PORT..."

# Espera activa
until timeout 1 bash -c "echo > /dev/tcp/$DB_ENDPOINT/$DB_PORT" 2>/dev/null; do
  echo "MySQL no disponible aún..."
  sleep 3
done

echo "MySQL disponible, iniciando backend..."

java -jar app.jar
