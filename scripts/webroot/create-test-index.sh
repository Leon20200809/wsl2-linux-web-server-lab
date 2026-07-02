#!/usr/bin/env bash
set -Eeuo pipefail

# Apache + PHP-FPM 経由で表示確認するための index.php を作成する

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env"

echo "[INFO] 確認用 index.php を作成します"

if [ ! -f "${ENV_FILE}" ]; then
  echo "[ERROR] .env が見つかりません: ${ENV_FILE}" >&2
  exit 1
fi

set -a
source "${ENV_FILE}"
set +a

: "${PROJECT_NAME:?PROJECT_NAME が未設定です}"
: "${PROJECT_DIR:?PROJECT_DIR が未設定です}"
: "${PROJECT_URL:?PROJECT_URL が未設定です}"

PROJECT_DIR="${PROJECT_DIR%/}"
INDEX_FILE="${PROJECT_DIR}/index.php"

if [[ "${PROJECT_DIR}" != /var/www/html/* ]]; then
  echo "[ERROR] PROJECT_DIR は /var/www/html/ 配下にしてください: ${PROJECT_DIR}" >&2
  exit 1
fi

if [ ! -d "${PROJECT_DIR}" ]; then
  echo "[ERROR] Webroot ディレクトリが存在しません: ${PROJECT_DIR}" >&2
  exit 1
fi

cat > "${INDEX_FILE}" <<PHP
<?php
declare(strict_types=1);

header('Content-Type: text/html; charset=UTF-8');

function h(string \$value): string
{
    return htmlspecialchars(\$value, ENT_QUOTES, 'UTF-8');
}

\$projectName = '${PROJECT_NAME}';
?>
<!doctype html>
<html lang="ja">
<head>
  <meta charset="UTF-8">
  <title><?= h(\$projectName) ?> - LAMP Check</title>
</head>
<body>
  <h1><?= h(\$projectName) ?></h1>
  <p>Apache + PHP-FPM webroot check OK.</p>

  <ul>
    <li>PHP Version: <?= h(PHP_VERSION) ?></li>
    <li>PHP SAPI: <?= h(PHP_SAPI) ?></li>
    <li>Server Software: <?= h(\$_SERVER['SERVER_SOFTWARE'] ?? 'unknown') ?></li>
    <li>Document Root: <?= h(\$_SERVER['DOCUMENT_ROOT'] ?? 'unknown') ?></li>
  </ul>
</body>
</html>
PHP

sudo chown "${USER}:www-data" "${INDEX_FILE}"
chmod 664 "${INDEX_FILE}"

echo
echo "===== TEST INDEX CREATED ====="
echo "INDEX_FILE: ${INDEX_FILE}"
echo "PROJECT_URL: ${PROJECT_URL}"

echo
echo "[OK] 確認用 index.php 作成完了"