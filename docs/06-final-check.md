# Final Check

`final-check.sh` は、LAMP環境の構築結果をまとめて確認する最終チェック用スクリプトです。

このスクリプトでは、インストールや設定変更は行いません。
現在の環境が、Apache / PHP-FPM / MySQL / Webroot まで正常に構築されているかを確認します。

## この部隊の目的

Final Check 部隊では、以下を一括確認します。

- 必要コマンドの存在確認
- Apache2 の起動確認
- HTTP 応答確認
- PHP-FPM の起動確認
- OPcache の確認
- Apache の PHP-FPM 連携確認
- MySQL の起動確認
- MySQL root 接続確認
- 専用DBユーザーでの接続確認
- Webroot の存在確認
- `index.php` の存在確認
- Webroot の所有者・グループ・権限確認
- Apache + PHP-FPM 経由での Web 表示確認
- 主要ポートの待受確認

## 対象スクリプト

```text
scripts/health/final-check.sh
```

## 実行方法

```bash
./scripts/health/final-check.sh
```

`run.sh` に組み込む場合は、最後に以下のような流れで実行します。

```text
STEP 99: FINAL CHECK
```

## 確認する環境変数

`.env` から以下の値を読み込みます。

```text
PROJECT_NAME
PROJECT_DIR
PROJECT_URL
DB_NAME
DB_USER
DB_PASSWORD
```

検証時の値:

```text
PROJECT_NAME: lamp_lab
PROJECT_DIR: /var/www/html/lamp_lab
PROJECT_URL: http://localhost/lamp_lab
DB_NAME: lamp_lab_db
DB_USER: lamp_lab_user
DB_PASSWORD: ********
```

`DB_PASSWORD` はログにそのまま表示せず、伏せ字にします。

## コマンド確認

LAMP構築に必要な主要コマンドが存在するか確認します。

確認対象:

```text
apache2
php
mysql
curl
ss
```

実行結果:

```text
[OK] command found: apache2
[OK] command found: php
[OK] command found: mysql
[OK] command found: curl
[OK] command found: ss
```

## Apache確認

Apache本体とHTTP応答を確認します。

確認内容:

- Apache バージョン
- Apache サービス起動状態
- `http://localhost/` へのHTTP応答

実行結果:

```text
Server version: Apache/2.4.66 (Ubuntu)
[OK] apache2 service is running
[OK] Apache HTTP response OK: http://localhost/
```

この結果により、Apache が起動し、80番ポートでHTTP応答を返せることを確認しました。

## PHP-FPM確認

PHP本体、PHP-FPMサービス、Apacheとの連携を確認します。

確認内容:

- PHPバージョン
- PHP-FPMサービス名
- PHP-FPMサービス起動状態
- OPcache の有無
- Apache `proxy_fcgi_module`
- Apache設定構文

検証用 Ubuntu-26.04 では、PHP 8.5.4 が導入されました。

```text
PHP_VERSION: 8.5
PHP_FPM_SERVICE: php8.5-fpm
PHP 8.5.4 (cli)
with Zend OPcache v8.5.4
```

実行結果:

```text
[OK] php8.5-fpm service is running
[OK] Zend OPcache is available
[OK] Apache proxy_fcgi_module is enabled
[OK] Apache config syntax OK
```

`proxy_fcgi_module` が有効であることにより、Apache から PHP-FPM に処理を渡せる状態であることを確認しました。

## MySQL確認

MySQL本体、サービス状態、root接続、専用DBユーザー接続を確認します。

検証時のMySQLバージョン:

```text
mysql  Ver 8.4.10-0ubuntu0.26.04.1 for Linux on x86_64 ((Ubuntu))
```

実行結果:

```text
[OK] mysql service is running
[OK] MySQL root connection OK
[OK] MySQL user connection OK: lamp_lab_user@localhost -> lamp_lab_db
```

この結果により、MySQL Server が起動しており、`.env` で作成した専用ユーザーが対象DBへ接続できることを確認しました。

## Webroot確認

`.env` で指定した公開ディレクトリと、確認用 `index.php` の存在を確認します。

実行結果:

```text
[OK] PROJECT_DIR exists: /var/www/html/lamp_lab
[OK] index.php exists: /var/www/html/lamp_lab/index.php
```

## 権限確認

Webroot の所有者、グループ、権限を確認します。

実行結果:

```text
drwxrwsr-x 2 espo www-data 4096 Jul  2 15:28 /var/www/html/lamp_lab
-rw-rw-r-- 1 espo www-data 701 Jul  2 15:28 /var/www/html/lamp_lab/index.php
```

確認結果:

```text
[OK] PROJECT_DIR owner OK: espo
[OK] PROJECT_DIR group OK: www-data
[OK] PROJECT_DIR mode OK: 2775
[OK] index.php owner OK: espo
[OK] index.php group OK: www-data
[OK] index.php mode OK: 664
```

この結果により、以下の権限設計が成立していることを確認しました。

```text
作業ユーザー espo が編集できる
Apache / PHP-FPM が www-data グループ経由で読める
ディレクトリは setgid 付きでグループ継承しやすい
```

## Webアプリケーション確認

`PROJECT_URL` にHTTPアクセスし、Apache + PHP-FPM 経由で確認用ページが表示できるか確認します。

確認URL:

```text
http://localhost/lamp_lab/
```

実行結果:

```text
[OK] Project URL response OK: http://localhost/lamp_lab/
[OK] Webroot test message found
[OK] Web PHP SAPI is fpm-fcgi
```

特に重要なのは以下です。

```text
[OK] Web PHP SAPI is fpm-fcgi
```

これは、CLIでPHPを実行したのではなく、Apache経由でPHP-FPMが動作していることを示す証拠です。

構成としては以下が成立しています。

```text
ブラウザ / curl
  ↓
Apache
  ↓ proxy_fcgi
PHP-FPM
  ↓
index.php 実行
```

## ポート確認

主要ポートの待受状態を確認します。

確認対象:

```text
80    = HTTP / Apache
3306  = MySQL
33060 = MySQL X Plugin
```

実行結果:

```text
LISTEN 127.0.0.1:3306   users:(("mysqld",pid=32122,fd=33))
LISTEN 127.0.0.1:33060  users:(("mysqld",pid=32122,fd=31))
LISTEN *:80             users:(("apache2",pid=32404,fd=4),("apache2",pid=32403,fd=4),("apache2",pid=31973,fd=4))
```

この結果により、Apache と MySQL が想定ポートで待受していることを確認しました。

## 実行時の sudo について

`final-check.sh` を単体実行した場合、途中で `sudo` パスワードを求められることがあります。

例:

```text
[sudo: authenticate] Password:
```

これは、サービス状態確認やroot接続確認で `sudo` を使うためです。

`run.sh` 経由で実行する場合は、冒頭で `sudo -v` による認証確認を行うため、sudo認証キャッシュが有効な間は再入力が不要になります。

## 最終結果

最終的に以下の結果を確認しました。

```text
[OK] LAMP final check completed successfully

RESULT: Apache + PHP-FPM + MySQL + Webroot are ready.
```

この結果により、以下の構成が完成していることを確認できました。

```text
空の Linux
  ↓
apt 初期装備
  ↓
Apache2 インストール
  ↓
PHP-FPM インストール
  ↓
MySQL Server インストール
  ↓
DB作成・専用ユーザー接続確認
  ↓
Webroot 作成
  ↓
権限設定
  ↓
Apache + PHP-FPM 経由でWeb表示確認
  ↓
final-check 成功
```

## 学んだこと

### 1. 構築後は必ず証拠を取る

インストールできたかどうかだけでは不十分です。

実務では、以下のように確認結果を残すことが重要です。

```text
サービスが起動している
HTTP応答が返る
PHP-FPM経由でPHPが実行される
DBへ専用ユーザーで接続できる
Webrootの権限が正しい
```

`final-check.sh` は、この確認を一括で行うための証拠提出スクリプトです。

### 2. CLI確認とWeb確認は別物

ターミナルで `php -v` が動いても、Apache経由でPHPが動いているとは限りません。

そのため、Web経由で以下を確認しました。

```text
PHP SAPI: fpm-fcgi
```

これにより、PHP-FPM経由でPHPが実行されていることを確認できます。

### 3. 権限は表示確認とセットで見る

`chown` や `chmod` を実行しただけでは、正しく動いているとは言えません。

実際にWebrootへ `index.php` を配置し、Apache + PHP-FPM 経由で表示できることまで確認しました。

### 4. ポート確認はトラブル対応に直結する

Apacheでは80番、MySQLでは3306番と33060番が重要でした。

サービス起動失敗時は、まずポート使用状況を確認します。

```bash
sudo ss -ltnp | grep -E ':80|:3306|:33060'
```

## 現在の結論

`final-check.sh` により、LAMP構築MVPの完成を証拠付きで確認できました。

この段階で、以下を説明できます。

```text
Linux上で Apache / PHP-FPM / MySQL を用いたWeb公開基盤を構築できる
サービス起動確認、HTTP確認、DB接続確認、権限確認まで行える
構築手順をシェルスクリプト化し、再現可能な形で管理できる
```

本編MVPはここで完了です。

次の追加メニューでは、SSH接続、ローカルSSL、Ansible化へ進みます。
