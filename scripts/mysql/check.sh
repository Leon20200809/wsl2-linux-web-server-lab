#!/usr/bin/env bash
set -Eeuo pipefail

# MySQLサービス状態と、専用ユーザーでのDB接続を確認する

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env"

echo "[INFO] MySQL の状態を確認します"

if [ ! -f "${ENV_FILE}" ]; then
  echo "[ERROR] .env が見つかりません: ${ENV_FILE}" >&2
  exit 1
fi

set -a
source "${ENV_FILE}"
set +a

: "${DB_NAME:?DB_NAME が未設定です}"
: "${DB_USER:?DB_USER が未設定です}"
: "${DB_PASSWORD:?DB_PASSWORD が未設定です}"

echo
echo "===== MYSQL VERSION ====="
mysql --version

echo
echo "===== MYSQL SERVICE STATUS ====="
if sudo service mysql status >/dev/null 2>&1; then
  echo "[OK] mysql service is running"
else
  echo "[WARN] mysql service is not running. restart を試みます"
  sudo service mysql restart
  sudo service mysql status --no-pager || sudo service mysql status
fi

echo
echo "===== MYSQL ROOT CHECK ====="
sudo mysql -e "SELECT VERSION() AS mysql_version;"

echo
echo
echo "===== MYSQL USER DB CHECK ====="
MYSQL_PWD="${DB_PASSWORD}" mysql -u "${DB_USER}" -h localhost "${DB_NAME}" -e "SELECT DATABASE() AS selected_database, USER() AS mysql_user;"

echo
echo "[OK] MySQL 確認完了"