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
echo "[OK] run.sh MVP completed"