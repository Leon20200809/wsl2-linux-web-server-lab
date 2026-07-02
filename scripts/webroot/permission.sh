#!/usr/bin/env bash
set -Eeuo pipefail

# Webrootを現在の作業ユーザーが編集でき、Apache/PHP-FPMが読める権限にする

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env"

echo "[INFO] Webroot の権限を設定します"

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

if [ ! -d "${PROJECT_DIR}" ]; then
  echo "[ERROR] Webroot ディレクトリが存在しません: ${PROJECT_DIR}" >&2
  exit 1
fi

echo
echo "===== WEBROOT PERMISSION SETTINGS ====="
echo "PROJECT_DIR: ${PROJECT_DIR}"
echo "OWNER: ${USER}"
echo "GROUP: www-data"

sudo chown -R "${USER}:www-data" "${PROJECT_DIR}"

sudo find "${PROJECT_DIR}" -type d -exec chmod 2775 {} \;
sudo find "${PROJECT_DIR}" -type f -exec chmod 664 {} \;

echo
echo "[OK] Webroot 権限設定完了"