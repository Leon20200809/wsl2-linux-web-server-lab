#!/usr/bin/env bash
set -Eeuo pipefail

# PHP-FPMサービスとApache経由のPHP実行を確認する

echo "[INFO] PHP-FPM の状態を確認します"

PHP_VERSION="$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;' 2>/dev/null)"
PHP_FPM_SERVICE="php${PHP_VERSION}-fpm"

echo
echo "===== PHP VERSION ====="
php -v

echo
echo "===== PHP SAPI CHECK ====="
php -r 'echo "CLI SAPI: " . PHP_SAPI . PHP_EOL;'

echo
echo "===== PHP-FPM SERVICE STATUS ====="
if sudo service "${PHP_FPM_SERVICE}" status >/dev/null 2>&1; then
  echo "[OK] ${PHP_FPM_SERVICE} is running"
else
  echo "[WARN] ${PHP_FPM_SERVICE} is not running. restart を試みます"
  sudo service "${PHP_FPM_SERVICE}" restart
  sudo service "${PHP_FPM_SERVICE}" status --no-pager || sudo service "${PHP_FPM_SERVICE}" status
fi

echo
echo "===== APACHE MODULE CHECK ====="
apache2ctl -M 2>/dev/null | grep -E 'proxy|proxy_fcgi|setenvif' || true

echo
echo "===== APACHE PHP-FPM CONF CHECK ====="
apache2ctl -t

echo
echo "===== WEB PHP EXECUTION CHECK ====="

TEST_FILE="/var/www/html/php-fpm-check.php"

# Apache経由でPHPが実行されるか確認するための一時ファイル
echo '<?php echo "PHP_FPM_OK:" . PHP_SAPI . PHP_EOL; ?>' | sudo tee "${TEST_FILE}" >/dev/null

if command -v curl >/dev/null 2>&1; then
  curl -s http://localhost/php-fpm-check.php
else
  echo "[WARN] curl が見つからないため HTTP 確認をスキップします"
fi

sudo rm -f "${TEST_FILE}"

echo
echo "[OK] PHP-FPM 確認完了"
