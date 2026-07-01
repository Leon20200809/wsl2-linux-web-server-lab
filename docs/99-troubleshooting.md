# Troubleshooting

構築中に発生したエラーと解決方法を記録する。

## Apache2 が起動しない

### 現象

Apache2 のインストールは成功しているが、起動確認で失敗した。

```text
Job for apache2.service failed because the control process exited with error code.
```

### 確認したこと

Apache の設定構文を確認。

```bash
sudo apache2ctl configtest
```

結果。

```text
Syntax OK
```

Apache の設定ファイルには問題なし。

次に、80番ポートの使用状況を確認。

```bash
sudo ss -ltnp | grep ':80'
```

結果。

```text
LISTEN 0 511 *:80 *:*
```

80番ポートが既に使用中だった。

### 原因

別の Ubuntu 環境で起動していた Apache2 が、80番ポートを使用していた。

WSL2 で複数の Ubuntu を使っている場合でも、`localhost:80` は競合する。

### 対応

メイン Ubuntu 側の Apache2 を停止した。

```bash
sudo service apache2 stop
```

その後、検証用 Ubuntu-26.04 側で Apache2 を再起動。

```bash
sudo service apache2 restart
```

HTTP 応答を確認。

```bash
curl -I http://localhost/
```

結果。

```text
HTTP/1.1 200 OK
Server: Apache/2.4.66 (Ubuntu)
```

### 学び

Apache の設定が正しくても、80番ポートが他のプロセスに使われていると起動できない。

Apache 起動失敗時は、まず以下を確認する。

```bash
sudo apache2ctl configtest
sudo ss -ltnp | grep ':80'
```
