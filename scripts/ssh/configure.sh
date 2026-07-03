#!/usr/bin/env bash
set -Eeuo pipefail

# SSHの待受ポートを10022に変更する
# Ubuntu環境によっては ssh.socket が22番を握るため、socketを無効化して ssh.service 管理に寄せる

SSH_PORT="${SSH_PORT:-10022}"
SSH_CONFIG_DIR="/etc/ssh/sshd_config.d"
SSH_CONFIG_FILE="${SSH_CONFIG_DIR}/99-lamp-lab.conf"

echo "[INFO] SSH 設定を変更します"
echo "SSH_PORT: ${SSH_PORT}"

if ! command -v systemctl >/dev/null 2>&1; then
  echo "[ERROR] systemctl が見つかりません。ssh.socket の無効化に systemd が必要です。" >&2
  exit 1
fi

if [ ! -x /usr/sbin/sshd ]; then
  echo "[ERROR] /usr/sbin/sshd が見つかりません。openssh-server が入っているか確認してください。" >&2
  exit 1
fi

if [[ ! "${SSH_PORT}" =~ ^[0-9]+$ ]]; then
  echo "[ERROR] SSH_PORT は数字で指定してください: ${SSH_PORT}" >&2
  exit 1
fi

if [ "${SSH_PORT}" -lt 1024 ] || [ "${SSH_PORT}" -gt 65535 ]; then
  echo "[ERROR] SSH_PORT は 1024〜65535 の範囲で指定してください: ${SSH_PORT}" >&2
  exit 1
fi

echo
echo "===== SSH CONFIG BACKUP ====="

# 既存の追加設定があればバックアップする
if [ -f "${SSH_CONFIG_FILE}" ]; then
  BACKUP_FILE="${SSH_CONFIG_FILE}.bak.$(date +%Y%m%d%H%M%S)"
  sudo cp "${SSH_CONFIG_FILE}" "${BACKUP_FILE}"
  echo "Backup created: ${BACKUP_FILE}"
else
  echo "No existing config: ${SSH_CONFIG_FILE}"
fi

echo
echo "===== WRITE SSH CONFIG ====="

sudo mkdir -p "${SSH_CONFIG_DIR}"

sudo tee "${SSH_CONFIG_FILE}" >/dev/null <<EOF
Port ${SSH_PORT}
PasswordAuthentication yes
PubkeyAuthentication yes
PermitRootLogin no
EOF

sudo chmod 644 "${SSH_CONFIG_FILE}"

echo "Config written: ${SSH_CONFIG_FILE}"

echo
echo "===== SSH CONFIG TEST ====="

# /run/sshd がないと構文チェックで怒られる環境がある
sudo mkdir -p /run/sshd

sudo /usr/sbin/sshd -t

echo "[OK] sshd config syntax OK"

echo
echo "===== DISABLE SSH SOCKET ====="

# ssh.socket が22番を先に握ることがあるため無効化する
if systemctl list-unit-files | grep -q '^ssh.socket'; then
  sudo systemctl disable --now ssh.socket
  echo "[OK] ssh.socket disabled"
else
  echo "[INFO] ssh.socket unit not found. skip"
fi

echo
echo "===== ENABLE SSH SERVICE ====="

# ssh.service本体を常駐サービスとして有効化する
sudo systemctl enable --now ssh.service
sudo systemctl restart ssh.service

echo
echo "[OK] SSH 設定変更完了"