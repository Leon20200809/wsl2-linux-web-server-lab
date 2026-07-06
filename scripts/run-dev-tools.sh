#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[INFO] dev-tools setup runner"

echo
echo "===== COMPOSER INSTALL ====="
"${SCRIPT_DIR}/dev-tools/install-composer.sh"

echo
echo "===== NODE.JS INSTALL ====="
"${SCRIPT_DIR}/dev-tools/install-node.sh"

echo
echo "===== DEV TOOLS CHECK ====="
"${SCRIPT_DIR}/dev-tools/check.sh"

echo
echo "[OK] dev-tools setup completed"
