# Grafana DuckDB AWS

AWS CDKを使用してEC2上にGrafana OSS + DuckDBプラグインを構築し、S3データを可視化するプロジェクトです。

## 概要

このプロジェクトは、以下の構成でAWS環境にGrafanaとDuckDBを構築します：

- **EC2インスタンス**: Amazon Linux 2023上でGrafana OSS実行
- **DuckDBプラグイン**: S3データへの直接アクセス
- **IAMロール認証**: セキュアなS3アクセス
- **SSM Session Manager**: セキュアなリモートアクセス

## アーキテクチャ

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Developer     │    │   EC2 Instance   │    │   S3 Bucket     │
│                 │    │                  │    │                 │
│ SSM Session ────┼────┤ Grafana OSS      │    │ Parquet Files   │
│ Manager         │    │ + DuckDB Plugin  ├────┤ (IoT Data)      │
│                 │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 前提条件

- AWS CLI設定済み
- CDKブートストラップ済み
- Node.js v20.16.0以上
- 適切なIAM権限（EC2、S3、IAM関連）

## セットアップ

### 1. 依存関係のインストール

```bash
npm install
```

### 2. CDKデプロイ

```bash
npm run deploy
```

### 3. Grafanaへのアクセス

デプロイ完了後、SSM Session Managerでポートフォワーディング：

```bash
aws ssm start-session \
    --target <INSTANCE_ID> \
    --document-name AWS-StartPortForwardingSession \
    --parameters '{"portNumber":["3000"],"localPortNumber":["3000"]}'
```

ブラウザで `http://localhost:3000` にアクセス

### 4. ログイン情報

- **ユーザー名**: `admin`
- **パスワード**: `GrafanaAdmin2025!`

## DuckDBデータソース設定

### Init SQL設定

```sql
INSTALL httpfs;
LOAD httpfs;
CREATE OR REPLACE SECRET (
    TYPE s3,
    PROVIDER credential_chain
);
```

### サンプルクエリ

```sql
SELECT 
    timestamp as time,
    temperature as value,
    'temperature' as metric
FROM 's3://grafana-duckdb-data-123456789012-ap-northeast-1/iot-data/sensor_data_2024_01.parquet'
WHERE $__timeFilter(timestamp)
ORDER BY timestamp;
```

## ディレクトリ構成

```
grafana-duckdb-aws/
├── lib/
│   └── grafana-duckdb-stack.ts    # CDKスタック定義
├── scripts/
│   └── setup-grafana.sh           # Grafanaセットアップスクリプト
├── config/
│   └── aws-duckdb-config.sql      # DuckDB設定テンプレート
├── bin/
│   └── grafana-duckdb-aws.ts      # CDKアプリエントリーポイント
├── package.json
└── cdk.json
```

## 利用可能なコマンド

```bash
npm run build      # TypeScriptコンパイル
npm run deploy     # CDKデプロイ
npm run destroy    # リソース削除
npm run diff       # 変更差分確認
npm run synth      # CloudFormationテンプレート生成
```

## セキュリティ

- インバウンドポートは開放せず、SSM Session Managerでアクセス
- IAMロールによるS3認証（アクセスキー不要）
- セキュリティグループで最小権限の原則を適用

## トラブルシューティング

### セットアップログの確認

```bash
# EC2インスタンスにSSMでアクセス
aws ssm start-session --target <INSTANCE_ID>

# ログ確認
sudo tail -f /var/log/grafana-setup.log
```

### Grafanaサービス状態確認

```bash
sudo systemctl status grafana-server
```

## クリーンアップ

```bash
npm run destroy
```

## ライセンス

MIT License 