#!/usr/bin/env bash
set -Eeuo pipefail

# MySQL Serverをインストールし、DBサーバーを起動できる状態にする

echo "[INFO] MySQL Server をインストールします"

sudo DEBIAN_FRONTEND=noninteractive apt install -y mysql-server

echo
echo "===== MYSQL PACKAGE STATUS ====="
dpkg-query -W -f='${binary:Package}\t${Version}\t${Status}\n' mysql-server

echo
echo "===== MYSQL VERSION ====="
mysql --version

echo
echo "[INFO] MySQL Server を起動します"

sudo service mysql restart

echo
echo "[OK] MySQL Server インストール完了"