#!/usr/bin/env bash
# Создаёт отдельный локальный центр сертификации и сертификаты сервисов Corelia.
set -euo pipefail
cd "$(dirname "$0")/.."
umask 077
if [[ -f .local/certs/.ready ]]; then
  echo 'Локальные сертификаты уже созданы.'
  exit 0
fi
if [[ -d .local/certs ]]; then
  echo 'Обнаружена незавершённая генерация. Переместите .local/certs и повторите запуск.' >&2
  exit 1
fi
mkdir -p .local/certs/ca .local/secrets
openssl rand -hex 24 | tr -d '\n' > .local/secrets/corelia.tls.password
openssl req -x509 -newkey rsa:3072 -sha256 -nodes -days 365 -subj '/CN=Corelia Local CA' \
  -keyout .local/certs/ca/ca.key -out .local/certs/ca/ca.crt 2>/dev/null
keytool_bin="${JAVA_HOME:+$JAVA_HOME/bin/}keytool"
for service in corelia-gateway corelia-auth corelia-document-service corelia-workflow-service corelia-attachment-service; do
  destination=".local/certs/$service"
  mkdir -p "$destination"
  openssl req -newkey rsa:2048 -nodes -subj "/CN=$service" -keyout "$destination/client.key" -out "$destination/client.csr" 2>/dev/null
  cat > "$destination/extensions.cnf" <<EOF
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth,clientAuth
subjectAltName=DNS:$service,DNS:localhost,IP:127.0.0.1
EOF
  openssl x509 -req -in "$destination/client.csr" -CA .local/certs/ca/ca.crt -CAkey .local/certs/ca/ca.key \
    -CAcreateserial -days 90 -sha256 -extfile "$destination/extensions.cnf" -out "$destination/client.crt" 2>/dev/null
  openssl pkcs12 -export -name "$service" -in "$destination/client.crt" -inkey "$destination/client.key" \
    -certfile .local/certs/ca/ca.crt -out "$destination/identity.p12" -passout file:.local/secrets/corelia.tls.password
  "$keytool_bin" -importcert -noprompt -alias corelia-ca -file .local/certs/ca/ca.crt \
    -keystore "$destination/trust.p12" -storetype PKCS12 -storepass:file .local/secrets/corelia.tls.password >/dev/null 2>&1
  cp .local/certs/ca/ca.crt "$destination/ca.crt"
  rm "$destination/client.csr" "$destination/extensions.cnf"
done
touch .local/certs/.ready
printf '%s\n' 'Сертификаты созданы на 90 дней. Закрытый ключ CA не передаётся контейнерам.'
