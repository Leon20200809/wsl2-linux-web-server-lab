# Apache

Apache は、ブラウザから届いた HTTP リクエストを受け取り、HTML / CSS / JavaScript / PHP などのファイルを返す Web サーバーです。

このプロジェクトでは、まず Apache2 を導入し、`http://localhost/` で HTTP 応答を返せる状態を作ります。

## この部隊の目的

Apache 部隊では、以下を自動化します。

- `apache2` のインストール
- Apache のバージョン確認
- Apache サービスの起動確認
- 起動していない場合の再起動
- `curl -I http://localhost/` による HTTP 疎通確認

## 対象スクリプト

```text
scripts/apache/install.sh
scripts/apache/check.sh
```

## install.sh の役割

`scripts/apache/install.sh` では、Apache2 本体をインストールします。

導入するパッケージ:

```text
apache2
```

インストール後、`dpkg-query` でパッケージ状態を確認します。

確認例:

```text
apache2 2.4.66-2ubuntu2.2 install ok installed
```

## check.sh の役割

`scripts/apache/check.sh` では、Apache が正しく動いているか確認します。

確認する内容:

- `apache2 -v`
- `sudo service apache2 status`
- 必要に応じて `sudo service apache2 restart`
- `curl -I http://localhost/`

成功時の重要な証拠:

```text
Active: active (running)
HTTP/1.1 200 OK
Server: Apache/2.4.66 (Ubuntu)
```

## 現在の実行結果

検証用 Ubuntu-26.04 で Apache2 の導入と起動確認に成功しました。

確認できた Apache バージョン:

```text
Server version: Apache/2.4.66 (Ubuntu)
```

HTTP 疎通確認:

```text
HTTP/1.1 200 OK
Server: Apache/2.4.66 (Ubuntu)
```

この時点で、静的 HTML / CSS / JavaScript のサイトであれば公開可能です。

## Apache の役割

現時点の構成は以下です。

```text
ブラウザ
  ↓ HTTP :80
Apache2
  ↓
/var/www/html
```

Apache は 80 番ポートで HTTP リクエストを受け取り、`/var/www/html` 配下のファイルを返します。

## 学んだこと

### 1. Apache が入っていても、起動できるとは限らない

Apache2 のインストール自体は成功していても、サービス起動で失敗することがあります。

今回の原因は、別の Ubuntu 環境で Apache が起動しており、80番ポートを既に使用していたことでした。

確認コマンド:

```bash
sudo apache2ctl configtest
sudo ss -ltnp | grep ':80'
```

設定確認結果:

```text
Syntax OK
```

80番ポート確認結果:

```text
LISTEN 0 511 *:80 *:*
```

設定は正しいが、ポートが使用中だったため Apache が起動できませんでした。

### 2. WSL2 の複数 Ubuntu でも localhost:80 は競合する

メイン Ubuntu と検証用 Ubuntu-26.04 は別の Linux 環境ですが、Windows 側から見た `localhost:80` は競合します。

そのため、複数の WSL 環境で Apache を起動する場合は、どの環境が 80番ポートを使っているか確認する必要があります。

対応:

```bash
sudo service apache2 stop
```

別環境の Apache を停止した後、検証用 Ubuntu-26.04 側で Apache を再起動して成功しました。

## 今後の拡張

将来的には、以下も検討します。

- 独自の Web ルート作成
- VirtualHost 設定
- ポート番号変更
- HTTPS 対応
- Apache ログ確認の自動化
- 起動失敗時の診断出力強化

## 現在の結論

Apache2 の自動インストールと起動確認は成功しました。

現在の到達点:

```text
空の Linux
  ↓
apt 初期装備
  ↓
Apache2 インストール
  ↓
Apache2 起動
  ↓
HTTP/1.1 200 OK
```

これにより、静的 Web サイトを配信できる状態になりました。
