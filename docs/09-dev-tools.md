# Dev Tools

この章では、LAMP構築後にアプリケーション開発へ進むための追加ツールを導入します。

LAMP本編では Apache / PHP-FPM / MySQL / Webroot の構築を扱います。  
Dev Tools では、Laravel やフロントエンドビルドに必要な Composer / Node.js / npm を扱います。

## この部隊の目的

Dev Tools 部隊では、以下を導入します。

- Composer
- nvm
- Node.js
- npm

## 対象スクリプト

```text
scripts/run-dev-tools.sh
scripts/dev-tools/install-composer.sh
scripts/dev-tools/install-node.sh
scripts/dev-tools/check.sh
```

## なぜLAMP本編に混ぜないか

Composer や Node.js は、Webサーバーを動かすだけなら必須ではありません。

LAMP本編の目的:

```text
Apache
PHP-FPM
MySQL
Webroot
```

Dev Tools の目的:

```text
Laravel
PHPライブラリ管理
Vite
Tailwind CSS
React / Next.js
npm scripts
```

役割が違うため、`scripts/run.sh` には混ぜず、追加メニューとして `scripts/run-dev-tools.sh` に分離します。

## Composerとは

Composer は PHP の依存関係管理ツールです。

Laravel や PHPUnit、Guzzle などのPHPライブラリを導入・管理するために使います。

主な用途:

```text
Laravelインストール
PHPライブラリ管理
autoload
PHPUnit
Guzzle
.env系ライブラリ
```

## Node.js / npmとは

Node.js は JavaScript の実行環境です。

npm は Node.js と一緒に使うパッケージ管理ツールです。

主な用途:

```text
Vite
Tailwind CSS
React
Next.js
Laravel Vite
npm scripts
フロントエンドビルド
```

## 実行手順

LAMP本編を先に実行します。

```bash
cp .env.example .env
./scripts/run.sh
```

その後、Dev Tools を実行します。

```bash
./scripts/run-dev-tools.sh
```

## Node.jsのバージョン指定

通常はLTS版を入れます。

```bash
./scripts/run-dev-tools.sh
```

特定バージョンを指定したい場合は、`NODE_VERSION` を指定します。

```bash
NODE_VERSION=24 ./scripts/run-dev-tools.sh
```

## 確認

```bash
./scripts/dev-tools/check.sh
```

確認するコマンド:

```text
php
composer
node
npm
```

成功例:

```text
[OK] php
[OK] composer
[OK] node
[OK] npm
[OK] dev-tools check completed successfully
```

## 現在の位置づけ

この章は、LAMP構築後にアプリケーション開発へ進むための追加装備です。

現在の構成:

```text
LAMP本編
  ↓
Apache / PHP-FPM / MySQL / Webroot

追加メニュー
  ↓
SSH
SSL / HTTPS
Dev Tools
```

Dev Tools を入れることで、次の段階に進めます。

```text
PHP素のPDOアプリ
Laravel最小アプリ
WordPress配置
Vite / Tailwind ビルド
React / Next.js 検証
```

## 結論

Composer と Node.js / npm を導入することで、WSL2 Ubuntu 上のLAMP環境を、単なるWebサーバー構築演習からアプリケーション開発環境へ拡張できます。

```text
LAMP
  +
SSH
  +
HTTPS
  +
Composer
  +
Node.js / npm
```

この段階で、PHPアプリ・Laravel・WordPress・フロントエンドビルドまで扱える土台になります。

## WSL特有の注意点

WSLでは、Linux側のPATHにWindows側のPATHが混ざることがあります。

そのため、WSL Ubuntu内で `composer` / `node` / `npm` を実行しても、Linux側ではなく Windows側のツールを拾う場合があります。

例:

```bash
command -v composer
```

Windows / Laragon側を拾っている例:

```text
/mnt/c/laragon/bin/composer/composer
```

この状態では、WSL Ubuntu内で `composer` を実行していても、実体はWindows側のComposerです。

LaravelやPHPアプリをLinux側の Apache / PHP-FPM / MySQL 上で扱う場合は、Linux側のComposerを使う方が自然です。

期待するComposerの場所:

```text
/usr/local/bin/composer
```

確認:

```bash
command -v composer
composer --version
```

Linux側Composerを使えている例:

```text
/usr/local/bin/composer
PHP version 8.5.4 (/usr/bin/php8.5)
```

Windows Git Bashで `composer` を実行した場合は、Laragon側のComposer / PHPを使うことがあります。

例:

```text
C:\laragon\bin\php\php-8.3.30-Win32-vs16-x64\php.exe
```

これはWindows側で作業しているなら正常です。

重要なのは、同じ `composer` コマンドでも、どの環境で実行しているかによって実体が変わることです。

```text
Windows Git Bash
  ↓
Windows / Laragon 側 Composer

WSL Ubuntu
  ↓
Linux 側 Composer

SSHでWSLへ接続
  ↓
Linux 側 Composer
```

そのため、開発ツール確認時はコマンド名だけではなく、必ず実体のパスを確認します。

```bash
command -v composer
command -v node
command -v npm
```

## nvmの注意点

Node.js は `nvm` 経由で導入します。

`nvm` で入れたNode.jsは、通常以下のような場所に保存されます。

```text
/home/espo/.nvm/versions/node/v24.18.0/bin/node
/home/espo/.nvm/versions/node/v24.18.0/bin/npm
```

ただし、Node.jsがインストール済みでも、現在のシェルが `nvm` を読み込んでいないと `node` コマンドは使えません。

つまり、以下は別物です。

```text
Node.jsがインストールされている
Node.jsが今のシェルで使える
```

`node` が見つからない例:

```text
Command 'node' not found
```

この場合でも、`~/.nvm/versions/node/` 配下にNode.js本体が存在している可能性があります。

現在のシェルで `nvm` を使えるようにするには、以下を実行します。

```bash
export NVM_DIR="$HOME/.nvm"
. "$NVM_DIR/nvm.sh"
```

`.` は `source` と同じ意味です。

つまり、以下と同じです。

```bash
source "$NVM_DIR/nvm.sh"
```

これは `nvm.sh` を今のシェルに読み込む操作です。

その後、使用するNode.jsを有効化します。

```bash
nvm use --lts
```

確認:

```bash
command -v node
command -v npm
node -v
npm -v
```

成功例:

```text
/home/espo/.nvm/versions/node/v24.18.0/bin/node
/home/espo/.nvm/versions/node/v24.18.0/bin/npm
v24.18.0
11.16.0
```

## nvmとset -uの注意点

このプロジェクトのシェルスクリプトでは、基本的に以下を使います。

```bash
set -Eeuo pipefail
```

これは、エラーを早く検出するための厳格モードです。

ただし、`set -u` は「未定義変数を使ったらエラーにする」設定です。

`nvm.sh` の内部には、未定義変数を前提にしている箇所があるため、`set -u` と相性が悪い場合があります。

実際に以下のエラーが発生しました。

```text
/home/espo/.nvm/nvm.sh: line 4117: PROVIDED_VERSION: unbound variable
```

そのため、`install-node.sh` では、`nvm` を読み込んで操作する間だけ `set +u` で一時的に解除します。

```bash
set +u

. "$NVM_DIR/nvm.sh"

nvm install --lts
nvm use --lts

set -u
```

本質:

```text
普段の自作スクリプト
  ↓
set -u で厳格にする

nvm操作中
  ↓
nvm内部との相性を考えて set +u にする

nvm操作後
  ↓
set -u に戻す
```

これにより、自作スクリプト全体の安全性を保ちつつ、nvmも正常に扱えます。

## Dev Tools確認時の見るべきポイント

Dev Toolsでは、バージョンだけでなく、どの実体を使っているかを確認します。

```bash
command -v php
command -v composer
command -v node
command -v npm
```

理想例:

```text
/usr/bin/php
/usr/local/bin/composer
/home/espo/.nvm/versions/node/v24.18.0/bin/node
/home/espo/.nvm/versions/node/v24.18.0/bin/npm
```

Windows側を拾っている例:

```text
/mnt/c/laragon/bin/composer/composer
/mnt/c/Program Files/nodejs/node.exe
```

この場合は、Linux側の開発環境としては混ざり物がある状態です。

WSL上のLAMP環境でアプリ開発をする場合は、PHP / Composer / Node.js / npm をLinux側で揃える方が安全です。

```text
Linux側 Apache
Linux側 PHP-FPM
Linux側 MySQL
Linux側 Composer
Linux側 Node.js / npm
```

環境を揃えることで、Laravel / Vite / Tailwind CSS / WordPress などの開発時に、Windows側とLinux側の差分によるトラブルを減らせます。
