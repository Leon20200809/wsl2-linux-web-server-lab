#!/usr/bin/env bash
set -Eeuo pipefail

# SSHが10022番で待受しているか確認する
# 接続テストは Windows Git Bash など外側から ssh -p 10022 user@localhost で行う

SSH_PORT="${SSH_PORT:-10022}"
ERROR_COUNT=0

ok() {
  echo "[OK] $1"
}

fail() {
  echo "[ERROR] $1" >&2
  ERROR_COUNT=$((ERROR_COUNT + 1))
}

section() {
  echo
  echo "===== $1 ====="
}

section "SSH SERVICE CHECK"

if sudo service ssh status >/dev/null 2>&1; then
  ok "ssh service is running"
else
  fail "ssh service is not running"
fi

section "SSH EFFECTIVE CONFIG"

# sshdが最終的に認識している設定を確認する
sudo /usr/sbin/sshd -T | grep -E '^port|^passwordauthentication|^pubkeyauthentication|^permitrootlogin'

EFFECTIVE_PORT="$(sudo /usr/sbin/sshd -T | awk '/^port / {print $2; exit}')"

if [ "${EFFECTIVE_PORT}" = "${SSH_PORT}" ]; then
  ok "sshd effective port OK: ${EFFECTIVE_PORT}"
else
  fail "sshd effective port mismatch: ${EFFECTIVE_PORT} expected ${SSH_PORT}"
fi

section "SSH SOCKET CHECK"

# ssh.socket が有効だと22番を握ることがあるため、無効化されているか確認する
if systemctl is-enabled ssh.socket >/dev/null 2>&1; then
  fail "ssh.socket is enabled"
else
  ok "ssh.socket is disabled"
fi

section "SSH LISTEN PORT CHECK"

if sudo ss -ltnp | grep -q ":${SSH_PORT}"; then
  sudo ss -ltnp | grep ":${SSH_PORT}"
  ok "SSH is listening on port ${SSH_PORT}"
else
  fail "SSH is not listening on port ${SSH_PORT}"
fi

if sudo ss -ltnp | grep -q ':22'; then
  echo
  echo "[WARN] port 22 is still listening:"
  sudo ss -ltnp | grep ':22'
else
  ok "port 22 is not listening"
fi

section "SSH CHECK RESULT"

if [ "${ERROR_COUNT}" -eq 0 ]; then
  echo "[OK] SSH check completed successfully"
  echo
  echo "Next:"
  echo "  ssh -p ${SSH_PORT} ${USER}@localhost"
  exit 0
else
  echo "[ERROR] SSH check failed: ${ERROR_COUNT} error(s)" >&2
  exit 1
fi