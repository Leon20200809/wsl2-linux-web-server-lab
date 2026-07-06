#!/usr/bin/env bash
set -Eeuo pipefail

# Composer は PHP の依存関係管理ツール。
# Laravel や PHP ライブラリ管理に必要な開発用装備。
# WSL では Windows 側 PATH が混ざるため、/mnt/c 配下の Composer は採用しない。

echo "[INFO] Composer install start"

LINUX_COMPOSER_PATH="/usr/local/bin/composer"
COMPOSER_PATH="$(command -v composer || true)"

# PHP がないと Composer は動かない
if ! command -v php >/dev/null 2>&1; then
  echo "[ERROR] php command not found. Run scripts/run.sh first."
  exit 1
fi

# /usr/local/bin/composer が既にあれば、Linux 側 Composer として採用する
if [ -x "$LINUX_COMPOSER_PATH" ]; then
  echo "[OK] Linux Composer already installed: $LINUX_COMPOSER_PATH"
  "$LINUX_COMPOSER_PATH" --version
  exit 0
fi

# command -v composer が Linux 側を指しているなら、それも採用する
if [ -n "$COMPOSER_PATH" ] && [[ "$COMPOSER_PATH" != /mnt/c/* ]]; then
  echo "[OK] Linux Composer already installed: $COMPOSER_PATH"
  "$COMPOSER_PATH" --version
  exit 0
fi

# WSL では Windows / Laragon 側 Composer が見えることがある
if [ -n "$COMPOSER_PATH" ] && [[ "$COMPOSER_PATH" == /mnt/c/* ]]; then
  echo "[WARN] Windows Composer detected: $COMPOSER_PATH"
  echo "[INFO] Install Linux Composer instead."
fi

TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cd "$TMP_DIR"

echo "[INFO] Download Composer installer"
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php') || exit(1);"

echo "[INFO] Verify Composer installer signature"
EXPECTED_SIGNATURE="$(php -r "copy('https://composer.github.io/installer.sig', 'php://stdout') || exit(1);")"
ACTUAL_SIGNATURE="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

if [ "$EXPECTED_SIGNATURE" != "$ACTUAL_SIGNATURE" ]; then
  echo "[ERROR] Invalid Composer installer signature"
  exit 1
fi

echo "[OK] Composer installer verified"

echo "[INFO] Install Composer to $LINUX_COMPOSER_PATH"
sudo php composer-setup.php --install-dir=/usr/local/bin --filename=composer

# シェルが古い composer の場所を覚えている可能性があるため更新する
hash -r

echo "[OK] Composer installed"
"$LINUX_COMPOSER_PATH" --version