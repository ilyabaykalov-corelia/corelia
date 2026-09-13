#!/usr/bin/env bash
# Системные тесты используют имитацию платформы и не меняют данные рабочего стенда.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -z "${JAVA_HOME:-}" && -d /opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home ]]; then
  export JAVA_HOME=/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home
fi
./scripts/init-local.sh
exec mvn -B -ntp verify "$@"
