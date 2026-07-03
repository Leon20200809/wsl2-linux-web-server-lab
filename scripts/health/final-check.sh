#!/usr/bin/env bash
set -Eeuo pipefail

# LAMP構築結果をまとめて確認する最終チェック
# ここではインストールや設定変更はせず、現在の状態だけを検査する

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env"

ERROR_COUNT=0

# 成功・警告・失敗メッセージを統一する
ok() {
  echo "[OK] $1"
}

warn() {
  echo "[WARN] $1"
}

fail() {
  echo "[ERROR] $1" >&2
  ERROR_COUNT=$((ERROR_COUNT + 1))
}

section() {
  echo
  echo "===== $1 ====="
}

# 必要なコマンドが存在するか確認する
require_command() {
  local command_name="$1"

  if command -v "${command_name}" >/dev/null 2>&1; then
    ok "command found: ${command_name}"
  else
    fail "command not found: ${command_name}"
  fi
}

# service コマンドでサービスが起動中か確認する
check_service() {
  local service_name="$1"

  if sudo service "${service_name}" status >/dev/null 2>&1; then
    ok "${service_name} service is running"
  else
    fail "${service_name} service is not running"
  fi
}

# .env がないと、PROJECT_DIR や DB 情報を取得できない
if [ ! -f "${ENV_FILE}" ]; then
  fail ".env が見つかりません: ${ENV_FILE}"
  exit 1
fi

# .env の値をシェル変数として読み込む
set -a
source "${ENV_FILE}"
set +a

# 必須の環境変数が空なら即停止する
: "${PROJECT_NAME:?PROJECT_NAME が未設定です}"
: "${PROJECT_DIR:?PROJECT_DIR が未設定です}"
: "${PROJECT_URL:?PROJECT_URL が未設定です}"
: "${DB_NAME:?DB_NAME が未設定です}"
: "${DB_USER:?DB_USER が未設定です}"
: "${DB_PASSWORD:?DB_PASSWORD が未設定です}"

# 末尾の / を削って、パスやURLの揺れを防ぐ
PROJECT_DIR="${PROJECT_DIR%/}"
PROJECT_URL="${PROJECT_URL%/}"
INDEX_FILE="${PROJECT_DIR}/index.php"

section "FINAL CHECK START"
echo "PROJECT_ROOT: ${PROJECT_ROOT}"
echo "PROJECT_NAME: ${PROJECT_NAME}"
echo "PROJECT_DIR: ${PROJECT_DIR}"
echo "PROJECT_URL: ${PROJECT_URL}"
echo "DB_NAME: ${DB_NAME}"
echo "DB_USER: ${DB_USER}"
echo "DB_PASSWORD: ********"

section "COMMAND CHECK"

# LAMP構築で使う主要コマンドの存在確認
require_command apache2
require_command php
require_command mysql
require_command curl
require_command ss

section "APACHE CHECK"

# Apache本体とHTTP応答を確認する
apache2 -v || fail "apache2 -v failed"
check_service apache2

if curl -fsSI "http://localhost/" >/dev/null 2>&1; then
  ok "Apache HTTP response OK: http://localhost/"
else
  fail "Apache HTTP response failed: http://localhost/"
fi

section "PHP-FPM CHECK"

# PHPのバージョンから php8.x-fpm のサービス名を組み立てる
PHP_VERSION="$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;' 2>/dev/null || true)"

if [ -n "${PHP_VERSION}" ]; then
  PHP_FPM_SERVICE="php${PHP_VERSION}-fpm"
  echo "PHP_VERSION: ${PHP_VERSION}"
  echo "PHP_FPM_SERVICE: ${PHP_FPM_SERVICE}"

  php -v
  check_service "${PHP_FPM_SERVICE}"
else
  fail "PHP_VERSION を取得できません"
fi

# OPcacheは高速化用。必須インストールではなく、存在確認だけ行う
if php -m | grep -qi 'Zend OPcache'; then
  ok "Zend OPcache is available"
else
  warn "Zend OPcache が確認できません"
fi

# ApacheがPHP-FPMへ処理を渡す proxy_fcgi を有効化できているか確認する
if apache2ctl -M 2>/dev/null | grep -q 'proxy_fcgi_module'; then
  ok "Apache proxy_fcgi_module is enabled"
else
  fail "Apache proxy_fcgi_module is not enabled"
fi

# Apache設定ファイル全体の構文確認
if apache2ctl -t >/dev/null 2>&1; then
  ok "Apache config syntax OK"
else
  fail "Apache config syntax error"
fi

section "MYSQL CHECK"

# MySQL本体・サービス・root接続・専用ユーザー接続を確認する
mysql --version
check_service mysql

if sudo mysql -e "SELECT VERSION() AS mysql_version;" >/dev/null 2>&1; then
  ok "MySQL root connection OK"
else
  fail "MySQL root connection failed"
fi

if MYSQL_PWD="${DB_PASSWORD}" mysql -u "${DB_USER}" -h localhost "${DB_NAME}" -e "SELECT DATABASE() AS selected_database, USER() AS mysql_user;" >/dev/null 2>&1; then
  ok "MySQL user connection OK: ${DB_USER}@localhost -> ${DB_NAME}"
else
  fail "MySQL user connection failed: ${DB_USER}@localhost -> ${DB_NAME}"
fi

section "WEBROOT CHECK"

# .envで指定した公開ディレクトリと index.php の存在確認
if [ -d "${PROJECT_DIR}" ]; then
  ok "PROJECT_DIR exists: ${PROJECT_DIR}"
else
  fail "PROJECT_DIR does not exist: ${PROJECT_DIR}"
fi

if [ -f "${INDEX_FILE}" ]; then
  ok "index.php exists: ${INDEX_FILE}"
else
  fail "index.php does not exist: ${INDEX_FILE}"
fi

# Webrootの所有者・グループ・権限を確認する
if [ -e "${PROJECT_DIR}" ]; then
  echo
  echo "===== WEBROOT PERMISSION ====="
  ls -ld "${PROJECT_DIR}"
  [ -f "${INDEX_FILE}" ] && ls -l "${INDEX_FILE}"

  DIR_OWNER="$(stat -c '%U' "${PROJECT_DIR}")"
  DIR_GROUP="$(stat -c '%G' "${PROJECT_DIR}")"
  DIR_MODE="$(stat -c '%a' "${PROJECT_DIR}")"

  if [ "${DIR_OWNER}" = "${USER}" ]; then
    ok "PROJECT_DIR owner OK: ${DIR_OWNER}"
  else
    fail "PROJECT_DIR owner mismatch: ${DIR_OWNER} expected ${USER}"
  fi

  if [ "${DIR_GROUP}" = "www-data" ]; then
    ok "PROJECT_DIR group OK: ${DIR_GROUP}"
  else
    fail "PROJECT_DIR group mismatch: ${DIR_GROUP} expected www-data"
  fi

  if [ "${DIR_MODE}" = "2775" ]; then
    ok "PROJECT_DIR mode OK: ${DIR_MODE}"
  else
    fail "PROJECT_DIR mode mismatch: ${DIR_MODE} expected 2775"
  fi
fi

# index.php の所有者・グループ・権限を確認する
if [ -f "${INDEX_FILE}" ]; then
  FILE_OWNER="$(stat -c '%U' "${INDEX_FILE}")"
  FILE_GROUP="$(stat -c '%G' "${INDEX_FILE}")"
  FILE_MODE="$(stat -c '%a' "${INDEX_FILE}")"

  if [ "${FILE_OWNER}" = "${USER}" ]; then
    ok "index.php owner OK: ${FILE_OWNER}"
  else
    fail "index.php owner mismatch: ${FILE_OWNER} expected ${USER}"
  fi

  if [ "${FILE_GROUP}" = "www-data" ]; then
    ok "index.php group OK: ${FILE_GROUP}"
  else
    fail "index.php group mismatch: ${FILE_GROUP} expected www-data"
  fi

  if [ "${FILE_MODE}" = "664" ]; then
    ok "index.php mode OK: ${FILE_MODE}"
  else
    fail "index.php mode mismatch: ${FILE_MODE} expected 664"
  fi
fi

section "WEB APPLICATION CHECK"

# Apache + PHP-FPM 経由でWebページが表示できるか確認する
if curl -fsS "${PROJECT_URL}/" >/tmp/lamp_lab_final_check.html; then
  ok "Project URL response OK: ${PROJECT_URL}/"

  # create-test-index.sh で作った確認文言があるか見る
  if grep -q 'Apache + PHP-FPM webroot check OK' /tmp/lamp_lab_final_check.html; then
    ok "Webroot test message found"
  else
    fail "Webroot test message not found"
  fi

  # Web経由のPHP SAPIが fpm-fcgi なら、PHP-FPM経由で動いている証拠
  if grep -q 'fpm-fcgi' /tmp/lamp_lab_final_check.html; then
    ok "Web PHP SAPI is fpm-fcgi"
  else
    fail "Web PHP SAPI fpm-fcgi not found"
  fi
else
  fail "Project URL response failed: ${PROJECT_URL}/"
fi

rm -f /tmp/lamp_lab_final_check.html

section "PORT CHECK"

# 主要ポートの待受状態を確認する
# 80 = HTTP, 3306 = MySQL, 33060 = MySQL X Plugin
sudo ss -ltnp | grep -E ':80|:3306|:33060' || warn "主要ポートの待受が確認できません"

section "FINAL RESULT"

# 1つでもERRORがあれば失敗。0ならLAMP構築完了
if [ "${ERROR_COUNT}" -eq 0 ]; then
  echo "[OK] LAMP final check completed successfully"
  echo
  echo "RESULT: Apache + PHP-FPM + MySQL + Webroot are ready."
  exit 0
else
  echo "[ERROR] LAMP final check failed: ${ERROR_COUNT} error(s)" >&2
  exit 1
fi