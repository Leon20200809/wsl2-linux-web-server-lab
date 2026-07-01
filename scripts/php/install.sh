#!/usr/bin/env bash
set -Eeuo pipefail

# PHP-FPMをインストールし、ApacheからFastCGI経由でPHPを実行できるようにする

PACKAGES=(
  php
  php-cli
  php-fpm
  php-mysql
  php-curl
  php-xml
  php-mbstring
  php-zip
  php-gd
  php-intl
)

echo "[INFO] PHP-FPM と主要PHP拡張をインストールします"
sudo DEBIAN_FRONTEND=noninteractive apt install -y "${PACKAGES[@]}"

echo
echo "===== PHP VERSION ====="
php -v

PHP_VERSION="$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;' 2>/dev/null)"
PHP_FPM_SERVICE="php${PHP_VERSION}-fpm"
PHP_FPM_CONF="php${PHP_VERSION}-fpm"

echo
echo "===== PHP-FPM DETECTED ====="
echo "PHP_VERSION: ${PHP_VERSION}"
echo "PHP_FPM_SERVICE: ${PHP_FPM_SERVICE}"
echo "PHP_FPM_CONF: ${PHP_FPM_CONF}"

echo
echo "===== PHP PACKAGE STATUS ====="
for package in "${PACKAGES[@]}"; do
  dpkg-query -W -f='${binary:Package}\t${Version}\t${Status}\n' "$package" 2>/dev/null || true
done

echo
echo "===== OPCACHE CHECK ====="
if php -m | grep -qi 'Zend OPcache'; then
  echo "[OK] Zend OPcache is available"
else
  echo "[WARN] Zend OPcache は現在のPHPモジュール一覧では確認できません"
fi

echo
echo "[INFO] ApacheでPHP-FPM連携に必要なモジュールを有効化します"

# ApacheがPHP-FPMへ処理を渡すために必要
sudo a2enmod proxy_fcgi setenvif

echo
echo "[INFO] ApacheのPHP-FPM設定を有効化します"

if [ -f "/etc/apache2/conf-available/${PHP_FPM_CONF}.conf" ]; then
  sudo a2enconf "${PHP_FPM_CONF}"
else
  echo "[ERROR] /etc/apache2/conf-available/${PHP_FPM_CONF}.conf が見つかりません" >&2
  echo "[INFO] 利用可能なFPM設定:" >&2
  ls -1 /etc/apache2/conf-available/*fpm*.conf 2>/dev/null || true
  exit 1
fi

echo
echo "[INFO] PHP-FPM と Apache2 を再起動します"

sudo service "${PHP_FPM_SERVICE}" restart
sudo service apache2 restart

echo
echo "[OK] PHP-FPM インストールとApache連携設定完了"
