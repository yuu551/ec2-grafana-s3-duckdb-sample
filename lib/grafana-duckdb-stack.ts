import * as cdk from "aws-cdk-lib";
import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as iam from "aws-cdk-lib/aws-iam";
import * as s3 from "aws-cdk-lib/aws-s3";
import { Construct } from "constructs";
import * as fs from "fs";
import * as path from "path";

export class GrafanaDuckdbStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // ==============================================================================
    // VPC設定 - デフォルトVPCを使用
    // ==============================================================================
    const vpc = ec2.Vpc.fromLookup(this, "DefaultVPC", {
      isDefault: true,
    });

    // ==============================================================================
    // S3バケット
    // ==============================================================================
    const dataBucket = new s3.Bucket(this, "GrafanaDataBucket", {
      bucketName: `grafana-duckdb-data-${cdk.Aws.ACCOUNT_ID}-${cdk.Aws.REGION}`,
      removalPolicy: cdk.RemovalPolicy.DESTROY, // 開発環境用
      autoDeleteObjects: true, // 開発環境用
    });

    // ==============================================================================
    // セキュリティグループ
    // ==============================================================================
    const grafanaSecurityGroup = new ec2.SecurityGroup(
      this,
      "GrafanaSecurityGroup",
      {
        vpc,
        description: "Security Group for Grafana instance",
        allowAllOutbound: true,
      }
    );

    // ==============================================================================
    // IAM ロール
    // ==============================================================================
    const grafanaRole = new iam.Role(this, "GrafanaInstanceRole", {
      assumedBy: new iam.ServicePrincipal("ec2.amazonaws.com"),
      description: "IAM role for Grafana EC2 instance",
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName(
          "AmazonSSMManagedInstanceCore"
        ),
      ],
    });

    // S3バケットへのアクセス権限を追加
    dataBucket.grantReadWrite(grafanaRole);

    // 追加のS3権限（必要に応じて）
    grafanaRole.addToPolicy(
      new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        actions: [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:ListBucketMultipartUploads",
        ],
        resources: [dataBucket.bucketArn],
      })
    );

    grafanaRole.addToPolicy(
      new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        actions: [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetObjectVersion",
          "s3:ListMultipartUploadParts",
          "s3:AbortMultipartUpload",
        ],
        resources: [`${dataBucket.bucketArn}/*`],
      })
    );

    // ==============================================================================
    // UserData - セットアップスクリプトの読み込み
    // ==============================================================================
    const userDataScript = fs.readFileSync(
      path.join(__dirname, "../scripts/setup-grafana.sh"),
      "utf8"
    );

    const userData = ec2.UserData.forLinux();
    userData.addCommands(userDataScript);

    // ==============================================================================
    // キーペア
    // ==============================================================================
    const keyPair = new ec2.KeyPair(this, "KeyPair", {
      type: ec2.KeyPairType.ED25519,
      format: ec2.KeyPairFormat.PEM,
    });

    // ==============================================================================
    // EC2インスタンス
    // ==============================================================================
    const grafanaInstance = new ec2.Instance(this, "GrafanaInstance", {
      vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PUBLIC },
      instanceType: ec2.InstanceType.of(
        ec2.InstanceClass.T3,
        ec2.InstanceSize.MICRO
      ),
      machineImage: ec2.MachineImage.latestAmazonLinux2023(),
      securityGroup: grafanaSecurityGroup,
      role: grafanaRole,
      userData: userData,
      keyPair: keyPair,
    });

    // ==============================================================================
    // Outputs
    // ==============================================================================
    new cdk.CfnOutput(this, "GrafanaInstanceId", {
      value: grafanaInstance.instanceId,
      description: "EC2 Instance ID for Grafana",
    });

    new cdk.CfnOutput(this, "DefaultCredentials", {
      value: "Username: admin, Password: GrafanaAdmin2025!",
      description: "Default Grafana login credentials",
    });
  }
}
