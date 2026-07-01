# WSL2 Linux Web Server Lab

WSL2 Ubuntu を訓練環境として使用し、空の Linux 環境に Apache / PHP / MySQL の LAMP 環境を自動構築するための学習用 IaC リポジトリです。

このリポジトリの目的は、WSL2 そのものを自動化することではありません。
本番環境や VPS のように、Linux 環境が用意された後の初期構築作業を、シェルスクリプトで再現可能にすることを目的としています。

## 目的

手作業で理解した Linux Web サーバー構築手順を、分隊型シェルスクリプトとして整理し、再現可能な形にします。

具体的には、以下の作業を自動化対象とします。

- apt によるパッケージ管理
- Apache のインストールと起動確認
- PHP のインストールと Apache 連携確認
- MySQL のインストールと起動確認
- データベースと専用ユーザーの作成
- Web 公開ディレクトリの作成
- Linux 権限の設定
- PHP 動作確認用ファイルの作成
- HTTP 疎通確認
- ログ確認導線の整理

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
Apache、PHP、MySQL、Web ルート、ヘルスチェックなどの実処理は、それぞれ専用のスクリプトに分離します。

これにより、以下を実現します。

- 処理ごとに読みやすい
- 失敗箇所を追いやすい
- 一部だけ修正・再実行しやすい
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
│   └── health/
│       └── final-check.sh
└── docs/
    ├── 01-overview.md
    ├── 02-apache.md
    ├── 03-php.md
    ├── 04-mysql.md
    ├── 05-permission.md
    └── 99-troubleshooting.md
```

## 各スクリプトの役割

| ファイル                               | 役割                                       |
| -------------------------------------- | ------------------------------------------ |
| `scripts/run.sh`                       | 全体の実行順序を管理するランナー           |
| `scripts/lib/common.sh`                | ログ表示・共通関数・エラー処理             |
| `scripts/lib/validate-env.sh`          | `.env` の必須項目チェック                  |
| `scripts/apache/install.sh`            | Apache のインストール                      |
| `scripts/apache/check.sh`              | Apache の起動確認                          |
| `scripts/php/install.sh`               | PHP と Apache 連携モジュールのインストール |
| `scripts/php/check.sh`                 | PHP の動作確認                             |
| `scripts/mysql/install.sh`             | MySQL のインストール                       |
| `scripts/mysql/create-db.sh`           | DB と専用ユーザーの作成                    |
| `scripts/mysql/check.sh`               | MySQL の接続確認                           |
| `scripts/webroot/create.sh`            | Web 公開ディレクトリの作成                 |
| `scripts/webroot/permission.sh`        | 所有者・権限の設定                         |
| `scripts/webroot/create-test-index.sh` | PHP 動作確認用ファイルの作成               |
| `scripts/health/final-check.sh`        | 最終ヘルスチェック                         |

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

## 実行方法

```bash
cp .env.example .env
./scripts/run.sh
```

現段階では、MVP としてディレクトリ構成とスクリプト配置を作成済みです。
各スクリプトの中身は、Apache、PHP、MySQL、Web ルート、ヘルスチェックの順に実装していきます。

## 想定する実行環境

- Ubuntu
- WSL2 Ubuntu
- Linux サーバー学習環境
- 空の VPS を想定した練習環境

このリポジトリでは WSL2 Ubuntu を使用していますが、目的は WSL2 固有の操作ではなく、Linux サーバー構築手順の理解と自動化です。

## 完成時のゴール

最終的には、以下のコマンドで LAMP 環境を構築できる状態を目指します。

```bash
./scripts/run.sh
```

構築後、以下の URL で PHP の動作確認ができる状態を目標とします。

```text
http://localhost/lamp_lab
```

また、以下の確認コマンドで各サービスの状態を確認できるようにします。

```bash
sudo service apache2 status
sudo service mysql status
php -v
curl -I http://localhost/lamp_lab
tail -f /var/log/apache2/error.log
```

## 学習テーマ

このリポジトリでは、以下を学習対象とします。

- Linux の基本操作
- apt によるパッケージ管理
- Apache の役割
- PHP と Web サーバーの連携
- MySQL の初期設定
- DB ユーザーと権限管理
- Linux の所有者・グループ・パーミッション
- シェルスクリプトによる自動化
- 再実行しやすい構成設計
- ヘルスチェックとログ確認

## 今後の拡張予定

- `.env` バリデーションの実装
- Apache 自動インストール
- PHP 自動インストール
- MySQL 自動インストール
- DB / DB ユーザー作成
- Web ルート作成
- 権限設定
- PHP 動作確認ファイル作成
- 最終ヘルスチェック
- WordPress インストール自動化
- Docker Engine 自動構築版への応用
- Docker Compose による WordPress 環境構築版への応用

## 現在の状態

```text
MVP scaffold complete.
```

現時点では、分隊型自動構築のディレクトリ構成と空スクリプトを作成済みです。
今後、各部隊スクリプトの中身を順番に実装していきます。
