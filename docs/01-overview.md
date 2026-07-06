# Overview

このドキュメントは、LAMP 自動構築プロジェクトの作業手順メモです。

README にはプロジェクト全体の説明を書き、このファイルでは実装・検証の流れを記録します。

## 前提

空の Linux 環境に入った後の作業を対象にします。

WSL2 のインストール、Windows Terminal の設定、初期 Unix ユーザー作成は対象外です。

本プロジェクトの目的は、Linux 上で Apache / PHP-FPM / MySQL を使った Web 公開基盤を構築し、再現可能な形でスクリプト化することです。

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

## 基本の実行手順

```bash
cp .env.example .env
./scripts/run.sh
```

`run.sh` は、LAMP 構築本編を順番に実行します。

現在の本編構成:

```text
run.sh
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

## sudo について

スクリプト内では、`apt install` や `service restart` などで `sudo` を使います。

sudo パスワードは `.env` には書きません。
必要な場合は、実行時にターミナルで入力します。

`run.sh` の最初で `sudo -v` を実行し、sudo 権限を確認します。
認証済みの間は、後続の sudo 処理を続けて実行できます。

処理に時間がかかった場合、途中で再度パスワードを求められることがあります。

## 現在の実装状態

LAMP 構築 MVP は完了済みです。

現在、以下の部隊を実装・検証済みです。

```text
scripts/bootstrap/00-apt-base.sh
scripts/apache/install.sh
scripts/apache/check.sh
scripts/php/install.sh
scripts/php/check.sh
scripts/mysql/install.sh
scripts/mysql/create-db.sh
scripts/mysql/check.sh
scripts/webroot/create.sh
scripts/webroot/permission.sh
scripts/webroot/create-test-index.sh
scripts/health/final-check.sh
```

## 実装済みの内容

### Bootstrap

`scripts/bootstrap/00-apt-base.sh` では、構築に必要な最低限の道具を導入します。

主な処理:

- OS 情報の出力
- 実行ユーザー情報の出力
- `apt` コマンドの存在確認
- sudo 権限の確認
- `apt update`
- `git` / `curl` / `ca-certificates` / `unzip` の導入
- 各コマンドのバージョン確認

### Apache

Apache2 をインストールし、HTTP 応答を確認します。

確認済み:

```text
Apache/2.4.66 (Ubuntu)
HTTP/1.1 200 OK
```

### PHP-FPM

Apache モジュール方式ではなく、PHP-FPM / FastCGI 方式を採用しました。

確認済み:

```text
PHP 8.5.4
PHP_FPM_SERVICE: php8.5-fpm
PHP_FPM_OK:fpm-fcgi
```

Xserver 上の WordPress サイトヘルスで `PHP SAPI: fpm-fcgi` を確認したため、本プロジェクトでも実務環境に近い PHP-FPM 方式を採用しています。

### MySQL

MySQL Server をインストールし、`.env` の値から DB と専用ユーザーを作成します。

確認済み:

```text
mysql-server 8.4.10-0ubuntu0.26.04.1
DB_NAME: lamp_lab_db
DB_USER: lamp_lab_user
```

専用ユーザーでの接続確認:

```text
selected_database | mysql_user
lamp_lab_db       | lamp_lab_user@localhost
```

### Webroot

`.env` の `PROJECT_DIR` を元に公開ディレクトリを作成します。

検証時の値:

```text
PROJECT_DIR=/var/www/html/lamp_lab
PROJECT_URL=http://localhost/lamp_lab
```

権限方針:

```text
所有者: 作業ユーザー
グループ: www-data
ディレクトリ: 2775
ファイル: 664
```

確認用 `index.php` を配置し、Apache + PHP-FPM 経由で表示確認しています。

### Final Check

`scripts/health/final-check.sh` により、構築結果を一括確認します。

確認する内容:

- 必要コマンドの存在
- Apache 起動状態
- HTTP 応答
- PHP-FPM 起動状態
- OPcache
- Apache `proxy_fcgi_module`
- MySQL 起動状態
- MySQL root 接続
- 専用DBユーザー接続
- Webroot の存在
- Webroot の権限
- Web経由での PHP-FPM 実行
- 主要ポートの待受

最終確認結果:

```text
[OK] LAMP final check completed successfully

RESULT: Apache + PHP-FPM + MySQL + Webroot are ready.
```

## 検証済み環境

検証用環境:

```text
Ubuntu-26.04
/home/espo/wsl2-linux-web-server-lab
```

確認済みの主な構成:

```text
Apache/2.4.66
PHP 8.5.4
PHP-FPM: php8.5-fpm
MySQL 8.4.10
Webroot: /var/www/html/lamp_lab
```

## 発生した主なトラブル

### Apache の80番ポート競合

別の Ubuntu 環境で Apache が起動していたため、検証用 Ubuntu-26.04 の Apache が起動できませんでした。

確認コマンド:

```bash
sudo ss -ltnp | grep ':80'
```

対応:

```bash
sudo service apache2 stop
```

### PHP OPcache パッケージ名

最初に `php-opcache` を必須パッケージとして指定したところ、Ubuntu-26.04 では存在しないパッケージとして扱われました。

対応:

```text
php-opcache は必須インストール対象から外す。
PHP本体導入後に php -m で OPcache の有無を確認する。
```

確認結果:

```text
Zend OPcache
```

### MySQL の33060番ポート競合

メインUbuntu側の MySQL が MySQL X Plugin 用の `33060` 番ポートを使用していたため、検証用 Ubuntu-26.04 側の MySQL が起動できませんでした。

確認コマンド:

```bash
sudo ss -ltnp | grep -E ':3306|:33060'
sudo tail -n 80 /var/log/mysql/error.log
```

対応:

```bash
sudo service mysql stop
```

### MySQL SQLエイリアス名

確認SQLで `current_user` をエイリアス名に使ったところ、MySQLで構文エラーになりました。

修正前:

```sql
SELECT DATABASE() AS current_database, USER() AS current_user;
```

修正後:

```sql
SELECT DATABASE() AS selected_database, USER() AS mysql_user;
```

## 追加メニュー

LAMP 本編とは別に、追加メニューとして SSH と SSL / HTTPS を検証しています。

SSH や SSL は強い設定変更を含むため、本編の `run.sh` には混ぜず、追加メニューとして分離します。

### SSH

対象:

```text
scripts/ssh/install.sh
scripts/ssh/configure.sh
scripts/ssh/check.sh
```

目的:

```text
メインUbuntu / Windows Git Bash
  ↓ SSH :10022
検証用 Ubuntu-26.04
```

確認済み:

```text
[OK] ssh service is running
[OK] sshd effective port OK: 10022
[OK] ssh.socket is disabled
[OK] SSH is listening on port 10022
[OK] port 22 is not listening
[OK] SSH check completed successfully
```

SSHでは、`ssh.socket` が22番を握る問題や、複数Ubuntu間の10022番ポート競合を確認しました。

### SSL / HTTPS

対象:

```text
scripts/ssl/install-mkcert.sh
scripts/ssl/create-cert.sh
scripts/ssl/configure-apache.sh
scripts/ssl/check.sh
```

予定または検証済みの内容:

- `mkcert` によるローカルCA作成
- `localhost` 用証明書作成
- Apache SSL VirtualHost 設定
- 443番ポート待受確認
- `https://localhost/lamp_lab/` 表示確認
- Windows Chrome 側で rootCA を信頼

確認済み:

```text
HTTP/1.1 200 OK
Apache + PHP-FPM webroot check OK.
PHP SAPI: fpm-fcgi
```

## 今後の予定

次の候補:

1. `scripts/ssh/` の内容を整理して `run-ssh.sh` を作成
2. `scripts/ssl/` を手動手順から自動化
3. `docs/08-ssl.md` の検証結果を整理
4. Ansible 化の検討
5. README を最終構成に合わせて更新

## 作業メモ

### run.sh の役割

`run.sh` は LAMP 本編の順番だけを管理します。
細かい処理は各部隊スクリプトに任せます。

現在の流れ:

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

### 追加メニューを分ける理由

SSHやSSLは、本編LAMP構築とは別扱いにします。

理由:

```text
SSH設定は接続不能リスクがある
SSL設定は証明書やブラウザ信頼が絡む
環境依存が強い
本編run.shを汚さない
```

そのため、追加メニューは別ランナーで管理します。

予定:

```text
scripts/run-ssh.sh
scripts/run-ssl.sh
```

## 現在の結論

LAMP構築MVPは完了しました。

現在、このプロジェクトでは以下を証拠付きで確認済みです。

```text
Apache HTTP :80
PHP-FPM     :fpm-fcgi
MySQL       :3306 / 33060
Webroot     :/var/www/html/lamp_lab
SSH         :10022
HTTPS       :443
```

この段階で、Linux上に Web 公開基盤を構築し、サービス起動、ポート確認、PHP実行、DB接続、権限設定、SSH接続、HTTPS表示まで一通り検証できています。
