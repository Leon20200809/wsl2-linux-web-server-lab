#!/usr/bin/env bash
set -Eeuo pipefail

PACKAGES=(
  git
  curl
  ca-certificates
  unzip
)

log_info() {
  echo "[INFO] $1"
}

log_ok() {
  echo "[OK] $1"
}

log_error() {
  echo "[ERROR] $1" >&2
}

show_command() {
  echo
  echo "$ $*"
  "$@"
}

log_info "APT base setup を開始します"

echo
echo "===== OS INFO ====="
if [ -f /etc/os-release ]; then
  cat /etc/os-release
else
  log_error "/etc/os-release が見つかりません"
  exit 1
fi

echo
echo "===== BASIC INFO ====="
echo "USER: $(whoami)"
echo "HOME: ${HOME}"
echo "SHELL: ${SHELL:-unknown}"
echo "PWD: $(pwd)"
echo "WSL_DISTRO_NAME: ${WSL_DISTRO_NAME:-not-wsl-or-unknown}"

echo
echo "===== APT CHECK ====="
if ! command -v apt >/dev/null 2>&1; then
  log_error "apt コマンドが見つかりません。このスクリプトは apt 系Linux向けです。"
  exit 1
fi

show_command apt --version

log_info "sudo権限を確認します"
sudo -v

log_info "apt のパッケージリストを更新します"
sudo apt update

log_info "最低限ツールをインストールします: ${PACKAGES[*]}"
sudo DEBIAN_FRONTEND=noninteractive apt install -y "${PACKAGES[@]}"

echo
echo "===== INSTALLED PACKAGE STATUS ====="
for package in "${PACKAGES[@]}"; do
  if dpkg-query -W -f='${binary:Package}\t${Version}\t${Status}\n' "$package" 2>/dev/null; then
    :
  else
    echo -e "${package}\tNOT INSTALLED"
  fi
done

echo
echo "===== COMMAND VERSION CHECK ====="
if command -v git >/dev/null 2>&1; then
  git --version
else
  echo "git: not found"
fi

if command -v curl >/dev/null 2>&1; then
  curl --version | head -n 1
else
  echo "curl: not found"
fi

if command -v unzip >/dev/null 2>&1; then
  unzip -v | head -n 1
else
  echo "unzip: not found"
fi

echo
log_ok "APT base setup 完了"
