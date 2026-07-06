# WSL2 Linux Web Server Lab

WSL2 Ubuntu を訓練環境として使用し、空の Linux 環境に Apache / PHP-FPM / MySQL を使った LAMP 環境を自動構築するための学習用リポジトリです。

このリポジトリの目的は、WSL2 そのものを自動化することではありません。  
本番環境や VPS のように、Linux 環境が用意された後の初期構築作業を、シェルスクリプトで再現可能にすることを目的としています。

## 目的

手作業で理解した Linux Web サーバー構築手順を、分隊型シェルスクリプトとして整理し、再現可能な形にします。

具体的には、以下の作業を自動化・検証対象とします。

- apt によるパッケージ管理
- Apache のインストールと起動確認
- PHP-FPM のインストールと Apache 連携確認
- MySQL のインストールと起動確認
- データベースと専用ユーザーの作成
- Web 公開ディレクトリの作成
- Linux 権限の設定
- PHP 動作確認用ファイルの作成
- HTTP 疎通確認
- 最終ヘルスチェック
- ログ確認導線の整理

追加メニューとして、以下も検証します。

- SSH 接続設定
- SSL / HTTPS 設定
- Composer / Node.js / npm などの開発ツール導入

## 対象外

以下はこのリポジトリの自動化対象外です。

- Windows 側の設定
- WSL2 のインストール
- Windows Terminal の設定
- Ubuntu 初回起動時の Unix ユーザー作成
- Windows PowerShell による WSL 操作自動化

このリポジトリでは、あくまで **Linux に入った後の Web サーバー構築作業** を扱います。

## 設計思想

このプロジェクトでは、巨大な一撃スクリプトではなく、処理を役割ごとに分割した **分隊型自動構築** を採用します。

```text
外から見れば一撃。
中身は分隊。
失敗したら即停止。
最後に証拠を出す。
```

`run.sh` は全体の順番を管理する司令塔です。  
Apache、PHP-FPM、MySQL、Webroot、ヘルスチェックなどの実処理は、それぞれ専用のスクリプトに分離します。

これにより、以下を実現します。

- 処理ごとに読みやすい
- 失敗箇所を追いやすい
- 一部だけ修正・再実行しやすい
- SSH / SSL / Dev Tools などを本編と分離できる
- Docker 版や WordPress 版へ応用しやすい
- Git のコミット単位で成長履歴を残しやすい

## ディレクトリ構成

```text
wsl2-linux-web-server-lab/
├── README.md
├── .env.example
├── .gitignore
├── scripts/
│   ├── run.sh
│   ├── run-dev-tools.sh
│   ├── bootstrap/
│   │   └── 00-apt-base.sh
│   ├── lib/
│   │   ├── common.sh
│   │   └── validate-env.sh
│   ├── apache/
│   │   ├── install.sh
│   │   └── check.sh
│   ├── php/
│   │   ├── install.sh
│   │   └── check.sh
│   ├── mysql/
│   │   ├── install.sh
│   │   ├── create-db.sh
│   │   └── check.sh
│   ├── webroot/
│   │   ├── create.sh
│   │   ├── permission.sh
│   │   └── create-test-index.sh
│   ├── health/
│   │   └── final-check.sh
│   └── dev-tools/
│       ├── install-composer.sh
│       ├── install-node.sh
│       └── check.sh
└── docs/
    ├── 01-overview.md
    ├── 02-apache.md
    ├── 03-php.md
    ├── 04-mysql.md
    ├── 05-permission.md
    ├── 06-final-check.md
    ├── 07-ssh.md
    ├── 08-ssl.md
    ├── 09-dev-tools.md
    ├── 90-ansible.md
    └── 99-troubleshooting.md
```

## 各スクリプトの役割

| ファイル                                | 役割                                                      |
| --------------------------------------- | --------------------------------------------------------- |
| `scripts/run.sh`                        | LAMP 本編の実行順序を管理するランナー                     |
| `scripts/bootstrap/00-apt-base.sh`      | git / curl / ca-certificates / unzip などの基本装備を導入 |
| `scripts/lib/common.sh`                 | ログ表示・共通関数・エラー処理                            |
| `scripts/lib/validate-env.sh`           | `.env` の必須項目チェック                                 |
| `scripts/apache/install.sh`             | Apache のインストール                                     |
| `scripts/apache/check.sh`               | Apache の起動確認と HTTP 応答確認                         |
| `scripts/php/install.sh`                | PHP / PHP-FPM / PHP拡張のインストールと Apache 連携       |
| `scripts/php/check.sh`                  | PHP-FPM の動作確認                                        |
| `scripts/mysql/install.sh`              | MySQL のインストール                                      |
| `scripts/mysql/create-db.sh`            | DB と専用ユーザーの作成                                   |
| `scripts/mysql/check.sh`                | MySQL の接続確認                                          |
| `scripts/webroot/create.sh`             | Web 公開ディレクトリの作成                                |
| `scripts/webroot/permission.sh`         | 所有者・グループ・権限の設定                              |
| `scripts/webroot/create-test-index.sh`  | PHP 動作確認用 `index.php` の作成                         |
| `scripts/health/final-check.sh`         | 最終ヘルスチェック                                        |
| `scripts/run-dev-tools.sh`              | Composer / Node.js / npm 導入用ランナー                   |
| `scripts/dev-tools/install-composer.sh` | Linux 側 Composer のインストール                          |
| `scripts/dev-tools/install-node.sh`     | nvm 経由で Node.js / npm をインストール                   |
| `scripts/dev-tools/check.sh`            | 開発ツールの最終確認                                      |

## 最初に必要な手動準備

完全に空の Linux 環境では、GitHub からこのリポジトリを clone するために、最初だけ `git` と `ca-certificates` を手動で入れます。

```bash
sudo apt update
sudo apt install -y git ca-certificates
```

`git` は GitHub からリポジトリを取得するために必要です。

`ca-certificates` は、HTTPS 通信で接続先の証明書を検証するための証明書パッケージです。  
GitHub へ `https://` で安全に接続するため、最初の手動準備に含めています。

その後、リポジトリを clone します。

```bash
git clone https://github.com/Leon20200809/wsl2-linux-web-server-lab.git
cd wsl2-linux-web-server-lab
```

## sudo について

このリポジトリのスクリプトでは、`apt install` や `service restart` など、管理者権限が必要な処理で `sudo` を使用します。

`sudo` のパスワードは `.env` には書きません。  
`.env` は DB 名、DB ユーザー、公開ディレクトリなど、構築対象の設定値を管理するためのファイルです。

一方、`sudo` パスワードは Linux ユーザー本人の権限確認に使う重要な認証情報のため、設定ファイルには保存せず、実行時にターミナル上で入力します。

スクリプト実行時は、最初に `sudo -v` で sudo 権限を確認します。  
ここで一度パスワードを入力すると、一定時間は sudo 認証が有効になり、その間は後続の `apt install` やサービス操作を続けて実行できます。

ただし、処理に時間がかかった場合は、途中で再度 sudo パスワードを求められることがあります。  
これは正常な挙動です。

## 環境変数

`.env.example` をコピーして `.env` を作成します。

```bash
cp .env.example .env
```

`.env.example` の例です。

```env
PROJECT_NAME=lamp_lab
PROJECT_DIR=/var/www/html/lamp_lab
PROJECT_URL=http://localhost/lamp_lab

DB_NAME=lamp_lab_db
DB_USER=lamp_lab_user
DB_PASSWORD=change_me_strong_password
```

`.env` は秘密情報を含むため Git 管理しません。  
Git に含めるのは `.env.example` のみです。

## LAMP本編の実行方法

```bash
cp .env.example .env
./scripts/run.sh
```

`run.sh` は以下の順番で LAMP 本編を構築します。

```text
run.sh
  ↓
sudo -v
  ↓
bootstrap
  ↓
apache
  ↓
php-fpm
  ↓
mysql
  ↓
webroot
  ↓
final-check
```

## 構築後の確認URL

HTTP:

```text
http://localhost/lamp_lab
```

SSL / HTTPS 追加メニューを設定した場合:

```text
https://localhost/lamp_lab
```

## 最終ヘルスチェック

LAMP 本編の最後に、`scripts/health/final-check.sh` で状態を確認します。

確認対象:

- Apache 起動状態
- HTTP 応答
- PHP-FPM 起動状態
- OPcache
- Apache `proxy_fcgi_module`
- MySQL 起動状態
- MySQL root 接続
- 専用 DB ユーザー接続
- Webroot の存在
- Webroot の所有者・グループ・権限
- Web経由での PHP-FPM 実行
- 主要ポートの待受

成功例:

```text
[OK] LAMP final check completed successfully

RESULT: Apache + PHP-FPM + MySQL + Webroot are ready.
```

## Dev Tools 追加メニュー

LAMP 構築後、Laravel やフロントエンドビルドへ進むために、Composer / Node.js / npm を追加導入します。

実行:

```bash
./scripts/run-dev-tools.sh
```

個別実行:

```bash
./scripts/dev-tools/install-composer.sh
./scripts/dev-tools/install-node.sh
./scripts/dev-tools/check.sh
```

確認:

```bash
command -v php
command -v composer
command -v node
command -v npm

php -v
composer --version
node -v
npm -v
```

WSL では Windows 側の PATH が混ざるため、`composer` / `node` / `npm` が `/mnt/c/...` 配下を指す場合があります。

このプロジェクトでは、Linux 側でのアプリ開発を想定し、以下のような状態を期待します。

```text
/usr/bin/php
/usr/local/bin/composer
/home/espo/.nvm/versions/node/vXX.XX.X/bin/node
/home/espo/.nvm/versions/node/vXX.XX.X/bin/npm
```

## 追加メニュー

LAMP 本編とは別に、以下の追加メニューを検証します。

### SSH

SSH 接続を使い、外部ターミナルや別環境から検証用 Ubuntu へ入るための練習です。

検証済みの構成:

```text
メインUbuntu / Windows Git Bash
  ↓ SSH :10022
検証用 Ubuntu-26.04
```

### SSL / HTTPS

`mkcert` を使い、ローカル環境で `https://localhost/lamp_lab` を表示できるようにします。

検証済み:

```text
HTTP/1.1 200 OK
Apache + PHP-FPM webroot check OK.
PHP SAPI: fpm-fcgi
```

### Dev Tools

Composer / nvm / Node.js / npm を導入し、Laravel、Vite、Tailwind CSS、React、Next.js などの開発に進むための追加装備です。

## 想定する実行環境

- Ubuntu
- WSL2 Ubuntu
- Linux サーバー学習環境
- 空の VPS を想定した練習環境

このリポジトリでは WSL2 Ubuntu を使用していますが、目的は WSL2 固有の操作ではなく、Linux サーバー構築手順の理解と自動化です。

## 学習テーマ

このリポジトリでは、以下を学習対象とします。

- Linux の基本操作
- apt によるパッケージ管理
- Apache の役割
- PHP-FPM と Web サーバーの連携
- MySQL の初期設定
- DB ユーザーと権限管理
- Linux の所有者・グループ・パーミッション
- シェルスクリプトによる自動化
- 再実行しやすい構成設計
- ヘルスチェックとログ確認
- SSH 接続
- SSL / HTTPS
- Composer / Node.js / npm
- WSL 特有の PATH の罠

## 今後の拡張候補

- WordPress インストール自動化
- Laravel 最小アプリ配置
- Apache VirtualHost による Laravel `public` 公開
- Next.js の Node.js サーバー起動検証
- Apache / Nginx リバースプロキシ検証
- Docker Engine 自動構築版への応用
- Docker Compose による WordPress / Next.js 環境構築版への応用
- Ansible 化

## 現在の状態

```text
LAMP MVP completed.
Additional menus: SSH / SSL / Dev Tools in progress.
```

現在、このプロジェクトでは以下を証拠付きで確認済みです。

```text
Apache HTTP  :80
Apache HTTPS :443
PHP-FPM      :fpm-fcgi
MySQL        :3306 / 33060
Webroot      :/var/www/html/lamp_lab
SSH          :10022
Composer     :/usr/local/bin/composer
Node.js/npm  :nvm managed
```

この段階で、Linux 上に Web 公開基盤を構築し、サービス起動、ポート確認、PHP 実行、DB 接続、権限設定、SSH 接続、HTTPS 表示、開発ツール導入まで一通り検証できています。
