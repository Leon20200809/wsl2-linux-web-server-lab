# MySQL

MySQL は、Webアプリケーションのデータを保存するためのデータベースサーバーです。

このプロジェクトでは、Apache + PHP-FPM の構成に加えて MySQL Server を導入し、`.env` の値を使ってデータベースと専用ユーザーを自動作成します。

## この部隊の目的

MySQL 部隊では、以下を自動化します。

- MySQL Server のインストール
- MySQL サービスの起動確認
- `.env` の値を使った DB 作成
- `.env` の値を使った DB ユーザー作成
- DB ユーザーへの権限付与
- root 接続確認
- 専用DBユーザーでの接続確認

## 対象スクリプト

```text
scripts/mysql/install.sh
scripts/mysql/create-db.sh
scripts/mysql/check.sh
```

## install.sh の役割

`scripts/mysql/install.sh` では、MySQL Server をインストールします。

導入するパッケージ:

```text
mysql-server
```

インストール後、以下を確認します。

- パッケージ状態
- MySQL バージョン
- MySQL サービス起動

検証用 Ubuntu-26.04 では、以下のバージョンが導入されました。

```text
mysql-server 8.4.10-0ubuntu0.26.04.1 install ok installed
mysql  Ver 8.4.10-0ubuntu0.26.04.1 for Linux on x86_64 ((Ubuntu))
```

## create-db.sh の役割

`scripts/mysql/create-db.sh` では、`.env` の値を読み込み、データベースと専用ユーザーを作成します。

使用する環境変数:

```text
DB_NAME
DB_USER
DB_PASSWORD
```

現在の検証値:

```text
DB_NAME: lamp_lab_db
DB_USER: lamp_lab_user
DB_PASSWORD: ********
```

作成する内容:

- `DB_NAME` のデータベース
- `DB_USER` のMySQLユーザー
- `DB_PASSWORD` によるパスワード設定
- 対象DBへの権限付与

実行結果:

```text
[OK] MySQL DB と専用ユーザー作成完了
```

## DB名・DBユーザー名のバリデーション

`.env` の値をSQLに埋め込むため、DB名とDBユーザー名にはバリデーションを入れています。

許可する文字:

```text
英字 A-Z a-z
数字 0-9
アンダースコア _
```

許可例:

```text
lamp_lab_db
lamp_lab_user
wordpress01
```

禁止例:

```text
lamp-lab
lamp lab
lamp.lab
lamp;drop
```

DB名やDBユーザー名は人間向け文章ではないため、自由度より安全性を優先します。

一方、`DB_PASSWORD` には同じ制限をかけません。
パスワードには記号を使いたいためです。

## check.sh の役割

`scripts/mysql/check.sh` では、MySQL が正しく動作しているか確認します。

確認する内容:

- `mysql --version`
- MySQL サービス状態
- root 接続確認
- 専用DBユーザーでの接続確認

root 接続確認:

```text
+-------------------------+
| mysql_version           |
+-------------------------+
| 8.4.10-0ubuntu0.26.04.1 |
+-------------------------+
```

専用DBユーザーでの接続確認:

```text
+-------------------+-------------------------+
| selected_database | mysql_user              |
+-------------------+-------------------------+
| lamp_lab_db       | lamp_lab_user@localhost |
+-------------------+-------------------------+
```

これにより、`.env` で作成した専用ユーザーが、対象DBへ接続できることを確認できました。

## current_user エラー

最初の確認SQLでは、以下のようなエラーが出ました。

```text
ERROR 1064 (42000) at line 1:
You have an error in your SQL syntax;
check the manual that corresponds to your MySQL server version
for the right syntax to use near 'current_user' at line 1
```

原因は、SQLのエイリアス名に `current_user` を使ったことです。

修正前:

```sql
SELECT DATABASE() AS current_database, USER() AS current_user;
```

修正後:

```sql
SELECT DATABASE() AS selected_database, USER() AS mysql_user;
```

`current_user` は MySQL 側の予約語・特殊関数名と衝突しやすいため、確認用の別名として使わない方が安全です。

## MySQL のポート競合

MySQL の起動時、以下のエラーが発生しました。

```text
Plugin mysqlx reported:
'Setup of bind-address: '127.0.0.1' port: 33060 failed,
bind() failed with error: Address already in use (98).
Do you already have another mysqld server running with Mysqlx ?'
```

原因は、メインUbuntu側で起動していた MySQL がポートを使用していたことでした。

MySQLで確認すべき主なポート:

```text
3306  = 通常のMySQL接続
33060 = MySQL X Plugin 用
```

確認コマンド:

```bash
sudo ss -ltnp | grep -E ':3306|:33060'
```

対応として、メインUbuntu側のMySQLを停止しました。

```bash
sudo service mysql stop
```

その後、検証用 Ubuntu-26.04 側の MySQL が正常に起動しました。

成功確認:

```text
Active: active (running)
Status: "Server is operational"
```

## Dockerでも同じ問題が起きる

DockerでMySQLを立てる場合も、ホスト側に同じポートを公開すると競合します。

例:

```bash
docker run -p 3306:3306 mysql
```

この場合、ホスト側の `3306` を使います。

すでにローカルMySQLが `3306` を使っている場合、Docker側のMySQLは同じポートを使えません。

回避例:

```bash
docker run -p 3307:3306 mysql
```

意味:

```text
ホスト側 3307
↓
コンテナ側 3306
```

ポート競合は、WSL2の複数Ubuntu環境でもDockerでも発生します。

## 学んだこと

### 1. MySQLもポート競合する

Apacheでは80番ポートが競合しました。

MySQLでは、3306番だけでなく、MySQL X Plugin の33060番も競合対象になります。

```text
Apache  → 80 / 443
MySQL   → 3306 / 33060
```

### 2. apt install 後に起動できるとは限らない

MySQL Server のインストールが成功しても、サービス起動で失敗することがあります。

その場合は、まずポート使用状況とエラーログを確認します。

```bash
sudo ss -ltnp | grep -E ':3306|:33060'
sudo tail -n 80 /var/log/mysql/error.log
```

### 3. SQLの確認用エイリアスにも注意する

`current_user` のように、MySQL側で意味を持つ名前は避けた方が安全です。

確認用の列名には、`selected_database` や `mysql_user` のような衝突しにくい名前を使います。

## 現在の結論

MySQL Server のインストール、DB作成、専用ユーザー作成、接続確認は成功しました。

現在の到達点:

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
DB作成
  ↓
専用DBユーザー接続確認
```

これにより、Webアプリケーションがデータを保存するためのDB基盤が整いました。
