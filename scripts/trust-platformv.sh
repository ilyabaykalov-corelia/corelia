#!/usr/bin/env bash
# Добавляет сертификат Platform V к стандартным доверенным CA Java из образа Corelia.
set -euo pipefail
cd "$(dirname "$0")/.."
certificate="${1:?Использование: ./scripts/trust-platformv.sh /путь/platform-v.crt}"
certificate="$(cd "$(dirname "$certificate")" && pwd)/$(basename "$certificate")"
[[ -f "$certificate" ]] || { echo "Нет файла: $certificate" >&2; exit 1; }
mkdir -p .local/platformv
stage="$(mktemp -d "$PWD/.local/platformv/import.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
cp "$certificate" "$stage/platformv.crt"
docker run --rm --network none --read-only --cap-drop ALL \
  --security-opt no-new-privileges:true \
  --user "$(id -u):$(id -g)" \
  --mount "type=bind,source=$stage,target=/import" \
  --entrypoint sh corelia/auth:local -ec '
    cp "$JAVA_HOME/lib/security/cacerts" /import/cacerts
    keytool -importcert -noprompt -alias corelia-platformv \
      -file /import/platformv.crt -keystore /import/cacerts -storepass changeit
  '
mv "$stage/cacerts" .local/platformv/cacerts
echo 'Хранилище готово. Применить: ./scripts/up.sh --debug (или без --debug).'
