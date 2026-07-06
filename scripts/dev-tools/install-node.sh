#!/usr/bin/env bash
set -Eeuo pipefail

# Node.js は JavaScript の実行環境。
# Vite / Tailwind CSS / React / Next.js / Laravel Vite などで使う。
# WSL では Windows 側 PATH が混ざるため、Node.js は nvm 経由で Linux 側に入れる。
# デフォルトは LTS 版。必要なら NODE_VERSION=24 のように指定できる。

echo "[INFO] Node.js install start"

# curl がないと nvm インストーラを取得できない
if ! command -v curl >/dev/null 2>&1; then
  echo "[ERROR] curl command not found. Run scripts/run.sh first."
  exit 1
fi

# nvm の配置場所と、入れる Node.js のバージョンを決める
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
NVM_VERSION="${NVM_VERSION:-v0.40.5}"
NODE_VERSION="${NODE_VERSION:---lts}"

# WSL では Windows 側 Node.js が PATH に見えることがある
CURRENT_NODE_PATH="$(command -v node || true)"
CURRENT_NPM_PATH="$(command -v npm || true)"

if [ -n "$CURRENT_NODE_PATH" ] && [[ "$CURRENT_NODE_PATH" == /mnt/c/* ]]; then
  echo "[WARN] Windows Node.js detected: $CURRENT_NODE_PATH"
  echo "[INFO] Install Linux Node.js via nvm instead."
fi

if [ -n "$CURRENT_NPM_PATH" ] && [[ "$CURRENT_NPM_PATH" == /mnt/c/* ]]; then
  echo "[WARN] Windows npm detected: $CURRENT_NPM_PATH"
  echo "[INFO] Install Linux npm via nvm instead."
fi

# nvm が未導入ならインストールする
if [ ! -s "$NVM_DIR/nvm.sh" ]; then
  echo "[INFO] Install nvm ${NVM_VERSION}"
  curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
else
  echo "[OK] nvm already installed"
fi

# このスクリプト内で nvm コマンドを使えるように読み込む
# shellcheck disable=SC1091
. "$NVM_DIR/nvm.sh"

echo "[INFO] Install Node.js: ${NODE_VERSION}"

# NODE_VERSION 未指定なら LTS 版を入れる
if [ "$NODE_VERSION" = "--lts" ] || [ "$NODE_VERSION" = "lts/*" ]; then
  nvm install --lts
  nvm use --lts
else
  nvm install "$NODE_VERSION"
  nvm use "$NODE_VERSION"
fi

# 今使っている Node.js を今後のデフォルトにする
INSTALLED_NODE_VERSION="$(node -v)"
nvm alias default "$INSTALLED_NODE_VERSION"

# nvm が PATH を更新したので、シェルのコマンド位置キャッシュを更新する
hash -r

echo "[OK] Node.js installed"
echo "[INFO] node path: $(command -v node)"
echo "[INFO] npm path : $(command -v npm)"
node -v
npm -v