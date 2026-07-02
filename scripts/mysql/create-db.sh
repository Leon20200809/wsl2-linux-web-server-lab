#!/usr/bin/env bash
set -Eeuo pipefail

# .envの値を使って、MySQLにDBと専用ユーザーを作成する

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env"

echo "[INFO] MySQL DB と専用ユーザーを作成します"

if [ ! -f "${ENV_FILE}" ]; then
  echo "[ERROR] .env が見つかりません: ${ENV_FILE}" >&2
  echo "[INFO] cp .env.example .env を実行してください" >&2
  exit 1
fi

set -a
source "${ENV_FILE}"
set +a

: "${DB_NAME:?DB_NAME が未設定です}"
: "${DB_USER:?DB_USER が未設定です}"
: "${DB_PASSWORD:?DB_PASSWORD が未設定です}"

if [[ ! "${DB_NAME}" =~ ^[A-Za-z0-9_]+$ ]]; then
  echo "[ERROR] DB_NAME は英数字とアンダースコアのみ使用できます: ${DB_NAME}" >&2
  exit 1
fi

if [[ ! "${DB_USER}" =~ ^[A-Za-z0-9_]+$ ]]; then
  echo "[ERROR] DB_USER は英数字とアンダースコアのみ使用できます: ${DB_USER}" >&2
  exit 1
fi

echo
echo "===== MYSQL DB SETTINGS ====="
echo "DB_NAME: ${DB_NAME}"
echo "DB_USER: ${DB_USER}"
echo "DB_PASSWORD: ********"

sudo mysql <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
ALTER USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL

echo
echo "[OK] MySQL DB と専用ユーザー作成完了"