# PHP

PHP は、Apache が受け取ったリクエストに対して、動的な処理を行うための実行環境です。

このプロジェクトでは、Apache モジュール方式ではなく、PHP-FPM / FastCGI 方式を採用します。

## この部隊の目的

PHP 部隊では、以下を自動化します。

- PHP 本体のインストール
- PHP-FPM のインストール
- WordPress 実務で使いやすい主要 PHP 拡張のインストール
- Apache から PHP-FPM へ処理を渡す設定
- PHP-FPM サービスの起動確認
- Apache 経由で PHP が実行されるか確認
- OPcache の有無確認

## 採用方式

採用する PHP 実行方式:

```text
PHP-FPM / FastCGI
```

理由:

Xserver 上の WordPress サイトヘルスで、PHP SAPI が以下のように表示されていました。

```text
PHP SAPI: fpm-fcgi
```

これは、PHP が Apache モジュール方式ではなく、PHP-FPM / FastCGI 方式で実行されていることを示します。

そのため、本プロジェクトでも実務環境に近い構成を理解するため、PHP-FPM 方式を採用します。

## Apache モジュール方式との違い

Apache モジュール方式:

```text
ブラウザ
  ↓
Apache + PHPモジュール
  ↓
PHP実行
```

PHP-FPM方式:

```text
ブラウザ
  ↓
Apache
  ↓ FastCGI
PHP-FPM
  ↓
PHP実行
```

Apache モジュール方式は簡単ですが、Apache が PHP 実行機能を抱え込みます。

PHP-FPM 方式では、Apache は HTTP 処理を担当し、PHP の実行は PHP-FPM に任せます。

この方が責務分離が明確です。

## 対象スクリプト

```text
scripts/php/install.sh
scripts/php/check.sh
```

## install.sh の役割

`scripts/php/install.sh` では、PHP-FPM と主要な PHP 拡張をインストールします。

導入する主なパッケージ:

```text
php
php-cli
php-fpm
php-mysql
php-curl
php-xml
php-mbstring
php-zip
php-gd
php-intl
```

### php-opcache は必須配列に入れない

最初は `php-opcache` もインストール対象に入れていましたが、Ubuntu-26.04 では以下のエラーで停止しました。

```text
Package php-opcache is not available
Error: Package 'php-opcache' has no installation candidate
```

ただし、これは OPcache が使えないという意味ではありません。

実際には、PHP 本体の導入後に以下が確認できました。

```text
with Zend OPcache v8.5.4
[OK] Zend OPcache is available
```

そのため、OPcache は必須インストール対象ではなく、PHP 導入後の確認対象として扱います。

方針:

```text
PHP-FPM本体を先に入れる。
OPcacheは後で確認する。
環境依存のパッケージ名を必須配列に混ぜない。
```

## PHP バージョンの自動検出

Ubuntu-26.04 では、PHP 8.5.4 が導入されました。

確認結果:

```text
PHP 8.5.4 (cli)
```

PHP-FPM のサービス名は PHP バージョンによって変わります。

例:

```text
php8.5-fpm
```

そのため、スクリプトでは PHP のメジャー・マイナーバージョンを自動検出し、サービス名と Apache 設定名を組み立てます。

確認結果:

```text
PHP_VERSION: 8.5
PHP_FPM_SERVICE: php8.5-fpm
PHP_FPM_CONF: php8.5-fpm
```

## Apache との連携

Apache から PHP-FPM に処理を渡すため、以下の Apache モジュールを有効化します。

```text
proxy
proxy_fcgi
setenvif
```

実行される処理:

```text
a2enmod proxy_fcgi setenvif
a2enconf php8.5-fpm
```

`a2enconf php8.5-fpm` により、Apache が PHP-FPM 用の設定を読み込むようになります。

その後、PHP-FPM と Apache を再起動します。

```text
php8.5-fpm restart
apache2 restart
```

## check.sh の役割

`scripts/php/check.sh` では、PHP-FPM が正しく動いているか確認します。

確認する内容:

- `php -v`
- CLI での PHP SAPI 確認
- PHP-FPM サービス状態確認
- Apache モジュール確認
- Apache 設定構文確認
- Apache 経由で PHP が実行されるか確認

## CLI SAPI と Web SAPI の違い

ターミナルで `php` を実行した場合、SAPI は `cli` になります。

確認結果:

```text
CLI SAPI: cli
```

一方、Apache 経由で PHP を実行した場合、SAPI は `fpm-fcgi` になります。

確認結果:

```text
PHP_FPM_OK:fpm-fcgi
```

つまり、PHP-FPM 方式で動いているか確認するには、CLI だけでなく Web 経由の実行確認が必要です。

## 現在の実行結果

検証用 Ubuntu-26.04 で、PHP-FPM のインストールと Apache 連携に成功しました。

重要な証拠:

```text
[OK] php8.5-fpm is running
proxy_fcgi_module (shared)
setenvif_module (shared)
Syntax OK
PHP_FPM_OK:fpm-fcgi
[OK] PHP-FPM 確認完了
```

この結果により、以下の構成が成立しました。

```text
ブラウザ / curl
  ↓
Apache
  ↓ proxy_fcgi
PHP-FPM
  ↓
PHP実行
```

## OPcache について

OPcache は PHP の高速化機能です。

PHP ファイルを毎回読み込み・解析・コンパイルし直すのではなく、一度コンパイルした中間コードをメモリに保存して使い回します。

WordPress のように PHP ファイルが多いシステムでは効果が大きいです。

今回の検証環境では、PHP 本体導入後に Zend OPcache が利用可能であることを確認しました。

```text
with Zend OPcache v8.5.4
[OK] Zend OPcache is available
```

## 学んだこと

### 1. apt install は1つでも存在しないパッケージがあると止まる

最初に `php-opcache` を必須パッケージに含めたところ、存在しないパッケージとして扱われ、PHP本体のインストール全体が停止しました。

教訓:

```text
必須パッケージと確認項目を分ける。
環境によって名前が変わるものは、必須配列に混ぜない。
```

### 2. PHP-FPM では libapache2-mod-php は入れない

今回の構成では、PHP実行を PHP-FPM に任せます。

そのため、Apache モジュール方式で使う `libapache2-mod-php` は不要です。

混ぜると、Apache モジュール方式なのか PHP-FPM 方式なのか分かりにくくなるため、今回は入れません。

### 3. Xserver の実務環境に近い構成を再現できた

Xserver の WordPress サイトヘルスでは、PHP SAPI が `fpm-fcgi` でした。

今回の検証環境でも、Apache 経由の PHP 実行結果として以下を確認できました。

```text
PHP_FPM_OK:fpm-fcgi
```

これにより、Xserver に近い PHP 実行方式を WSL2 Ubuntu 上で再現できました。

## 現在の結論

PHP-FPM の自動インストールと Apache 連携は成功しました。

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
PHP-FPM インストール
  ↓
Apache + PHP-FPM 連携
  ↓
PHP_FPM_OK:fpm-fcgi
```

これにより、静的 HTML だけでなく、PHP を実行できる Web サーバー環境になりました。
