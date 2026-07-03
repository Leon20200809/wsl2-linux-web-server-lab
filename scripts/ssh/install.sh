#!/usr/bin/env bash
set -Eeuo pipefail

# OpenSSH Serverをインストールする
# Windows Git Bashや別Linuxから、このUbuntuへSSH接続するための入口を作る

echo "[INFO] OpenSSH Server をインストールします"

sudo DEBIAN_FRONTEND=noninteractive apt install -y openssh-server

echo
echo "===== SSH PACKAGE STATUS ====="
dpkg-query -W -f='${binary:Package}\t${Version}\t${Status}\n' openssh-server

echo
echo "===== SSH VERSION ====="
ssh -V
/usr/sbin/sshd -V 2>&1 || true

echo
echo "[OK] OpenSSH Server インストール完了"