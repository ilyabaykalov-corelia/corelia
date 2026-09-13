#!/usr/bin/env bash
# Останавливает только сервисы проекта Corelia, не затрагивая платформу и другие проекты.
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose down
