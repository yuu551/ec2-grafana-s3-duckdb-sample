#!/bin/bash

# ==============================================================================
# Grafana OSS + DuckDB Plugin セットアップスクリプト
# Amazon Linux 2023 用
# ==============================================================================

set -e  # エラー時に停止

echo "=== Grafana OSS + DuckDB セットアップ開始 ==="

# ログファイルの設定
LOGFILE="/var/log/grafana-setup.log"
exec 1> >(tee -a $LOGFILE)
exec 2>&1

echo "$(date): セットアップ開始"

# ==============================================================================
# 1. システムの更新と基本パッケージのインストール
# ==============================================================================
echo "=== システム更新とパッケージインストール ==="

# システム更新
dnf update -y --skip-broken

# curl-minimalが既にインストールされている場合の競合を解決
dnf install -y wget unzip jq net-tools --skip-broken

# ==============================================================================
# 2. Grafanaリポジトリの追加とインストール
# ==============================================================================
echo "=== Grafana OSS インストール ==="

# GPGキーのインポート
wget -q -O gpg.key https://rpm.grafana.com/gpg.key
rpm --import gpg.key

# Grafanaリポジトリの追加
cat > /etc/yum.repos.d/grafana.repo << 'EOF'
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF

# Grafanaのインストール
dnf install -y grafana

echo "Grafana インストール完了"

# ==============================================================================
# 3. プラグインディレクトリの作成
# ==============================================================================
echo "=== プラグインディレクトリ作成 ==="

# プラグインディレクトリを事前に作成
mkdir -p /var/lib/grafana/plugins
chown -R grafana:grafana /var/lib/grafana
chmod -R 755 /var/lib/grafana

# ==============================================================================
# 4. DuckDBプラグインのダウンロードとインストール
# ==============================================================================
echo "=== DuckDB プラグイン インストール ==="

# プラグインディレクトリへ移動
cd /var/lib/grafana/plugins

# DuckDBプラグインのダウンロード
PLUGIN_VERSION="v0.2.0"
PLUGIN_URL="https://github.com/motherduckdb/grafana-duckdb-datasource/releases/download/${PLUGIN_VERSION}/motherduck-duckdb-datasource-0.2.0.zip"

echo "プラグインダウンロード: $PLUGIN_URL"
wget -O duckdb-plugin.zip "$PLUGIN_URL"

# プラグインの展開
unzip duckdb-plugin.zip
rm duckdb-plugin.zip

# DuckDB用の作業ディレクトリを作成
echo "=== DuckDB 作業ディレクトリ作成 ==="
mkdir -p /var/lib/grafana/duckdb

# 権限設定
chown -R grafana:grafana /var/lib/grafana/plugins
chown -R grafana:grafana /var/lib/grafana/duckdb
chmod -R 755 /var/lib/grafana/plugins
chmod -R 755 /var/lib/grafana/duckdb

echo "DuckDB プラグイン インストール完了"

# ==============================================================================
# 5. Grafana設定ファイルの作成
# ==============================================================================
echo "=== Grafana 設定ファイル作成 ==="

# 元の設定ファイルをバックアップ
cp /etc/grafana/grafana.ini /etc/grafana/grafana.ini.backup

# 新しい設定ファイルを作成
cat > /etc/grafana/grafana.ini << 'EOF'
##################### Grafana Configuration #####################

[DEFAULT]
instance_name = grafana-aws-duckdb

#################################### Server ##############################
[server]
# HTTP Serverの設定
http_addr = 0.0.0.0
http_port = 3000
domain = localhost
root_url = http://localhost:3000/

# セキュリティ設定
enforce_domain = false
cookie_secure = false
cookie_samesite = lax

#################################### Security ##############################
[security]
# 管理者設定
admin_user = admin
admin_password = GrafanaAdmin2025!

# セキュリティ設定
allow_embedding = false
cookie_secure = false
strict_transport_security = false

# セッション設定
login_remember_days = 7
disable_gravatar = false

#################################### Plugins ##############################
[plugins]
# プラグイン設定
enable_alpha = false
allow_loading_unsigned_plugins = motherduck-duckdb-datasource

#################################### Logging ##############################
[log]
# ログ設定
mode = console file
level = info
filters = rendering:debug

[log.console]
level = info
format = console

[log.file]
level = info
format = text
log_rotate = true
max_lines = 1000000
max_size_shift = 28
daily_rotate = true
max_days = 7

#################################### Analytics ##############################
[analytics]
# 使用統計の無効化
reporting_enabled = false
check_for_updates = false

#################################### Users ##############################
[users]
# ユーザー管理
allow_sign_up = false
allow_org_create = false
auto_assign_org = true
auto_assign_org_role = Viewer

#################################### Auth ##############################
[auth]
# 認証設定
disable_login_form = false
disable_signout_menu = false

EOF

echo "Grafana 設定ファイル作成完了"

# ==============================================================================
# 6. Grafanaサービスの設定と開始
# ==============================================================================
echo "=== Grafana サービス設定 ==="

# systemdサービスファイルのカスタマイズ
echo "=== systemd サービスファイル設定 ==="
mkdir -p /etc/systemd/system/grafana-server.service.d

# DuckDB用の環境変数を設定するdropinファイルを作成
cat > /etc/systemd/system/grafana-server.service.d/duckdb.conf << 'EOF'
[Service]
Environment="HOME=/var/lib/grafana/duckdb"
EOF

# systemdデーモンの再読み込み
systemctl daemon-reload

# Grafanaサービスの有効化（起動時に自動開始）
systemctl enable grafana-server

# Grafanaサービスの開始
systemctl start grafana-server

# サービス状態の確認
sleep 5
if systemctl is-active --quiet grafana-server; then
    echo "✅ Grafana サービス正常起動"
else
    echo "❌ Grafana サービス起動失敗"
    systemctl status grafana-server --no-pager
fi