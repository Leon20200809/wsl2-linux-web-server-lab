#!/usr/bin/env bash
set -Eeuo pipefail

# Apache2が起動し、HTTP応答を返せるか確認する

echo "[INFO] Apache2 の状態を確認します"

echo
echo "===== APACHE VERSION ====="
apache2 -v

echo
echo "===== APACHE SERVICE STATUS ====="
if sudo service apache2 status >/dev/null 2>&1; then
  echo "[OK] Apache2 service is running"
else
  echo "[WARN] Apache2 service is not running. restart を試みます"
  sudo service apache2 restart
  sudo service apache2 status --no-pager || sudo service apache2 status
fi

echo
echo "===== HTTP CHECK ====="
if command -v curl >/dev/null 2>&1; then
  curl -I http://localhost/ | head
else
  echo "[WARN] curl が見つからないため HTTP 確認をスキップします"
fi

echo
echo "[OK] Apache2 確認完了"
