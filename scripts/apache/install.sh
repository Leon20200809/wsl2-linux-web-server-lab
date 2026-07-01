#!/usr/bin/env bash
set -Eeuo pipefail

# Apache2をインストールし、Webサーバーの玄関を用意する

echo "[INFO] Apache2 をインストールします"

sudo DEBIAN_FRONTEND=noninteractive apt install -y apache2

echo
echo "===== APACHE PACKAGE STATUS ====="
dpkg-query -W -f='${binary:Package}\t${Version}\t${Status}\n' apache2

echo
echo "[OK] Apache2 インストール完了"
