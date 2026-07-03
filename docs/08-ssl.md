# SSL / HTTPS

この章では、WSL2 Ubuntu 上の Apache にローカルSSL証明書を設定し、`https://localhost/lamp_lab/` でアクセスできる状態を作る。

本番環境では Let’s Encrypt や Xserver の無料独自SSLを使うが、ローカル環境では `localhost` 用の公開証明書を通常取得できない。

そのため、このプロジェクトでは `mkcert` を使って、ローカル開発用の認証局と証明書を作成する。

## この部隊の目的

SSL 部隊では、以下を扱う。

- `mkcert` のインストール
- ローカルCAの作成
- `localhost` 用SSL証明書の作成
- 証明書と秘密鍵のApache用配置
- Apache SSLモジュールの有効化
- SSL用 VirtualHost の作成
- 443番ポートでの待受確認
- HTTPS経由でのWeb表示確認
- Windows側ブラウザでの信頼確認

## 対象スクリプト予定

```text
scripts/ssl/install-mkcert.sh
scripts/ssl/create-cert.sh
scripts/ssl/configure-apache.sh
scripts/ssl/check.sh
```

このドキュメント作成時点では、まず手動で動作確認を行った。
確認後、同じ手順を `scripts/ssl/` 配下に自動化する。

## ゴール

HTTPで表示できていたページを、HTTPSでも表示できるようにする。

HTTP:

```text
http://localhost/lamp_lab/
```

HTTPS:

```text
https://localhost/lamp_lab/
```

最終的に、以下が確認できれば成功。

```text
HTTP/1.1 200 OK
Apache + PHP-FPM webroot check OK.
PHP SAPI: fpm-fcgi
```

## HTTPSに必要なもの

HTTPS化には、主に以下が必要。

```text
証明書
秘密鍵
Apache SSLモジュール
SSL用VirtualHost
443番ポート
ブラウザ側の信頼
```

今回作成したファイル:

```text
localhost.pem      = 証明書
localhost-key.pem  = 秘密鍵
```

Apacheに配置した場所:

```text
/etc/apache2/ssl/lamp-lab/localhost.pem
/etc/apache2/ssl/lamp-lab/localhost-key.pem
```

## 証明書と秘密鍵の役割

証明書は、サーバーの身分証明書のようなもの。

```text
このサーバーは localhost 用のサーバーです
```

という情報を持つ。

秘密鍵は、サーバー本人だけが持つ鍵。

```text
証明書 = 公開してよい
秘密鍵 = 絶対に漏らしてはいけない
```

そのため、Apacheに配置した後、権限を分ける。

```bash
sudo chmod 644 /etc/apache2/ssl/lamp-lab/localhost.pem
sudo chmod 600 /etc/apache2/ssl/lamp-lab/localhost-key.pem
```

意味:

```text
証明書 644 = 読めればよい
秘密鍵 600 = rootだけ読める
```

## mkcertをインストールする

検証用 Ubuntu-26.04 側で実行する。

```bash
sudo apt update
sudo apt install -y mkcert libnss3-tools
```

バージョン確認:

```bash
mkcert -version
```

検証時の結果:

```text
1.4.4
```

`libnss3-tools` は、FirefoxやNSS系の証明書ストア操作に使われる補助ツール。

## ローカルCAを作成する

```bash
mkcert -install
```

実行結果:

```text
Created a new local CA
The local CA is now installed in the system trust store
```

ここで、ローカル開発用の認証局が作成される。

CAの場所確認:

```bash
mkcert -CAROOT
```

検証時の結果:

```text
/home/espo/.local/share/mkcert
```

この中に、ローカルCAの証明書が保存される。

## localhost用証明書を作成する

作業用ディレクトリを作る。

```bash
mkdir -p ~/ssl/lamp-lab
cd ~/ssl/lamp-lab
```

証明書と秘密鍵を作成する。

```bash
mkcert \
  -cert-file localhost.pem \
  -key-file localhost-key.pem \
  localhost 127.0.0.1 ::1 room1-4
```

指定した名前:

```text
localhost
127.0.0.1
::1
room1-4
```

それぞれの意味:

```text
localhost = ローカルアクセス用
127.0.0.1 = IPv4のループバックアドレス
::1       = IPv6のループバックアドレス
room1-4   = WSL内Linuxのホスト名
```

作成結果:

```text
localhost.pem
localhost-key.pem
```

確認:

```bash
ls -l
```

検証時の結果:

```text
-rw------- 1 espo espo 1704 Jul  3 15:17 localhost-key.pem
-rw-r--r-- 1 espo espo 1489 Jul  3 15:17 localhost.pem
```

補足:

```text
localhost.pem
localhost-key.pem
```

だけをターミナルに打つと、コマンドとして実行しようとして `command not found` になる。

ファイル確認は `ls -l` を使う。

## Apache用ディレクトリへコピーする

Apacheが読みやすいように、証明書と秘密鍵を `/etc/apache2/ssl/lamp-lab/` に配置する。

```bash
sudo mkdir -p /etc/apache2/ssl/lamp-lab

sudo cp localhost.pem /etc/apache2/ssl/lamp-lab/localhost.pem
sudo cp localhost-key.pem /etc/apache2/ssl/lamp-lab/localhost-key.pem
```

所有者をrootにする。

```bash
sudo chown root:root /etc/apache2/ssl/lamp-lab/localhost.pem
sudo chown root:root /etc/apache2/ssl/lamp-lab/localhost-key.pem
```

権限を設定する。

```bash
sudo chmod 644 /etc/apache2/ssl/lamp-lab/localhost.pem
sudo chmod 600 /etc/apache2/ssl/lamp-lab/localhost-key.pem
```

確認:

```bash
sudo ls -l /etc/apache2/ssl/lamp-lab/
```

期待する状態:

```text
localhost.pem      = root所有 / 644
localhost-key.pem  = root所有 / 600
```

## ApacheのSSL VirtualHostを作成する

SSL用のサイト設定ファイルを作成する。

```bash
sudo tee /etc/apache2/sites-available/lamp-lab-ssl.conf >/dev/null <<'EOF'
<IfModule mod_ssl.c>
<VirtualHost *:443>
    ServerName localhost
    ServerAlias room1-4 127.0.0.1

    DocumentRoot /var/www/html

    SSLEngine on
    SSLCertificateFile /etc/apache2/ssl/lamp-lab/localhost.pem
    SSLCertificateKeyFile /etc/apache2/ssl/lamp-lab/localhost-key.pem

    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/lamp-lab-ssl-error.log
    CustomLog ${APACHE_LOG_DIR}/lamp-lab-ssl-access.log combined
</VirtualHost>
</IfModule>
EOF
```

主な設定の意味:

```text
<VirtualHost *:443>
    443番ポートのHTTPS用設定

ServerName localhost
    メインのホスト名

ServerAlias room1-4 127.0.0.1
    追加で許可する名前

DocumentRoot /var/www/html
    公開ディレクトリの基点

SSLEngine on
    SSLを有効化

SSLCertificateFile
    証明書ファイル

SSLCertificateKeyFile
    秘密鍵ファイル
```

今回 `DocumentRoot` は `/var/www/html` にしている。

そのため、アクセスURLは以下になる。

```text
https://localhost/lamp_lab/
```

Apacheは以下のファイルを探す。

```text
/var/www/html/lamp_lab/index.php
```

## ApacheのSSLモジュールとサイトを有効化する

SSLモジュールを有効化する。

```bash
sudo a2enmod ssl
```

SSLサイトを有効化する。

```bash
sudo a2ensite lamp-lab-ssl.conf
```

設定構文を確認する。

```bash
sudo apache2ctl configtest
```

成功時:

```text
Syntax OK
```

Apacheを再起動する。

```bash
sudo service apache2 restart
```

## 443番ポートを確認する

```bash
sudo ss -ltnp | grep -E ':80|:443'
```

検証時の結果:

```text
LISTEN *:80  users:(("apache2",...))
LISTEN *:443 users:(("apache2",...))
```

意味:

```text
80番  = HTTP
443番 = HTTPS
```

この状態で、ApacheはHTTPとHTTPSの両方で待ち受けている。

## HTTPSで疎通確認する

まずはヘッダー確認。

```bash
curl -k -I https://localhost/lamp_lab/
```

検証時の結果:

```text
HTTP/1.1 200 OK
Date: Fri, 03 Jul 2026 06:22:17 GMT
Server: Apache/2.4.66 (Ubuntu)
Content-Type: text/html; charset=UTF-8
```

`200 OK` が出れば、HTTPS経由で目的のURLに到達できている。

## PHP-FPM経由の実行確認

本文の一部を確認する。

```bash
curl -k -s https://localhost/lamp_lab/ | grep -E 'Apache \+ PHP-FPM|fpm-fcgi'
```

検証時の結果:

```text
<p>Apache + PHP-FPM webroot check OK.</p>
<li>PHP SAPI: fpm-fcgi</li>
```

これにより、以下が成立していることを確認できる。

```text
HTTPS :443
  ↓
Apache SSL VirtualHost
  ↓
/var/www/html/lamp_lab/index.php
  ↓
PHP-FPM
```

HTTPS化しても、PHPの実行方式は `fpm-fcgi` のまま。

## curl -k の意味

```bash
curl -k -I https://localhost/lamp_lab/
```

`-k` は、証明書検証を無視するオプション。

用途:

```text
HTTPS通信そのものが通っているか確認する
証明書の信頼問題と、Apacheの疎通問題を切り分ける
```

本番では基本的に使わない。

本番で `curl -k` が必要な状態は、証明書の設定に問題がある可能性が高い。

## Windows側ブラウザで確認する

今回の構成では、ApacheはWSL側で動いている。

```text
WSL Ubuntu
  ↓
Apache :443
```

一方、ブラウザはWindows側で動いている。

```text
Windows Chrome / Edge
```

そのため、WSL側で `mkcert -install` しただけでは、Windowsブラウザが証明書を信頼しない場合がある。

必要に応じて、mkcertのローカルCAをWindows側に登録する。

CAの場所を確認する。

```bash
mkcert -CAROOT
```

Windowsエクスプローラーで開く。

```bash
explorer.exe "$(wslpath -w "$(mkcert -CAROOT)")"
```

中にある `rootCA.pem` をWindows側でインストールする。

手順:

```text
rootCA.pem を開く
↓
証明書のインストール
↓
現在のユーザー
↓
証明書をすべて次のストアに配置する
↓
信頼されたルート証明機関
↓
完了
```

その後、ブラウザで確認する。

```text
https://localhost/lamp_lab/
```

警告なしで表示できれば、Windows側ブラウザもローカルCAを信頼できている。

## 404になったときの切り分け

最初にHTTPSで確認したとき、以下のように404になった。

```text
HTTP/1.1 404 Not Found
```

このとき、443番ポートは開いていた。

```bash
sudo ss -ltnp | grep -E ':80|:443'
```

結果:

```text
*:80  apache2
*:443 apache2
```

つまり、SSLや443番ポートは動いていた。

原因は、SSLを設定したUbuntuに `/var/www/html/lamp_lab` が存在しなかったこと。

確認:

```bash
ls -ld /var/www/html/lamp_lab
ls -l /var/www/html/lamp_lab/index.php
```

結果:

```text
No such file or directory
```

構造:

```text
https://localhost/lamp_lab/
  ↓
DocumentRoot /var/www/html
  ↓
/var/www/html/lamp_lab/
  ↓
存在しない
  ↓
404
```

学び:

```text
HTTPSで404が出る場合、証明書エラーではなく、DocumentRootやファイル配置の問題であることがある。
```

## WSL複数環境での注意

WSL内に複数のUbuntuがある場合、どのUbuntuにいるかを必ず確認する。

確認:

```bash
echo "WSL_DISTRO_NAME=$WSL_DISTRO_NAME"
hostnamectl
pwd
```

`/var/www/html/lamp_lab` が存在するUbuntuでSSL設定を行う必要がある。

確認:

```bash
ls -ld /var/www/html/lamp_lab
curl -I http://localhost/lamp_lab/
```

HTTPで `200 OK` が出るUbuntuが、SSL設定すべき環境。

## Apacheの有効サイト確認

SSL設定がどのVirtualHostに効いているか確認する。

```bash
sudo apache2ctl -S
```

有効化されているサイト一覧を見る。

```bash
ls -l /etc/apache2/sites-enabled/
```

`lamp-lab-ssl.conf` が有効になっていれば、SSL用VirtualHostが読み込まれている。

## SSLログ確認

SSL側のログは、設定ファイルで以下に分けた。

```text
ErrorLog  ${APACHE_LOG_DIR}/lamp-lab-ssl-error.log
CustomLog ${APACHE_LOG_DIR}/lamp-lab-ssl-access.log combined
```

エラーログ確認:

```bash
sudo tail -n 80 /var/log/apache2/lamp-lab-ssl-error.log
```

アクセスログ確認:

```bash
sudo tail -n 80 /var/log/apache2/lamp-lab-ssl-access.log
```

HTTPSで表示できない場合は、Apacheの設定構文、待受ポート、ログを確認する。

## SSLの成功判定

SSL / HTTPSの成功判定は段階で行う。

### 1. Apacheが443番で待受している

```bash
sudo ss -ltnp | grep ':443'
```

期待:

```text
*:443 apache2
```

### 2. HTTPSでApacheが応答する

```bash
curl -k -I https://localhost/
```

Apacheからレスポンスが返れば、HTTPSの入口は動いている。

### 3. 目的URLが200になる

```bash
curl -k -I https://localhost/lamp_lab/
```

期待:

```text
HTTP/1.1 200 OK
```

### 4. PHP-FPM経由で動いている

```bash
curl -k -s https://localhost/lamp_lab/ | grep -E 'Apache \+ PHP-FPM|fpm-fcgi'
```

期待:

```text
Apache + PHP-FPM webroot check OK.
PHP SAPI: fpm-fcgi
```

### 5. Windowsブラウザで表示できる

```text
https://localhost/lamp_lab/
```

警告なしで表示できれば、ブラウザ側の信頼も成功。

## 本番SSLとの違い

ローカルSSL:

```text
localhost
mkcert
ローカルCA
自分の環境だけで信頼
```

本番SSL:

```text
公開ドメイン
Let’s Encrypt / Xserver無料SSL
公開CA
世界中のブラウザが信頼
```

違いは、証明書を誰が発行し、誰が信頼するか。

ただし、基本構造は同じ。

```text
証明書
秘密鍵
CA
443番ポート
Webサーバー設定
```

## 現在の成功結果

検証用 Ubuntu-26.04 で、以下を確認した。

```bash
curl -k -I https://localhost/lamp_lab/
```

結果:

```text
HTTP/1.1 200 OK
Server: Apache/2.4.66 (Ubuntu)
Content-Type: text/html; charset=UTF-8
```

PHP-FPM確認:

```bash
curl -k -s https://localhost/lamp_lab/ | grep -E 'Apache \+ PHP-FPM|fpm-fcgi'
```

結果:

```text
<p>Apache + PHP-FPM webroot check OK.</p>
<li>PHP SAPI: fpm-fcgi</li>
```

これにより、以下が成立した。

```text
ブラウザ / curl
  ↓ HTTPS :443
Apache SSL
  ↓
PHP-FPM
```

## 学んだこと

### 1. SSLは証明書だけでは動かない

HTTPS化には、証明書だけでなく、秘密鍵、Apache設定、443番ポート、ブラウザ側の信頼が必要。

```text
証明書
秘密鍵
Apache SSL設定
443番ポート
ブラウザ側の信頼
```

### 2. 443番が開いていればSSLの入口は動いている

```bash
sudo ss -ltnp | grep ':443'
```

ここでApacheが待受していれば、HTTPSの入口は開いている。

### 3. 404はSSL失敗とは限らない

HTTPSで404が返る場合、SSL通信自体は成立している。

その場合は、ファイル配置や `DocumentRoot` を確認する。

### 4. WSLではApache側とブラウザ側を分けて考える

ApacheはWSL側で動く。
ブラウザはWindows側で動く。

そのため、証明書ファイルはWSL側に配置し、必要に応じてCAはWindows側にも信頼させる。

### 5. HTTPS化してもPHP-FPM構成は変わらない

HTTPS化は通信の入口を暗号化する設定。

PHPの実行方式は変わらない。

確認結果:

```text
PHP SAPI: fpm-fcgi
```

## 現在の結論

ローカル環境で `mkcert` を使い、ApacheにSSL証明書を設定することで、`https://localhost/lamp_lab/` を表示できるようになった。

これにより、HTTPだけでなくHTTPS前提のWebアプリケーション開発・検証ができる状態になった。

現在の到達点:

```text
Apache HTTP  :80
Apache HTTPS :443
PHP-FPM      :fpm-fcgi
MySQL        :3306 / 33060
SSH          :10022
```

これで、ローカルWSL上にかなり本番に近いLinux Webサーバー環境ができた。
