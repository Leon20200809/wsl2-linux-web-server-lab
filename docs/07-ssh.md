# SSH

SSH は、別の端末から Linux サーバーへ安全にログインするための仕組みです。

このプロジェクトでは、Windows Git Bash やメインUbuntuから、検証用 Ubuntu-26.04 へ SSH 接続できる状態を作ります。

将来的には、この SSH 接続を使って Ansible からリモート構築を行う予定です。

## この部隊の目的

SSH 部隊では、以下を扱います。

- OpenSSH Server のインストール
- SSH待受ポートの変更
- `ssh.socket` の無効化
- `ssh.service` の有効化
- 10022番ポートでの待受確認
- Windows Git Bash からのSSH接続確認
- メインUbuntuから検証用UbuntuへのSSH接続確認
- ポート競合の確認
- SSH接続中の環境確認

## 対象スクリプト

```text
scripts/ssh/install.sh
scripts/ssh/configure.sh
scripts/ssh/check.sh
```

## 目標構成

最終的な構成は以下です。

```text
メインUbuntu / Windows Git Bash
  ↓ SSH
検証用 Ubuntu-26.04
  ↓
SSH Server :10022
```

メインUbuntuは接続元、検証用 Ubuntu-26.04 は接続先として扱います。

```text
メインUbuntu        = SSHクライアント / 管理端末 / 旗艦
検証用 Ubuntu-26.04 = SSHサーバー / 構築対象
```

## SSHクライアントとSSHサーバー

SSHには、接続する側と接続される側があります。

```text
openssh-client = 接続する側
openssh-server = 接続される側
```

`ssh` コマンドを使って接続するだけなら、SSHサーバーは不要です。

一方、外部からそのLinuxへ入ってもらうには、SSHサーバーが必要です。

今回、メインUbuntuは接続元専用にするため、メインUbuntu側のSSHサーバーは停止しました。

## 使用ポート

今回のSSH待受ポートは `10022` にします。

```text
22    = SSH標準ポート
10022 = 今回の検証用SSHポート
```

XserverでもSSHポートとして `10022` を使っていたため、本番運用の感覚に近い形で練習できます。

## install.sh の役割

`scripts/ssh/install.sh` では、OpenSSH Server をインストールします。

導入するパッケージ:

```text
openssh-server
```

確認する内容:

```text
OpenSSH Server のパッケージ状態
ssh クライアントのバージョン
sshd サーバーのバージョン
```

実行結果例:

```text
OpenSSH_10.2p1 Ubuntu-2ubuntu3.2, OpenSSL 3.5.5 27 Jan 2026
[OK] OpenSSH Server インストール完了
```

## configure.sh の役割

`scripts/ssh/configure.sh` では、SSHサーバーの待受ポートを `10022` に変更します。

主な処理:

- `/etc/ssh/sshd_config.d/99-lamp-lab.conf` を作成
- `Port 10022` を設定
- パスワード認証を許可
- 公開鍵認証を許可
- rootログインを禁止
- `sshd -t` で構文確認
- `ssh.socket` を無効化・封印
- `ssh.service` を有効化・再起動

設定内容:

```text
Port 10022
PasswordAuthentication yes
PubkeyAuthentication yes
PermitRootLogin no
```

## ssh.service と ssh.socket

SSHには、今回2つのsystemd unitが関係しました。

```text
ssh.service = SSHサーバー本体
ssh.socket  = systemdの待受代行
```

`ssh.service` は、SSHサーバー本体である `sshd` を起動します。

一方、`ssh.socket` は systemd の socket activation 用のunitです。
`ssh.socket` が先にポートを待ち受け、接続が来たタイミングで `ssh.service` を起動することがあります。

今回の目的は以下です。

```text
ssh.service が 10022番で待受する
ssh.socket は使わない
```

そのため、`ssh.socket` は無効化し、さらに `mask` で封印します。

```bash
sudo systemctl disable --now ssh.socket || true
sudo systemctl mask ssh.socket || true
```

`disable` は自動起動を無効化する設定です。

`mask` はさらに強く、そのunitを起動できないようにします。

今回の理解:

```text
ssh.service = SSH本体
ssh.socket  = 22番を握る可能性がある自動ドア係
```

10022番でSSH本体に待たせるため、`ssh.socket` は封印します。

## check.sh の役割

`scripts/ssh/check.sh` では、SSH設定が狙い通りになっているか確認します。

確認する内容:

- `ssh.service` が起動しているか
- `sshd` の有効設定が `port 10022` になっているか
- `ssh.socket` が無効化されているか
- 10022番で待受しているか
- 22番で待受していないか

成功例:

```text
[OK] ssh service is running
[OK] sshd effective port OK: 10022
[OK] ssh.socket is disabled
[OK] SSH is listening on port 10022
[OK] port 22 is not listening
[OK] SSH check completed successfully
```

## 有効設定の確認

SSHの設定ファイルを書いただけでは、本当に反映されているとは限りません。

そのため、以下で `sshd` が最終的に認識している設定を確認します。

```bash
sudo /usr/sbin/sshd -T | grep -E '^port|^passwordauthentication|^pubkeyauthentication|^permitrootlogin'
```

確認結果:

```text
port 10022
permitrootlogin no
pubkeyauthentication yes
passwordauthentication yes
```

`port 10022` が出れば、SSHサーバー本体は10022番設定を認識しています。

## 待受ポートの確認

実際にどのポートで待受しているかは、`ss` で確認します。

```bash
sudo ss -ltnp | grep -E ':22|:10022'
```

成功例:

```text
LISTEN 0 128 0.0.0.0:10022 0.0.0.0:* users:(("sshd",pid=35806,fd=6))
LISTEN 0 128 [::]:10022    [::]:*    users:(("sshd",pid=35806,fd=7))
```

この状態では、SSHサーバーが10022番で待受しています。

22番が出ていなければ、標準SSHポートは閉じています。

## 手動検証で詰まったこと

### 1. 10022番ではなく22番で待受していた

最初、SSH設定ファイルには `Port 10022` を書いていました。

設定確認でも以下のように出ていました。

```text
port 10022
```

しかし、`sudo service ssh status` では以下のように表示されました。

```text
Server listening on 0.0.0.0 port 22.
Server listening on :: port 22.
```

この時点で、設定ファイル上は10022なのに、実際の待受は22番というズレが起きていました。

原因は `ssh.socket` でした。

```text
TriggeredBy: ssh.socket
```

`ssh.socket` が22番を先に握っていたため、`ssh.service` 本体の10022設定とズレていました。

対応:

```bash
sudo systemctl disable --now ssh.socket
sudo systemctl enable --now ssh.service
sudo systemctl restart ssh.service
```

これにより、10022番で待受するようになりました。

### 2. ssh.socket が enabled のまま残っていた

一度10022番で待受できても、`check.sh` では以下のエラーが出ました。

```text
[ERROR] ssh.socket is enabled
```

この時点で、実際の待受は10022番でした。

```text
[OK] SSH is listening on port 10022
[OK] port 22 is not listening
```

つまり、今すぐの接続は成功する状態でした。

しかし、`ssh.socket` が enabled のままだと、将来的に22番の待受として復活する可能性があります。

対応:

```bash
sudo systemctl disable --now ssh.socket || true
sudo systemctl mask ssh.socket || true
sudo systemctl restart ssh.service
```

確認:

```bash
systemctl is-enabled ssh.socket
systemctl is-active ssh.socket
```

結果:

```text
masked
inactive
```

これで、`ssh.socket` は封印され、SSH本体が10022番で待受する構成になりました。

### 3. 10022番ポートが競合した

メインUbuntuにもSSHサーバーを入れて10022番で待受させた後、検証用 Ubuntu-26.04 でも10022番を使おうとしたため、SSHサービスの起動に失敗しました。

これは、Apacheの80番、MySQLの33060番と同じポート競合です。

```text
メインUbuntu sshd        → 10022 使用中
検証用 Ubuntu-26.04 sshd → 10022 を使おうとして失敗
```

対応として、メインUbuntu側のSSHサーバーを停止しました。

```bash
sudo systemctl disable --now ssh.service
sudo systemctl disable --now ssh.socket 2>/dev/null || true
```

メインUbuntuは接続元専用にし、検証用 Ubuntu-26.04 側だけを10022番で待受させます。

最終構成:

```text
メインUbuntu        = SSHクライアント専用
検証用 Ubuntu-26.04 = SSHサーバー :10022
```

ポート競合は、WSL2の複数Ubuntu環境やDocker環境でも発生します。

本番サーバーがまっさらであれば起きにくいですが、ローカル検証環境では鉄板チェックポイントです。

## ポート競合の確認

SSHで詰まったときは、まず待受ポートを確認します。

```bash
sudo ss -ltnp | grep -E ':22|:10022'
```

他の主要ポートもまとめて見るなら以下です。

```bash
sudo ss -ltnp | grep -E ':22|:10022|:80|:443|:3306|:33060'
```

今回の鉄板ポート:

```text
22     = SSH標準
10022  = 今回のSSH
80     = HTTP / Apache
443    = HTTPS / Apache SSL
3306   = MySQL
33060  = MySQL X Plugin
```

## Windows Git Bash からの接続

Windows Git Bash から、10022番でSSH接続しました。

```bash
ssh -p 10022 espo@localhost
```

初回接続時には、以下の確認が出ます。

```text
The authenticity of host '[localhost]:10022' can't be established.
Are you sure you want to continue connecting?
```

これは、接続先サーバーのホスト鍵を初めて見るため、信用するか確認している状態です。

`yes` を入力すると、Windows側の `known_hosts` に登録されます。

```text
Warning: Permanently added '[localhost]:10022' (ED25519) to the list of known hosts.
```

その後、パスワード認証でログインできました。

## ホスト名での接続

`localhost` だけでなく、ホスト名でも接続しました。

```bash
ssh -p 10022 room1-4
```

このとき、以下のように表示されました。

```text
The authenticity of host '[room1-4]:10022 ([127.0.1.1]:10022)' can't be established.
```

`room1-4` が `127.0.1.1` に解決され、10022番へ接続されました。

接続後、以下でホスト情報を確認しました。

```bash
hostnamectl
```

確認結果:

```text
Static hostname: room1-4
Virtualization: wsl
Operating System: Ubuntu 26.04 LTS
Kernel: Linux 6.6.87.2-microsoft-standard-WSL2
```

これにより、SSH接続先がWSL上のUbuntuであることを確認できました。

## SSH接続中の確認コマンド

SSH接続できた後は、以下を確認します。

```bash
whoami
pwd
hostname
hostnamectl
echo $SSH_CONNECTION
echo $SSH_TTY
```

本質:

```text
whoami          = 誰としてログインしているか
pwd             = どこにいるか
hostname        = どのLinuxホストか
hostnamectl     = OS・仮想化方式・ホスト名
SSH_CONNECTION  = SSH接続元と接続先
SSH_TTY         = SSH端末
```

## SSH_CONNECTION の見方

SSH接続中に以下を実行しました。

```bash
echo $SSH_CONNECTION
```

結果:

```text
127.0.0.1 40180 127.0.1.1 10022
```

意味:

```text
接続元IP       127.0.0.1
接続元ポート   40180
接続先IP       127.0.1.1
接続先ポート   10022
```

接続元ポート `40180` は、OSが一時的に割り当てるエフェメラルポートです。

毎回変わるため、通常は意識しません。

重要なのは接続先ポートです。

```text
10022 = SSHサーバーの待受ポート
40180 = クライアント側の一時ポート
```

## WSL_DISTRO_NAME について

通常のWSL起動時には、以下でディストリビューション名を確認できます。

```bash
echo $WSL_DISTRO_NAME
```

ただし、SSHログイン時には `WSL_DISTRO_NAME` が空になることがありました。

これは、SSHログインセッションではWSL固有の環境変数が引き継がれないためです。

SSH接続先の正体確認には、以下の方が確実です。

```bash
hostnamectl
cat /etc/os-release
```

確認すべき情報:

```text
Virtualization: wsl
Operating System: Ubuntu 26.04 LTS
```

## .bashrc について

SSH接続後、普段使っているプロンプトやaliasが効いていない状態がありました。

通常のWSL起動時と、SSHログイン時では、読み込まれるシェル初期化ファイルが異なる場合があります。

```text
通常のWSL起動
→ .bashrc が効く

SSHログイン
→ .profile / .bash_profile / .bashrc の読み込まれ方が異なる場合がある
```

今回は、SSH接続できていることの確認を優先し、`.bashrc` の調整は後回しにします。

## known_hosts について

初回SSH接続時に、接続先のホスト鍵が `known_hosts` に登録されます。

これは、次回以降に同じ接続先であることを確認するための仕組みです。

```text
初回:
このサーバーを信用するか確認される

2回目以降:
known_hosts の情報と照合される
```

同じホスト名・ポートでも、接続先のホスト鍵が変わると警告が出ます。

これは中間者攻撃やサーバー再作成の可能性を検知するための安全機能です。

## 現在の成功結果

最終的に、以下の状態を確認しました。

```text
[OK] ssh service is running
[OK] sshd effective port OK: 10022
[OK] ssh.socket is disabled
[OK] SSH is listening on port 10022
[OK] port 22 is not listening
[OK] SSH check completed successfully
```

SSH接続も成功しました。

```bash
ssh -p 10022 room1-4
```

接続後の確認:

```text
whoami → espo
pwd    → /home/espo
hostnamectl:
  Static hostname: room1-4
  Virtualization: wsl
  Operating System: Ubuntu 26.04 LTS
```

## 学んだこと

### 1. SSH設定は「設定値」と「実際の待受」を両方見る

`sshd -T` で設定値を確認できます。

```bash
sudo /usr/sbin/sshd -T | grep '^port'
```

ただし、実際に待受しているかは `ss` で見る必要があります。

```bash
sudo ss -ltnp | grep ':10022'
```

設定値が正しくても、`ssh.socket` やポート競合により、期待通りに待受しないことがあります。

### 2. ssh.socket は22番を握る可能性がある

Ubuntu環境によっては、`ssh.socket` がSSHの待受に関わります。

10022番で運用したい場合は、`ssh.socket` を無効化し、`ssh.service` 本体に待受させる方が分かりやすいです。

```text
ssh.socket を封印
ssh.service を有効化
10022番で待受
```

### 3. ポート競合は鉄板チェックポイント

Apache、MySQL、SSHでそれぞれポート競合を確認しました。

```text
Apache → 80
MySQL  → 3306 / 33060
SSH    → 10022
```

複数のWSL環境やDockerを同時に動かす場合は、ポート競合が起こりやすくなります。

### 4. SSH接続はAnsible化の前提になる

Ansibleは基本的に、管理端末から対象サーバーへSSH接続して命令を流します。

そのため、今回のSSH接続はAnsible化の土台になります。

```text
メインUbuntu
  ↓ SSH
検証用 Ubuntu-26.04
  ↓
Ansible Playbookで構築
```

## 現在の結論

SSH部隊により、検証用 Ubuntu-26.04 へ10022番ポートでSSH接続できる状態を作りました。

現在の到達点:

```text
OpenSSH Server インストール
  ↓
Port 10022 設定
  ↓
ssh.socket 無効化・mask
  ↓
ssh.service 有効化
  ↓
10022番待受確認
  ↓
Windows Git Bash / メインUbuntu からSSH接続成功
```

これにより、本番サーバー接続やAnsible構成管理に近い形の訓練環境ができました。
