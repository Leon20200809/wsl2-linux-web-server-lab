#!/usr/bin/env bash
set -Eeuo pipefail

# .envのPROJECT_DIRを元に、公開用ディレクトリを作成する

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env"

echo "[INFO] Webroot ディレクトリを作成します"

if [ ! -f "${ENV_FILE}" ]; then
  echo "[ERROR] .env が見つかりません: ${ENV_FILE}" >&2
  exit 1
fi

set -a
source "${ENV_FILE}"
set +a

: "${PROJECT_DIR:?PROJECT_DIR が未設定です}"

PROJECT_DIR="${PROJECT_DIR%/}"

if [[ "${PROJECT_DIR}" != /var/www/html/* ]]; then
  echo "[ERROR] PROJECT_DIR は /var/www/html/ 配下にしてください: ${PROJECT_DIR}" >&2
  exit 1
fi

if [[ "${PROJECT_DIR}" == "/var/www/html" ]]; then
  echo "[ERROR] PROJECT_DIR に /var/www/html 自体は指定しないでください" >&2
  exit 1
fi

echo
echo "===== WEBROOT SETTINGS ====="
echo "PROJECT_DIR: ${PROJECT_DIR}"

sudo mkdir -p "${PROJECT_DIR}"

echo
echo "[OK] Webroot ディレクトリ作成完了"