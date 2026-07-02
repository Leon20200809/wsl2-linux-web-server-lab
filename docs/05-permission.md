# Permission

Linux の権限設定は、Webサーバー構築で特に重要な要素です。

Apache や PHP-FPM がファイルを読めなければWebページは表示できず、作業ユーザーが編集できなければ開発効率が落ちます。

このプロジェクトでは、Webroot 配下のファイルを「作業ユーザーが編集できる」「Apache / PHP-FPM が読める」状態に整えます。

## この部隊の目的

Permission 部隊では、以下を扱います。

- 公開用ディレクトリの所有者設定
- Apache / PHP-FPM が読めるグループ設定
- ディレクトリ権限の設定
- ファイル権限の設定
- setgid によるグループ継承
- 危険な権限設定を避ける

## 対象スクリプト

```text
scripts/webroot/create.sh
scripts/webroot/permission.sh
scripts/webroot/create-test-index.sh
```

権限設定の中心は以下です。

```text
scripts/webroot/permission.sh
```

## 前提

このプロジェクトでは、公開用ディレクトリを `.env` の `PROJECT_DIR` で指定します。

例:

```text
PROJECT_DIR=/var/www/html/lamp_lab
PROJECT_URL=http://localhost/lamp_lab
```

`PROJECT_DIR` は `/var/www/html/` 配下に限定します。

理由:

- Apache の標準公開ディレクトリ配下で扱うため
- 誤って重要なシステムディレクトリを操作しないため
- `chown -R` や `chmod -R` の対象を安全に絞るため

禁止する例:

```text
PROJECT_DIR=/var/www/html
PROJECT_DIR=/
PROJECT_DIR=/etc
PROJECT_DIR=/home/espo
```

`/var/www/html` 自体を直接指定しないのは、Apacheのデフォルト公開ディレクトリ全体を巻き込まないためです。

## 所有者とグループ

今回の基本方針:

```text
所有者: 現在の作業ユーザー
グループ: www-data
```

例:

```text
OWNER: espo
GROUP: www-data
```

Apache や PHP-FPM は、通常 `www-data` ユーザーまたは `www-data` グループで動作します。

そのため、Webroot のグループを `www-data` にしておくと、Apache / PHP-FPM がファイルを読みやすくなります。

## chown の考え方

`chown` は、ファイルやディレクトリの所有者を変更するコマンドです。

今回の方針:

```bash
sudo chown -R "${USER}:www-data" "${PROJECT_DIR}"
```

意味:

```text
PROJECT_DIR 配下を再帰的に
所有者 = 現在の作業ユーザー
グループ = www-data
にする
```

これにより、以下の状態を狙います。

```text
作業ユーザー espo → 編集できる
Apache/PHP-FPM → www-data グループ経由で読める
```

## chmod の考え方

`chmod` は、ファイルやディレクトリの権限を変更するコマンドです。

このプロジェクトでは、ディレクトリとファイルで権限を分けます。

ディレクトリ:

```text
2775
```

ファイル:

```text
664
```

## ディレクトリ権限 2775

ディレクトリには `2775` を設定します。

```bash
sudo find "${PROJECT_DIR}" -type d -exec chmod 2775 {} \;
```

意味:

```text
2 = setgid
7 = 所有者は読み・書き・実行
7 = グループは読み・書き・実行
5 = その他は読み・実行
```

ディレクトリの実行権限は、「中に入れる」「中のファイルへ到達できる」という意味です。

Web公開ディレクトリでは、Apache がファイルへ到達するためにディレクトリの実行権限が必要です。

## setgid について

`2775` の先頭の `2` は setgid です。

ディレクトリに setgid を付けると、その中で新しく作られるファイルやディレクトリが、親ディレクトリのグループを引き継ぎやすくなります。

今回の場合:

```text
/var/www/html/lamp_lab のグループ = www-data
↓
中で作られるファイルも www-data グループになりやすい
```

これにより、後からファイルを追加したときに、Apache / PHP-FPM から読めない事故を減らします。

## ファイル権限 664

ファイルには `664` を設定します。

```bash
sudo find "${PROJECT_DIR}" -type f -exec chmod 664 {} \;
```

意味:

```text
6 = 所有者は読み・書き
6 = グループは読み・書き
4 = その他は読み
```

通常のHTML、CSS、JS、PHPファイルは実行権限を持つ必要がありません。

PHPファイルはLinux上で直接実行するのではなく、Apache / PHP-FPM 経由で読み込まれて処理されます。

そのため、基本は `664` で十分です。

## 777 を避ける理由

`777` は、全員に読み・書き・実行を許可する設定です。

```text
所有者: 読み・書き・実行
グループ: 読み・書き・実行
その他: 読み・書き・実行
```

一見便利ですが、Webサーバーでは危険です。

理由:

- 誰でも書き換え可能になる
- 誤操作の影響範囲が広がる
- 改ざんリスクが上がる
- 権限設計の問題を隠してしまう

LG流では、雑に `777` で解決しません。

```text
動かすために全開放するのではなく、
必要な相手に必要な権限だけ渡す。
```

## WordPressとの関係

WordPressでは、以下のような場面で権限問題が起きやすいです。

- 画像アップロード
- テーマ編集
- プラグイン更新
- 言語ファイル追加
- キャッシュファイル生成
- `.htaccess` 更新

過去の検証では、WordPress の日本語化で `www-data` 側の権限が関係しました。

そのため、Webrootの権限設計は、WordPress構築前に理解しておく価値があります。

## 確認すべきコマンド

権限確認:

```bash
ls -la /var/www/html
ls -la /var/www/html/lamp_lab
```

所有者とグループ確認:

```bash
stat /var/www/html/lamp_lab
```

Apache / PHP-FPM 経由で表示確認:

```bash
curl -s http://localhost/lamp_lab/
```

確認用 `index.php` で見るべき値:

```text
PHP SAPI: fpm-fcgi
Server Software: Apache/2.4.66 (Ubuntu)
Document Root: /var/www/html
```

## まだ確認前の項目

このドキュメント作成時点では、Webroot 部隊の実行確認はこれから行います。

確認予定:

- `PROJECT_DIR` が作成されること
- 所有者が作業ユーザーになること
- グループが `www-data` になること
- ディレクトリが `2775` になること
- ファイルが `664` になること
- `index.php` が作成されること
- `http://localhost/lamp_lab/` で表示できること
- PHP SAPI が `fpm-fcgi` になること

確認後、この章に実行結果を追記します。

## 現在の設計方針

Webroot 権限の基本方針:

```text
所有者: 作業ユーザー
グループ: www-data
ディレクトリ: 2775
ファイル: 664
```

狙い:

```text
作業ユーザーが編集できる
Apache / PHP-FPM が読める
将来のWordPress配置に備える
777で雑に逃げない
```

## 現在の結論

Permission 部隊は、Webroot を安全に扱うための土台です。

Apache、PHP-FPM、MySQL が揃っても、ファイル権限が崩れているとWebアプリケーションは正しく動きません。

そのため、Webroot 作成後は必ず権限を確認します。

```text
Webroot 作成
  ↓
所有者とグループ設定
  ↓
ディレクトリ権限設定
  ↓
ファイル権限設定
  ↓
Apache / PHP-FPM 経由で表示確認
```

権限は地味ですが、Webサーバー構築の門番です。
