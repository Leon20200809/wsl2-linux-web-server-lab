#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[INFO] SSH setup runner"

sudo -v

echo
echo "===== SSH INSTALL ====="
"${SCRIPT_DIR}/ssh/install.sh"

echo
echo "===== SSH CONFIGURE ====="
"${SCRIPT_DIR}/ssh/configure.sh"

echo
echo "===== SSH CHECK ====="
"${SCRIPT_DIR}/ssh/check.sh"

echo
echo "[OK] SSH setup completed"