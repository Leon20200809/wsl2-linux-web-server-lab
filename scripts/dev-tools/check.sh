#!/usr/bin/env bash
set -Eeuo pipefail

echo "[INFO] dev-tools check start"

ERROR_COUNT=0

check_command() {
  local name="$1"

  if command -v "$name" >/dev/null 2>&1; then
    echo "[OK] ${name}: $(command -v "$name")"
  else
    echo "[ERROR] ${name} command not found"
    ERROR_COUNT=$((ERROR_COUNT + 1))
  fi
}

# Load nvm so node/npm installed via nvm can be found in this script.
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"
fi

check_command php
check_command composer
check_command node
check_command npm

echo
echo "===== VERSION ====="

if command -v php >/dev/null 2>&1; then
  php -v | head -n 1
fi

if command -v composer >/dev/null 2>&1; then
  composer --version
fi

if command -v node >/dev/null 2>&1; then
  node -v
fi

if command -v npm >/dev/null 2>&1; then
  npm -v
fi

echo
if [ "$ERROR_COUNT" -eq 0 ]; then
  echo "[OK] dev-tools check completed successfully"
else
  echo "[ERROR] dev-tools check failed: ${ERROR_COUNT}"
  exit 1
fi
