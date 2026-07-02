#!/usr/bin/env bash
set -Eeuo pipefail

# このファイルの場所を基準に、プロジェクト全体の位置を決める
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "[INFO] LG Modular Provisioning runner"
echo "[INFO] Project root: ${PROJECT_ROOT}"

# 最初にsudo権限を確認する
# パスワードは.envに保存せず、必要ならターミナルで入力する
sudo -v

echo
echo "===== STEP 00: APT BASE SETUP ====="

# 以後の構築に必要な最低限の道具を揃える
"${SCRIPT_DIR}/bootstrap/00-apt-base.sh"

echo
echo "===== STEP 10: APACHE INSTALL ====="

# Webサーバー本体を導入する
"${SCRIPT_DIR}/apache/install.sh"

echo
echo "===== STEP 11: APACHE CHECK ====="

# Apache2が起動し、HTTP応答を返せるか確認する
"${SCRIPT_DIR}/apache/check.sh"

echo
echo "===== STEP 20: PHP-FPM INSTALL ====="

# PHP-FPMを導入し、ApacheからPHPを実行できるようにする
"${SCRIPT_DIR}/php/install.sh"

echo
echo "===== STEP 21: PHP-FPM CHECK ====="

# PHP-FPMサービスとApache経由のPHP実行を確認する
"${SCRIPT_DIR}/php/check.sh"

echo
echo "===== STEP 30: MYSQL INSTALL ====="

# MySQL Serverを導入する
"${SCRIPT_DIR}/mysql/install.sh"

echo
echo "===== STEP 31: MYSQL CREATE DB ====="

# .envの値を使ってDBと専用ユーザーを作成する
"${SCRIPT_DIR}/mysql/create-db.sh"

echo
echo "===== STEP 32: MYSQL CHECK ====="

# MySQLサービスと専用ユーザーでの接続を確認する
"${SCRIPT_DIR}/mysql/check.sh"

echo
echo "[OK] run.sh MVP completed"
