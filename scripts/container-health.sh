#!/usr/bin/env sh
# Проверяет собственный сервис; ключи других сервисов контейнеру недоступны.
set -eu
if [ "$CORELIA_SERVICE" = corelia-gateway ]; then
  exec curl -fsS --max-time 4 http://localhost:7170/api/core/v1/health
fi
exec curl -fsS --max-time 4 --cacert /run/corelia/certs/ca.crt \
  --cert /run/corelia/certs/client.crt --key /run/corelia/certs/client.key https://localhost:8443/internal/v1/health
