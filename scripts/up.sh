#!/usr/bin/env bash
# Собирает и запускает только контейнеры проекта Corelia.
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/init-local.sh
if [[ ! -f .env ]]; then
  cp .env.example .env
  chmod 600 .env
  echo 'Создан .env. Заполните адреса платформы; без них доступны только проверки запуска.'
fi
export CORELIA_UID="$(id -u)" CORELIA_GID="$(id -g)"
compose_args=()
compose_files=(-f compose.yaml)
if [[ -f .local/platformv/cacerts ]]; then
  compose_files+=(-f compose.platformv-tls.yaml)
fi
skip_tests="${CORELIA_SKIP_TESTS:-true}"
for arg in "$@"; do
  case "$arg" in
    --debug) compose_files+=(-f compose.debug.yaml) ;;
    --skip-tests|--no-tests) skip_tests=true ;;
    *) compose_args+=("$arg") ;;
  esac
done
export CORELIA_SKIP_TESTS="$skip_tests"
if ((${#compose_args[@]} > 0)); then
  docker compose "${compose_files[@]}" up --build --wait --wait-timeout 240 "${compose_args[@]}"
else
  docker compose "${compose_files[@]}" up --build --wait --wait-timeout 240
fi
echo 'Сервисы Corelia готовы. Для просмотра событий: docker compose logs -f'
