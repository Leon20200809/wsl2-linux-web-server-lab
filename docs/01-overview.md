# Overview

このドキュメントは、LAMP 自動構築プロジェクトの作業手順メモです。
README にはプロジェクト全体の説明を書き、このファイルでは実装・検証の流れを記録します。

## 前提

空の Linux 環境に入った後の作業を対象にします。

WSL2 のインストール、Windows Terminal の設定、初期 Unix ユーザー作成は対象外です。

## 最初に必要な手動準備

完全に空の Linux 環境では、GitHub からこのリポジトリを clone するために、最初だけ `git` を手動で入れます。

```bash
sudo apt update
sudo apt install -y git ca-certificates
```

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

## sudo について

スクリプト内では、`apt install` や `service restart` などで `sudo` を使います。

sudo パスワードは `.env` には書きません。
必要な場合は、実行時にターミナルで入力します。

`run.sh` の最初で `sudo -v` を実行し、sudo 権限を確認します。
認証済みの間は、後続の sudo 処理を続けて実行できます。

処理に時間がかかった場合、途中で再度パスワードを求められることがあります。

## 現在の実装状態

現在は、最初の部隊として `scripts/bootstrap/00-apt-base.sh` を実装済みです。

このスクリプトでは、以下を行います。

- OS 情報の出力
- 実行ユーザー情報の出力
- apt コマンドの存在確認
- sudo 権限の確認
- apt update
- git / curl / ca-certificates / unzip の導入
- 各コマンドのバージョン確認

`run.sh` から `00-apt-base.sh` を呼び出すところまで確認済みです。

## 検証済み環境

```text
Ubuntu-26.04
/home/espo/wsl2-linux-web-server-lab
```

検証用 Ubuntu-26.04 で、以下の流れを確認済みです。

```bash
git fetch
git pull --ff-only
./scripts/run.sh
```

結果:

```text
[OK] APT base setup 完了
[OK] run.sh MVP completed
```

## 次に実装するもの

次は Apache 部隊を実装します。

予定:

1. `scripts/apache/install.sh`
2. `scripts/apache/check.sh`
3. `run.sh` に Apache 部隊を追加
4. 検証用 Ubuntu-26.04 で実行確認

## 作業メモ

### Bootstrap 装備

空の Linux からこのプロジェクトを開始するには、最初に `git` が必要です。
そのため、完全自動化の前に以下だけは手動で行います。

```bash
sudo apt update
sudo apt install -y git ca-certificates
```

これは GitHub から設計図を取得するための最小装備です。

### run.sh の役割

`run.sh` は全体の順番だけを管理します。
細かい処理は各部隊スクリプトに任せます。

現在の流れ:

```text
run.sh
  ↓
sudo -v
  ↓
scripts/bootstrap/00-apt-base.sh
```

今後の予定:

```text
run.sh
  ↓
bootstrap
  ↓
apache
  ↓
php
  ↓
mysql
  ↓
webroot
  ↓
health check
```
