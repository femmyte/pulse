resource "aws_config_configuration_recorder" "socialjar" {
  name     = "socialjar"
  role_arn = aws_iam_role.role.arn
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}


resource "aws_iam_role" "role" {
  name               = "awsconfig"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

//Used to collect data from within the aws acount 
resource "aws_config_configuration_aggregator" "socialjar-aggregator" {
  name = "socialjar-aggregator"

  account_aggregation_source {
    //Place change account id to your own when running
    account_ids = ["609806490186"]
    regions     = ["us-east-1"]
  }
}


data "aws_iam_policy_document" "aggregator_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}
resource "aws_iam_role" "organization" {
  name               = "socialjar-org"
  assume_role_policy = data.aws_iam_policy_document.aggregator_role.json
}

resource "aws_iam_role_policy_attachment" "organization" {
  role       = aws_iam_role.organization.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRoleForOrganizations"
}

resource "aws_config_delivery_channel" "socialjar" {
  name           = "socialjar-channel"
  s3_bucket_name = aws_s3_bucket.b.id
  depends_on     = [aws_config_configuration_recorder.socialjar]
}


resource "aws_s3_bucket" "b" {
  bucket        = "delivery-channel-b"
  force_destroy = true
}

data "aws_iam_policy_document" "policy" {
  statement {
    effect  = "Allow"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.b.arn,
      "${aws_s3_bucket.b.arn}/*"
    ]
  }
}

resource "aws_iam_role_policy" "p" {
  name   = "awsconfig"
  role   = aws_iam_role.role.id
  policy = data.aws_iam_policy_document.policy.json
}


resource "aws_config_configuration_recorder_status" "foo" {
  name       = aws_config_configuration_recorder.socialjar.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.socialjar]
}

resource "aws_iam_role_policy_attachment" "a" {
  role       = aws_iam_role.role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_config_config_rule" "r" {
  name = "awsconfig-rule-set"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_VERSIONING_ENABLED"
  }
  

  
  depends_on = [aws_config_configuration_recorder.socialjar]
}

resource "aws_config_conformance_pack" "s3conformancepack" {
  name = "s3conformancepack"
  depends_on = [aws_config_configuration_recorder.socialjar]

  template_body = <<EOT

Resources:
  S3BucketPublicReadProhibited:
    Type: AWS::Config::ConfigRule
    Properties:
      ConfigRuleName: S3BucketPublicReadProhibited
      Description: >- 
        Checks that your Amazon S3 buckets do not allow public read access.
        The rule checks the Block Public Access settings, the bucket policy, and the
        bucket access control list (ACL).
      Scope:
        ComplianceResourceTypes:
        - "AWS::S3::Bucket"
      Source:
        Owner: AWS
        SourceIdentifier: S3_BUCKET_PUBLIC_READ_PROHIBITED
      MaximumExecutionFrequency: Six_Hours
  S3BucketPublicWriteProhibited: 
    Type: "AWS::Config::ConfigRule"
    Properties: 
      ConfigRuleName: S3BucketPublicWriteProhibited
      Description: "Checks that your Amazon S3 buckets do not allow public write access. The rule checks the Block Public Access settings, the bucket policy, and the bucket access control list (ACL)."
      Scope: 
        ComplianceResourceTypes: 
        - "AWS::S3::Bucket"
      Source: 
        Owner: AWS
        SourceIdentifier: S3_BUCKET_PUBLIC_WRITE_PROHIBITED
      MaximumExecutionFrequency: Six_Hours
  S3BucketReplicationEnabled: 
    Type: "AWS::Config::ConfigRule"
    Properties: 
      ConfigRuleName: S3BucketReplicationEnabled
      Description: "Checks whether the Amazon S3 buckets have cross-region replication enabled."
      Scope: 
        ComplianceResourceTypes: 
        - "AWS::S3::Bucket"
      Source: 
        Owner: AWS
        SourceIdentifier: S3_BUCKET_REPLICATION_ENABLED
  S3BucketSSLRequestsOnly: 
    Type: "AWS::Config::ConfigRule"
    Properties: 
      ConfigRuleName: S3BucketSSLRequestsOnly
      Description: "Checks whether S3 buckets have policies that require requests to use Secure Socket Layer (SSL)."
      Scope: 
        ComplianceResourceTypes: 
        - "AWS::S3::Bucket"
      Source: 
        Owner: AWS
        SourceIdentifier: S3_BUCKET_SSL_REQUESTS_ONLY
  ServerSideEncryptionEnabled: 
    Type: "AWS::Config::ConfigRule"
    Properties: 
      ConfigRuleName: ServerSideEncryptionEnabled
      Description: "Checks that your Amazon S3 bucket either has S3 default encryption enabled or that the S3 bucket policy explicitly denies put-object requests without server side encryption."
      Scope: 
        ComplianceResourceTypes: 
        - "AWS::S3::Bucket"
      Source: 
        Owner: AWS
        SourceIdentifier: S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED
  S3BucketLoggingEnabled: 
    Type: "AWS::Config::ConfigRule"
    Properties: 
      ConfigRuleName: S3BucketLoggingEnabled
      Description: "Checks whether logging is enabled for your S3 buckets."
      Scope: 
        ComplianceResourceTypes: 
        - "AWS::S3::Bucket"
      Source: 
        Owner: AWS
        SourceIdentifier: S3_BUCKET_LOGGING_ENABLED
EOT
}



//----------------------------------------------------------------------------------------------------------------

resource "aws_config_conformance_pack" "lambda_conformance_pack" {
  name = "lambda-conformance"  # Set the conformance pack name to "lambda-conformance"
  depends_on = [aws_config_configuration_recorder.socialjar]

  template_body = <<EOT
    # The provided AWS CloudFormation template content goes here
    Parameters:
      LambdaFunctionSettingsCheckParamRuntime:
        Default: nodejs16.x, nodejs14.x, nodejs12.x, python3.9, python3.8, python3.7,
          python3.6, ruby2.7, java11, java8, java8.al2, go1.x, dotnetcore3.1, dotnet6
        Type: String
    Resources:
      LambdaDlqCheck:
        Properties:
          ConfigRuleName: lambda-dlq-check
          Scope:
            ComplianceResourceTypes:
            - AWS::Lambda::Function
          Source:
            Owner: AWS
            SourceIdentifier: LAMBDA_DLQ_CHECK
        Type: AWS::Config::ConfigRule
      LambdaFunctionSettingsCheck:
        Properties:
          ConfigRuleName: lambda-function-settings-check
          InputParameters:
            runtime:
              Fn::If:
              - lambdaFunctionSettingsCheckParamRuntime
              - Ref: LambdaFunctionSettingsCheckParamRuntime
              - Ref: AWS::NoValue
          Scope:
            ComplianceResourceTypes:
            - AWS::Lambda::Function
          Source:
            Owner: AWS
            SourceIdentifier: LAMBDA_FUNCTION_SETTINGS_CHECK
        Type: AWS::Config::ConfigRule
      LambdaInsideVpc:
        Properties:
          ConfigRuleName: lambda-inside-vpc
          Scope:
            ComplianceResourceTypes:
            - AWS::Lambda::Function
          Source:
            Owner: AWS
            SourceIdentifier: LAMBDA_INSIDE_VPC
        Type: AWS::Config::ConfigRule
      LambdaVpcMultiAzCheck:
        Properties:
          ConfigRuleName: lambda-vpc-multi-az-check
          Scope:
            ComplianceResourceTypes:
            - AWS::Lambda::Function
          Source:
            Owner: AWS
            SourceIdentifier: LAMBDA_VPC_MULTI_AZ_CHECK
        Type: AWS::Config::ConfigRule
    Conditions:
      lambdaFunctionSettingsCheckParamRuntime:
        Fn::Not:
        - Fn::Equals:
          - ''
          - Ref: LambdaFunctionSettingsCheckParamRuntime
    EOT
}


resource "aws_config_conformance_pack" "nist" {
  name = ""
  depends_on = [aws_config_configuration_recorder.socialjar]

  template_body = <<EOT
    Parameters:
  AccessKeysRotatedParamMaxAccessKeyAge:
    Default: '90'
    Type: String
  AcmCertificateExpirationCheckParamDaysToExpiration:
    Default: '90'
    Type: String
  BackupPlanMinFrequencyAndMinRetentionCheckParamRequiredFrequencyUnit:
    Default: days
    Type: String
  BackupPlanMinFrequencyAndMinRetentionCheckParamRequiredFrequencyValue:
    Default: '1'
    Type: String
  BackupPlanMinFrequencyAndMinRetentionCheckParamRequiredRetentionDays:
    Default: '35'
    Type: String
  DynamodbThroughputLimitCheckParamAccountRCUThresholdPercentage:
    Default: '80'
    Type: String
  DynamodbThroughputLimitCheckParamAccountWCUThresholdPercentage:
    Default: '80'
    Type: String
  Ec2VolumeInuseCheckParamDeleteOnTermination:
    Default: 'true'
    Type: String
  IamCustomerPolicyBlockedKmsActionsParamBlockedActionsPatterns:
    Default: kms:Decrypt,kms:ReEncryptFrom
    Type: String
  IamInlinePolicyBlockedKmsActionsParamBlockedActionsPatterns:
    Default: kms:Decrypt,kms:ReEncryptFrom
    Type: String
  IamPasswordPolicyParamMaxPasswordAge:
    Default: '90'
    Type: String
  IamPasswordPolicyParamMinimumPasswordLength:
    Default: '14'
    Type: String
  IamPasswordPolicyParamPasswordReusePrevention:
    Default: '24'
    Type: String
  IamPasswordPolicyParamRequireLowercaseCharacters:
    Default: 'true'
    Type: String
  IamPasswordPolicyParamRequireNumbers:
    Default: 'true'
    Type: String
  IamPasswordPolicyParamRequireSymbols:
    Default: 'true'
    Type: String
  IamPasswordPolicyParamRequireUppercaseCharacters:
    Default: 'true'
    Type: String
  IamUserUnusedCredentialsCheckParamMaxCredentialUsageAge:
    Default: '90'
    Type: String
  LambdaConcurrencyCheckParamConcurrencyLimitHigh:
    Default: '1000'
    Type: String
  LambdaConcurrencyCheckParamConcurrencyLimitLow:
    Default: '500'
    Type: String
  RedshiftClusterMaintenancesettingsCheckParamAllowVersionUpgrade:
    Default: 'true'
    Type: String
  RestrictedIncomingTrafficParamBlockedPort1:
    Default: '20'
    Type: String
  RestrictedIncomingTrafficParamBlockedPort2:
    Default: '21'
    Type: String
  RestrictedIncomingTrafficParamBlockedPort3:
    Default: '3389'
    Type: String
  RestrictedIncomingTrafficParamBlockedPort4:
    Default: '3306'
    Type: String
  RestrictedIncomingTrafficParamBlockedPort5:
    Default: '4333'
    Type: String
  VpcSgOpenOnlyToAuthorizedPortsParamAuthorizedTcpPorts:
    Default: '443'
    Type: String
Resources:
  AccessKeysRotated:
    Properties:
      ConfigRuleName: access-keys-rotated
      InputParameters:
        maxAccessKeyAge:
          Fn::If:
          - accessKeysRotatedParamMaxAccessKeyAge
          - Ref: AccessKeysRotatedParamMaxAccessKeyAge
          - Ref: AWS::NoValue
      Source:
        Owner: AWS
        SourceIdentifier: ACCESS_KEYS_ROTATED
    Type: AWS::Config::ConfigRule
  AccountPartOfOrganizations:
    Properties:
      ConfigRuleName: account-part-of-organizations
      Source:
        Owner: AWS
        SourceIdentifier: ACCOUNT_PART_OF_ORGANIZATIONS
    Type: AWS::Config::ConfigRule
  AcmCertificateExpirationCheck:
    Properties:
      ConfigRuleName: acm-certificate-expiration-check
      InputParameters:
        daysToExpiration:
          Fn::If:
          - acmCertificateExpirationCheckParamDaysToExpiration
          - Ref: AcmCertificateExpirationCheckParamDaysToExpiration
          - Ref: AWS::NoValue
      Scope:
        ComplianceResourceTypes:
        - AWS::ACM::Certificate
      Source:
        Owner: AWS
        SourceIdentifier: ACM_CERTIFICATE_EXPIRATION_CHECK
    Type: AWS::Config::ConfigRule
  AlbHttpToHttpsRedirectionCheck:
    Properties:
      ConfigRuleName: alb-http-to-https-redirection-check
      Source:
        Owner: AWS
        SourceIdentifier: ALB_HTTP_TO_HTTPS_REDIRECTION_CHECK
    Type: AWS::Config::ConfigRule
  AlbWafEnabled:
    Properties:
      ConfigRuleName: alb-waf-enabled
      Scope:
        ComplianceResourceTypes:
        - AWS::ElasticLoadBalancingV2::LoadBalancer
      Source:
        Owner: AWS
        SourceIdentifier: ALB_WAF_ENABLED
    Type: AWS::Config::ConfigRule
  ApiGwAssociatedWithWaf:
    Properties:
      ConfigRuleName: api-gw-associated-with-waf
      Scope:
        ComplianceResourceTypes:
        - AWS::ApiGateway::Stage
      Source:
        Owner: AWS
        SourceIdentifier: API_GW_ASSOCIATED_WITH_WAF
    Type: AWS::Config::ConfigRule
  ApiGwCacheEnabledAndEncrypted:
    Properties:
      ConfigRuleName: api-gw-cache-enabled-and-encrypted
      Scope:
        ComplianceResourceTypes:
        - AWS::ApiGateway::Stage
      Source:
        Owner: AWS
        SourceIdentifier: API_GW_CACHE_ENABLED_AND_ENCRYPTED
    Type: AWS::Config::ConfigRule
  ApiGwExecutionLoggingEnabled:
    Properties:
      ConfigRuleName: api-gw-execution-logging-enabled
      Scope:
        ComplianceResourceTypes:
        - AWS::ApiGateway::Stage
        - AWS::ApiGatewayV2::Stage
      Source:
        Owner: AWS
        SourceIdentifier: API_GW_EXECUTION_LOGGING_ENABLED
    Type: AWS::Config::ConfigRule
  ApiGwSslEnabled:
    Properties:
      ConfigRuleName: api-gw-ssl-enabled
      Scope:
        ComplianceResourceTypes:
        - AWS::ApiGateway::Stage
      Source:
        Owner: AWS
        SourceIdentifier: API_GW_SSL_ENABLED
    Type: AWS::Config::ConfigRule
  AutoscalingGroupElbHealthcheckRequired:
    Properties:
      ConfigRuleName: autoscaling-group-elb-healthcheck-required
      Scope:
        ComplianceResourceTypes:
        - AWS::AutoScaling::AutoScalingGroup
      Source:
        Owner: AWS
        SourceIdentifier: AUTOSCALING_GROUP_ELB_HEALTHCHECK_REQUIRED
    Type: AWS::Config::ConfigRule
  AutoscalingLaunchConfigPublicIpDisabled:
    Properties:
      ConfigRuleName: autoscaling-launch-config-public-ip-disabled
      Scope:
        ComplianceResourceTypes:
        - AWS::AutoScaling::LaunchConfiguration
      Source:
        Owner: AWS
        SourceIdentifier: AUTOSCALING_LAUNCH_CONFIG_PUBLIC_IP_DISABLED
    Type: AWS::Config::ConfigRule
  BackupPlanMinFrequencyAndMinRetentionCheck:
    Properties:
      ConfigRuleName: backup-plan-min-frequency-and-min-retention-check
      InputParameters:
        requiredFrequencyUnit:
          Fn::If:
          - backupPlanMinFrequencyAndMinRetentionCheckParamRequiredFrequencyUnit
          - Ref: BackupPlanMinFrequencyAndMinRetentionCheckParamRequiredFrequencyUnit
          - Ref: AWS::NoValue
        requiredFrequencyValue:
          Fn::If:
          - backupPlanMinFrequencyAndMinRetentionCheckParamRequiredFrequencyValue
          - Ref: BackupPlanMinFrequencyAndMinRetentionCheckParamRequiredFrequencyValue
          - Ref: AWS::NoValue
        requiredRetentionDays:
          Fn::If:
          - backupPlanMinFrequencyAndMinRetentionCheckParamRequiredRetentionDays
          - Ref: BackupPlanMinFrequencyAndMinRetentionCheckParamRequiredRetentionDays
          - Ref: AWS::NoValue
      Scope:
        ComplianceResourceTypes:
        - AWS::Backup::BackupPlan
      Source:
        Owner: AWS
        SourceIdentifier: BACKUP_PLAN_MIN_FREQUENCY_AND_MIN_RETENTION_CHECK
    Type: AWS::Config::ConfigRule
  BackupRecoveryPointEncrypted:
    Properties:
      ConfigRuleName: backup-recovery-point-encrypted
      Scope:
        ComplianceResourceTypes:
        - AWS::Backup::RecoveryPoint
      Source:
        Owner: AWS
        SourceIdentifier: BACKUP_RECOVERY_POINT_ENCRYPTED
    Type: AWS::Config::ConfigRule
  BackupRecoveryPointManualDeletionDisabled:
    Properties:
      ConfigRuleName: backup-recovery-point-manual-deletion-disabled
      Scope:
        ComplianceResourceTypes:
        - AWS::Backup::BackupVault
      Source:
        Owner: AWS
        SourceIdentifier: BACKUP_RECOVERY_POINT_MANUAL_DELETION_DISABLED
    Type: AWS::Config::ConfigRule
  BeanstalkEnhancedHealthReportingEnabled:
    Properties:
      ConfigRuleName: beanstalk-enhanced-health-reporting-enabled
      Scope:
        ComplianceResourceTypes:
        - AWS::ElasticBeanstalk::Environment
      Source:
        Owner: AWS
        SourceIdentifier: BEANSTALK_ENHANCED_HEALTH_REPORTING_ENABLED
    Type: AWS::Config::ConfigRule
  CloudTrailCloudWatchLogsEnabled:
    Properties:
      ConfigRuleName: cloud-trail-cloud-watch-logs-enabled
      Source:
        Owner: AWS
        SourceIdentifier: CLOUD_TRAIL_CLOUD_WATCH_LOGS_ENABLED
    Type: AWS::Config::ConfigRule
  CloudTrailEnabled:
    Properties:
      ConfigRuleName: cloudtrail-enabled
      Source:
        Owner: AWS
        SourceIdentifier: CLOUD_TRAIL_ENABLED
    Type: AWS::Config::ConfigRule
  CloudTrailEncryptionEnabled:
    Properties:
      ConfigRuleName: cloud-trail-encryption-enabled
      Source:
        Owner: AWS
        SourceIdentifier: CLOUD_TRAIL_ENCRYPTION_ENABLED
    Type: AWS::Config::ConfigRule
  CloudTrailLogFileValidationEnabled:
    Properties:
      ConfigRuleName: cloud-trail-log-file-validation-enabled
      Source:
        Owner: AWS
        SourceIdentifier: CLOUD_TRAIL_LOG_FILE_VALIDATION_ENABLED
    Type: AWS::Config::ConfigRule
  CloudtrailS3DataeventsEnabled:
    Properties:
      ConfigRuleName: cloudtrail-s3-dataevents-enabled
      Source:
        Owner: AWS
        SourceIdentifier: CLOUDTRAIL_S3_DATAEVENTS_ENABLED
    Type: AWS::Config::ConfigRule
  CloudwatchAlarmActionCheck:
    Properties:
      ConfigRuleName: cloudwatch-alarm-action-check
      InputParameters:
        alarmActionRequired: 'true'
        insufficientDataActionRequired: 'true'
        okActionRequired: 'false'
      Scope:
        ComplianceResourceTypes:
        - AWS::CloudWatch::Alarm
      Source:
        Owner: AWS
        SourceIdentifier: CLOUDWATCH_ALARM_ACTION_CHECK
    Type: AWS::Config::ConfigRule
  CmkBackingKeyRotationEnabled:
    Properties:
      ConfigRuleName: cmk-backing-key-rotation-enabled
      Source:
        Owner: AWS
        SourceIdentifier: CMK_BACKING_KEY_ROTATION_ENABLED
    Type: AWS::Config::ConfigRule
  CodebuildProjectEnvvarAwscredCheck:
    Properties:
      ConfigRuleName: codebuild-project-envvar-awscred-check
      Scope:
        ComplianceResourceTypes:
        - AWS::CodeBuild::Project
      Source:
        Owner: AWS
        SourceIdentifier: CODEBUILD_PROJECT_ENVVAR_AWSCRED_CHECK
    Type: AWS::Config::ConfigRule
  CodebuildProjectSourceRepoUrlCheck:
    Properties:
      ConfigRuleName: codebuild-project-source-repo-url-check
      Scope:
        ComplianceResourceTypes:
        - AWS::CodeBuild::Project
      Source:
        Owner: AWS
        SourceIdentifier: CODEBUILD_PROJECT_SOURCE_REPO_URL_CHECK
    Type: AWS::Config::ConfigRule
  CwLoggroupRetentionPeriodCheck:
    Properties:
      ConfigRuleName: cw-loggroup-retention-period-check
      Source:
        Owner: AWS
        SourceIdentifier: CW_LOGGROUP_RETENTION_PERIOD_CHECK
    Type: AWS::Config::ConfigRule
  DbInstanceBackupEnabled:
    Properties:
      ConfigRuleName: db-instance-backup-enabled
      Scope:
        ComplianceResourceTypes:
        - AWS::RDS::DBInstance
      Source:
        Owner: AWS
        SourceIdentifier: DB_INSTANCE_BACKUP_ENABLED
    Type: AWS::Config::ConfigRule
  DmsReplicationNotPublic:
    Properties:
      ConfigRuleName: dms-replication-not-public
      Scope:
        ComplianceResourceTypes: []
      Source:
        Owner: AWS
        SourceIdentifier: DMS_REPLICATION_NOT_PUBLIC
    Type: AWS::Config::ConfigRule
  DynamodbAutoscalingEnabled:
    Properties:
      ConfigRuleName: dynamodb-autoscaling-enabled
      Scope:
        ComplianceResourceTypes:
        - AWS::DynamoDB::Table
      Source:
        Owner: AWS
        SourceIdentifier: DYNAMODB_AUTOSCALING_ENABLED
    Type: AWS::Config::ConfigRule
  DynamodbInBackupPlan:
    Properties:
      ConfigRuleName: dynamodb-in-backup-plan
      Source:
        Owner: AWS
        SourceIdentifier: DYNAMODB_IN_BACKUP_PLAN
    Type: AWS::Config::ConfigRule
  DynamodbPitrEnabled:
    Properties:
      ConfigRuleName: dynamodb-pitr-enabled
      Scope:
        ComplianceResourceTypes:
        - AWS::DynamoDB::Table
      Source:
        Owner: AWS
        SourceIdentifier: DYNAMODB_PITR_ENABLED
    Type: AWS::Config::ConfigRule
  DynamodbResourcesProtectedByBackupPlan:
    Properties:
      ConfigRuleName: dynamodb-resources-protected-by-backup-plan
      Scope:
        ComplianceResourceTypes:
        - AWS::DynamoDB::Table
      Source:
        Owner: AWS
        SourceIdentifier: DYNAMODB_RESOURCES_PROTECTED_BY_BACKUP_PLAN
    Type: AWS::Config::ConfigRule
  DynamodbThroughputLimitCheck:
    Properties:
      ConfigRuleName: dynamodb-throughput-limit-check
      InputParameters:
        accountRCUThresholdPercentage:
          Fn::If:
          - dynamodbThroughputLimitCheckParamAccountRCUThresholdPercentage
          - Ref: DynamodbThroughputLimitCheckParamAccountRCUThresholdPercentage
          - Ref: AWS::NoValue
        accountWCUThresholdPercentage:
          Fn::If:
          - dynamodbThroughputLimitCheckParamAccountWCUThresholdPercentage
          - Ref: DynamodbThroughputLimitCheckParamAccountWCUThresholdPercentage
          - Ref: AWS::NoValue
      Source:
        Owner: AWS
        SourceIdentifier: DYNAMODB_THROUGHPUT_LIMIT_CHECK
    Type: AWS::Config::ConfigRule
  EbsInBackupPlan:
    Properties:
      ConfigRuleName: ebs-in-backup-plan
      Source:
        Owner: AWS
        SourceIdentifier: EBS_IN_BACKUP_PLAN
    Type: AWS::Config::ConfigRule
  EbsSnapshotPublicRestorableCheck:
    Properties:
      ConfigRuleName: ebs-snapshot-public-restorable-check
      Source:
        Owner: AWS
        SourceIdentifier: EBS_SNAPSHOT_PUBLIC_RESTORABLE_CHECK
    Type: AWS::Config::ConfigRule
  Ec2EbsEncryptionByDefault:
    Properties:
      ConfigRuleName: ec2-ebs-encryption-by-default
      Source:
        Owner: AWS
        SourceIdentifier: EC2_EBS_ENCRYPTION_BY_DEFAULT
    Type: AWS::Config::ConfigRule
  Ec2InstanceDetailedMonitoringEnabled:
    Properties:
      ConfigRuleName: ec2-instance-detailed-monitoring-enabled
      Scope:
        ComplianceResourceTypes:
        - AWS::EC2::Instance
      Source:
        Owner: AWS
        SourceIdentifier: EC2_INSTANCE_DETAILED_MONITORING_ENABLED
    Type: AWS::Config::ConfigRule
  Ec2InstanceManagedBySsm:
    Properties:
      ConfigRuleName: ec2-instance-managed-by-systems-manager
      Scope:
        ComplianceResourceTypes:
        - AWS::EC2::Instance
        - AWS::SSM::ManagedInstanceInventory
      Source:
        Owner: AWS
        SourceIdentifier: EC2_INSTANCE_MANAGED_BY_SSM
    Type: AWS::Config::ConfigRule
  Ec2InstanceNoPublicIp:
    Properties:
      ConfigRuleName: ec2-instance-no-public-ip
      Scope:
        ComplianceResourceTypes:
        - AWS::EC2::Instance
      Source:
        Owner: AWS
        SourceIdentifier: EC2_INSTANCE_NO_PUBLIC_IP
    Type: AWS::Config::ConfigRule
  Ec2InstanceProfileAttached:
    Properties:
      ConfigRuleName: ec2-instance-profile-attached
      Scope:
        ComplianceResourceTypes:
        - AWS::EC2::Instance
      Source:
        Owner: AWS
        SourceIdentifier: EC2_INSTANCE_PROFILE_ATTACHED
    Type: AWS::Config::ConfigRule
  Ec2ManagedinstanceAssociationComplianceStatusCheck:
    Properties:
      ConfigRuleName: ec2-managedinstance-association-compliance-status-check
      Scope:
        ComplianceResourceTypes:
        - AWS::SSM::AssociationCompliance
      Source:
        Owner: AWS
        SourceIdentifier: EC2_MANAGEDINSTANCE_ASSOCIATION_COMPLIANCE_STATUS_CHECK
    Type: AWS::Config::ConfigRule
  Ec2ManagedinstancePatchComplianceStatusCheck:
    Properties:
      ConfigRuleName: ec2-managedinstance-patch-compliance-status-check
      Scope:
        ComplianceResourceTypes:
        - AWS::SSM::PatchCompliance
      Source:
        Owner: AWS
        SourceIdentifier: EC2_MANAGEDINSTANCE_PATCH_COMPLIANCE_STATUS_CHECK
    Type: AWS::Config::ConfigRule
  Ec2ResourcesProtectedByBackupPlan:
    Properties:
      ConfigRuleName: ec2-resources-protected-by-backup-plan
      Scope:
        ComplianceResourceTypes:
        - AWS::EC2::Instance
      Source:
        Owner: AWS
        SourceIdentifier: EC2_RESOURCES_PROTECTED_BY_BACKUP_PLAN
    Type: AWS::Config::ConfigRule
  Ec2StoppedInstance:
    Properties:
      ConfigRuleName: ec2-stopped-instance
      Source:
        Owner: AWS
        SourceIdentifier: EC2_STOPPED_INSTANCE
    Type: AWS::Config::ConfigRule
  Ec2VolumeInuseCheck:
    Properties:
      ConfigRuleName: ec2-volume-inuse-check
      InputParameters:
        deleteOnTermination:
          Fn::If:
          - ec2VolumeInuseCheckParamDeleteOnTermination
          - Ref: Ec2VolumeInuseCheckParamDeleteOnTermination
          - Ref: AWS::NoValue
      Scope:
        ComplianceResourceTypes:
        - AWS::EC2::Volume
      Source:
        Owner: AWS
        SourceIdentifier: EC2_VOLUME_INUSE_CHECK
    Type: AWS::Config::ConfigRule
  EcsTaskDefinitionUserForHostModeCheck:
    Properties:
      ConfigRuleName: ecs-task-definition-user-for-host-mode-check
      Scope:
        ComplianceResourceTypes:
        - AWS::ECS::TaskDefinition
      Source:
        Owner: AWS
        SourceIdentifier: ECS_TASK_DEFINITION_USER_FOR_HOST_MODE_CHECK
    Type: AWS::Config::ConfigRule
  EfsEncryptedCheck:
    Properties:
      ConfigRuleName: efs-encrypted-check
      Source:
        Owner: AWS
        SourceIdentifier: EFS_ENCRYPTED_CHECK
    Type: AWS::Config::ConfigRule
  EfsInBackupPlan:
    Properties:
      ConfigRuleName: efs-in-backup-plan
      Source:
        Owner: AWS
        SourceIdentifier: EFS_IN_BACKUP_PLAN
    Type: AWS::Config::ConfigRule
  ElasticBeanstalkManagedUpdatesEnabled:
    Properties:
      ConfigRuleName: elastic-beanstalk-managed-updates-enabled
      Scope:
        ComplianceResourceTypes:
        - AWS::ElasticBeanstalk::Environment
      Source:
        Owner: AWS
        SourceIdentifier: ELASTIC_BEANSTALK_MANAGED_UPDATES_ENABLED
    Type: AWS::Config::ConfigRule
  ElasticacheRedisClusterAutomaticBackupCheck:
    Properties:
      ConfigRuleName: elasticache-redis-cluster-automatic-backup-check
      Source:
        Owner: AWS
        SourceIdentifier: ELASTICACHE_REDIS_CLUSTER_AUTOMATIC_BACKUP_CHECK
    Type: AWS::Config::ConfigRule
  ElasticsearchEncryptedAtRest:
    Properties:
      ConfigRuleName: elasticsearch-encrypted-at-rest
      Source:
        Owner: AWS
        SourceIdentifier: ELASTICSEARCH_ENCRYPTED_AT_REST
    Type: AWS::Config::ConfigRule
  ElasticsearchInVpcOnly:
    Properties:
      ConfigRuleName: elasticsearch-in-vpc-only
      Source:
        Owner: AWS
        SourceIdentifier: ELASTICSEARCH_IN_VPC_ONLY
    Type: AWS::Config::ConfigRule
  ElasticsearchLogsToCloudwatch:
    Properties:
      ConfigRuleName: elasticsearch-logs-to-cloudwatch
      Scope:
        ComplianceResourceTypes:
        - AWS::Elasticsearch::Domain
      Source:
        Owner: AWS
        SourceIdentifier: ELASTICSEARCH_LOGS_TO_CLOUDWATCH
    Type: AWS::Config::ConfigRule
  ElasticsearchNodeToNodeEncryptionCheck:
    Properties:
      ConfigRuleName: elasticsearch-node-to-node-encryption-check
      Scope:
        ComplianceResourceTypes:
        - AWS::Elasticsearch::Domain
      Source:
        Owner: AWS
        SourceIdentifier: ELASTICSEARCH_NODE_TO_NODE_ENCRYPTION_CHECK
    Type: AWS::Config::ConfigRule
  ElbAcmCertificateRequired:
    Properties:
      ConfigRuleName: elb-acm-certificate-required
      Scope:
        ComplianceResourceTypes:
        - AWS::ElasticLoadBalancing::LoadBalancer
      Source:
        Owner: AWS
        SourceIdentifier: ELB_ACM_CERTIFICATE_REQUIRED
    Type: AWS::Config::ConfigRule
  ElbCrossZoneLoadBalancingEnabled:
    Properties:
      ConfigRuleName: elb-cross-zone-load-balancing-enabled
      Scope:
        ComplianceResourceTypes:
        - AWS::ElasticLoadBalancing::LoadBalancer
      Source:
        Owner: AWS
        SourceIdentifier: ELB_CROSS_ZONE_LOAD_BALANCING_ENABLED
    Type: AWS::Config::ConfigRule
  ElbDeletionProtectionEnabled:
    Properties:
      ConfigRuleName: elb-deletion-protection-enabled
      Scope:
        ComplianceResourceTypes:
        - AWS::ElasticLoadBalancingV2::LoadBalancer
      Source:
        Owner: AWS
        SourceIdentifier: ELB_DELETION_PROTECTION_ENABLED
    Type: AWS::Config::ConfigRule
  ElbLoggingEnabled:
    Properties:
      ConfigRuleName: elb-logging-enabled
      Scope:
        ComplianceResourceTypes:
        - AWS::ElasticLoadBalancing::LoadBalancer
        - AWS::ElasticLoadBalancingV2::LoadBalancer
      Source:
        Owner: AWS
        SourceIdentifier: ELB_LOGGING_ENABLED
    Type: AWS::Config::ConfigRule
  ElbTlsHttpsListenersOnly:
    Properties:
      ConfigRuleName: elb-tls-https-listeners-only
      Scope:
        ComplianceResourceTypes:
        - AWS::ElasticLoadBalancing::LoadBalancer
      Source:
        Owner: AWS
        SourceIdentifier: ELB_TLS_HTTPS_LISTENERS_ONLY
    Type: AWS::Config::ConfigRule
  Elbv2AcmCertificateRequired:
    Properties:
      ConfigRuleName: elbv2-acm-certificate-required
      Source:
        Owner: AWS
        SourceIdentifier: ELBV2_ACM_CERTIFICATE_REQUIRED
    Type: AWS::Config::ConfigRule
  EmrKerberosEnabled:
    Properties:
      ConfigRuleName: emr-kerberos-enabled
      Source:
        Owner: AWS
        SourceIdentifier: EMR_KERBEROS_ENABLED
    Type: AWS::Config::ConfigRule
  EmrMasterNoPublicIp:
    Properties:
      ConfigRuleName: emr-master-no-public-ip
      Scope:
        ComplianceResourceTypes: []
      Source:
        Owner: AWS
        SourceIdentifier: EMR_MASTER_NO_PUBLIC_IP
    Type: AWS::Config::ConfigRule
  EncryptedVolumes:
    Properties:
      ConfigRuleName: encrypted-volumes
      Scope:
        ComplianceResourceTypes:
        - AWS::EC2::Volume
      Source:
        Owner: AWS
        SourceIdentifier: ENCRYPTED_VOLUMES
    Type: AWS::Config::ConfigRule
  GuarddutyEnabledCentralized:
    Properties:
      ConfigRuleName: guardduty-enabled-centralized
      Source:
        Owner: AWS
        SourceIdentifier: GUARDDUTY_ENABLED_CENTRALIZED
    Type: AWS::Config::ConfigRule
  IamCustomerPolicyBlockedKmsActions:
    Properties:
      ConfigRuleName: iam-customer-policy-blocked-kms-actions
      InputParameters:
        blockedActionsPatterns:
          Fn::If:
          - iamCustomerPolicyBlockedKmsActionsParamBlockedActionsPatterns
          - Ref: IamCustomerPolicyBlockedKmsActionsParamBlockedActionsPatterns
          - Ref: AWS::NoValue
      Scope:
        ComplianceResourceTypes:
        - AWS::IAM::Policy
      Source:
        Owner: AWS
        SourceIdentifier: IAM_CUSTOMER_POLICY_BLOCKED_KMS_ACTIONS
    Type: AWS::Config::ConfigRule
  IamGroupHasUsersCheck:
    Properties:
      ConfigRuleName: iam-group-has-users-check
      Scope:
        ComplianceResourceTypes:
        - AWS::IAM::Group
      Source:
        Owner: AWS
        SourceIdentifier: IAM_GROUP_HAS_USERS_CHECK
    Type: AWS::Config::ConfigRule
  IamInlinePolicyBlockedKmsActions:
    Properties:
      ConfigRuleName: iam-inline-policy-blocked-kms-actions
      InputParameters:
        blockedActionsPatterns:
          Fn::If:
          - iamInlinePolicyBlockedKmsActionsParamBlockedActionsPatterns
          - Ref: IamInlinePolicyBlockedKmsActionsParamBlockedActionsPatterns
          - Ref: AWS::NoValue
      Scope:
        ComplianceResourceTypes:
        - AWS::IAM::Group
        - AWS::IAM::Role
        - AWS::IAM::User
      Source:
        Owner: AWS
        SourceIdentifier: IAM_INLINE_POLICY_BLOCKED_KMS_ACTIONS
    Type: AWS::Config::ConfigRule
  IamNoInlinePolicyCheck:
    Properties:
      ConfigRuleName: iam-no-inline-policy-check
      Scope:
        ComplianceResourceTypes:
        - AWS::IAM::User
        - AWS::IAM::Role
        - AWS::IAM::Group
      Source:
        Owner: AWS
        SourceIdentifier: IAM_NO_INLINE_POLICY_CHECK
    Type: AWS::Config::ConfigRule
  IamPasswordPolicy:
    Properties:
      ConfigRuleName: iam-password-policy
      InputParameters:
        MaxPasswordAge:
          Fn::If:
          - iamPasswordPolicyParamMaxPasswordAge
          - Ref: IamPasswordPolicyParamMaxPasswordAge
          - Ref: AWS::NoValue
        MinimumPasswordLength:
          Fn::If:
          - iamPasswordPolicyParamMinimumPasswordLength
          - Ref: IamPasswordPolicyParamMinimumPasswordLength
          - Ref: AWS::NoValue
        PasswordReusePrevention:
          Fn::If:
          - iamPasswordPolicyParamPasswordReusePrevention
          - Ref: IamPasswordPolicyParamPasswordReusePrevention
          - Ref: AWS::NoValue
        RequireLowercaseCharacters:
          Fn::If:
          - iamPasswordPolicyParamRequireLowercaseCharacters
          - Ref: IamPasswordPolicyParamRequireLowercaseCharacters
          - Ref: AWS::NoValue
        RequireNumbers:
          Fn::If:
          - iamPasswordPolicyParamRequireNumbers
          - Ref: IamPasswordPolicyParamRequireNumbers
          - Ref: AWS::NoValue
        RequireSymbols:
          Fn::If:
          - iamPasswordPolicyParamRequireSymbols
          - Ref: IamPasswordPolicyParamRequireSymbols
          - Ref: AWS::NoValue
        RequireUppercaseCharacters:
          Fn::If:
          - iamPasswordPolicyParamRequireUppercaseCharacters
          - Ref: IamPasswordPolicyParamRequireUppercaseCharacters
          - Ref: AWS::NoValue
      Source:
        Owner: AWS
        SourceIdentifier: IAM_PASSWORD_POLICY
    Type: AWS::Config::ConfigRule
  IamPolicyNoStatementsWithAdminAccess:
    Properties:
      ConfigRuleName: iam-policy-no-statements-with-admin-access
      Scope:
        ComplianceResourceTypes:
        - AWS::IAM::Policy
      Source:
        Owner: AWS
        SourceIdentifier: IAM_POLICY_NO_STATEMENTS_WITH_ADMIN_ACCESS
    Type: AWS::Config::ConfigRule
  IamPolicyNoStatementsWithFullAccess:
    Properties:
      ConfigRuleName: iam-policy-no-statements-with-full-access
      Scope:
        ComplianceResourceTypes:
        - AWS::IAM::Policy
      Source:
        Owner: AWS
        SourceIdentifier: IAM_POLICY_NO_STATEMENTS_WITH_FULL_ACCESS
    Type: AWS::Config::ConfigRule
  IamRootAccessKeyCheck:
    Properties:
      ConfigRuleName: iam-root-access-key-check
      Source:
        Owner: AWS
        SourceIdentifier: IAM_ROOT_ACCESS_KEY_CHECK
    Type: AWS::Config::ConfigRule
  IamUserGroupMembershipCheck:
    Properties:
      ConfigRuleName: iam-user-group-membership-check
      Scope:
        ComplianceResourceTypes:
        - AWS::IAM::User
      Source:
        Owner: AWS
        SourceIdentifier: IAM_USER_GROUP_MEMBERSHIP_CHECK
    Type: AWS::Config::ConfigRule
  IamUserMfaEnabled:
    Properties:
      ConfigRuleName: iam-user-mfa-enabled
      Source:
        Owner: AWS
        SourceIdentifier: IAM_USER_MFA_ENABLED
    Type: AWS::Config::ConfigRule
  IamUserNoPoliciesCheck:
    Properties:
      ConfigRuleName: iam-user-no-policies-check
      Scope:
        ComplianceResourceTypes:
        - AWS::IAM::User
      Source:
        Owner: AWS
        SourceIdentifier: IAM_USER_NO_POLICIES_CHECK
    Type: AWS::Config::ConfigRule
  IamUserUnusedCredentialsCheck:
    Properties:
      ConfigRuleName: iam-user-unused-credentials-check
      InputParameters:
        maxCredentialUsageAge:
          Fn::If:
          - iamUserUnusedCredentialsCheckParamMaxCredentialUsageAge
          - Ref: IamUserUnusedCredentialsCheckParamMaxCredentialUsageAge
          - Ref: AWS::NoValue
      Source:
        Owner: AWS
        SourceIdentifier: IAM_USER_UNUSED_CREDENTIALS_CHECK
    Type: AWS::Config::ConfigRule
  IncomingSshDisabled:
    Properties:
      ConfigRuleName: restricted-ssh
      Scope:
        ComplianceResourceTypes:
        - AWS::EC2::SecurityGroup
      Source:
        Owner: AWS
        SourceIdentifier: INCOMING_SSH_DISABLED
    Type: AWS::Config::ConfigRule
  InstancesInVpc:
    Properties:
      ConfigRuleName: ec2-instances-in-vpc
      Scope:
        ComplianceResourceTypes:
        - AWS::EC2::Instance
      Source:
        Owner: AWS
        SourceIdentifier: INSTANCES_IN_VPC
    Type: AWS::Config::ConfigRule
  KmsCmkNotScheduledForDeletion:
    Properties:
      ConfigRuleName: kms-cmk-not-scheduled-for-deletion
      Scope:
        ComplianceResourceTypes:
        - AWS::KMS::Key
      Source:
        Owner: AWS
        SourceIdentifier: KMS_CMK_NOT_SCHEDULED_FOR_DELETION
    Type: AWS::Config::ConfigRule
  LambdaConcurrencyCheck:
    Properties:
      ConfigRuleName: lambda-concurrency-check
      InputParameters:
        ConcurrencyLimitHigh:
          Fn::If:
          - lambdaConcurrencyCheckParamConcurrencyLimitHigh
          - Ref: LambdaConcurrencyCheckParamConcurrencyLimitHigh
          - Ref: AWS::NoValue
        ConcurrencyLimitLow:
          Fn::If:
          - lambdaConcurrencyCheckParamConcurrencyLimitLow
          - Ref: LambdaConcurrencyCheckParamConcurrencyLimitLow
          - Ref: AWS::NoValue
      Scope:
        ComplianceResourceTypes:
        - AWS::Lambda::Function
      Source:
        Owner: AWS
        SourceIdentifier: LAMBDA_CONCURRENCY_CHECK
    Type: AWS::Config::ConfigRule
  LambdaDlqCheck:
    Properties:
      ConfigRuleName: lambda-dlq-check
      Scope:
        ComplianceResourceTypes:
        - AWS::Lambda::Function
      Source:
        Owner: AWS
        SourceIdentifier: LAMBDA_DLQ_CHECK
    Type: AWS::Config::ConfigRule
  LambdaFunctionPublicAccessProhibited:
    Properties:
      ConfigRuleName: lambda-function-public-access-prohibited
      Scope:
        ComplianceResourceTypes:
        - AWS::Lambda::Function
      Source:
        Owner: AWS
        SourceIdentifier: LAMBDA_FUNCTION_PUBLIC_ACCESS_PROHIBITED
    Type: AWS::Config::ConfigRule
  LambdaInsideVpc:
    Properties:
      ConfigRuleName: lambda-inside-vpc
      Scope:
        ComplianceResourceTypes:
        - AWS::Lambda::Function
      Source:
        Owner: AWS
        SourceIdentifier: LAMBDA_INSIDE_VPC
    Type: AWS::Config::ConfigRule
  MfaEnabledForIamConsoleAccess:
    Properties:
      ConfigRuleName: mfa-enabled-for-iam-console-access
      Source:
        Owner: AWS
        SourceIdentifier: MFA_ENABLED_FOR_IAM_CONSOLE_ACCESS
    Type: AWS::Config::ConfigRule
  MultiRegionCloudTrailEnabled:
    Properties:
      ConfigRuleName: multi-region-cloudtrail-enabled
      Source:
        Owner: AWS
        SourceIdentifier: MULTI_REGION_CLOUD_TRAIL_ENABLED
    Type: AWS::Config::ConfigRule
  NoUnrestrictedRouteToIgw:
    Properties:
      ConfigRuleName: no-unrestricted-route-to-igw
      Scope:
        ComplianceResourceTypes:
        - AWS::EC2::RouteTable
      Source:
        Owner: AWS
        SourceIdentifier: NO_UNRESTRICTED_ROUTE_TO_IGW
    Type: AWS::Config::ConfigRule
  RdsAutomaticMinorVersionUpgradeEnabled:
    Properties:
      ConfigRuleName: rds-automatic-minor-version-upgrade-enabled
      Scope:
        ComplianceResourceTypes:
        - AWS::RDS::DBInstance
      Source:
        Owner: AWS
        SourceIdentifier: RDS_AUTOMATIC_MINOR_VERSION_UPGRADE_ENABLED
    Type: AWS::Config::ConfigRule
  RdsEnhancedMonitoringEnabled:
    Properties:
      ConfigRuleName: rds-enhanced-monitoring-enabled
      Scope:
        ComplianceResourceTypes:
        - AWS::RDS::DBInstance
      Source:
        Owner: AWS
        SourceIdentifier: RDS_ENHANCED_MONITORING_ENABLED
    Type: AWS::Config::ConfigRule
  RdsInBackupPlan:
    Properties:
      ConfigRuleName: rds-in-backup-plan
      Source:
        Owner: AWS
        SourceIdentifier: RDS_IN_BACKUP_PLAN
    Type: AWS::Config::ConfigRule
  RdsInstanceDeletionProtectionEnabled:
    Properties:
      ConfigRuleName: rds-instance-deletion-protection-enabled
      Scope:
        ComplianceResourceTypes:
        - AWS::RDS::DBInstance
      Source:
        Owner: AWS
        SourceIdentifier: RDS_INSTANCE_DELETION_PROTECTION_ENABLED
    Type: AWS::Config::ConfigRule
  RdsInstancePublicAccessCheck:
    Properties:
      ConfigRuleName: rds-instance-public-access-check
      Scope:
        ComplianceResourceTypes:
        - AWS::RDS::DBInstance
      Source:
        Owner: AWS
        SourceIdentifier: RDS_INSTANCE_PUBLIC_ACCESS_CHECK
    Type: AWS::Config::ConfigRule
  RdsLoggingEnabled:
    Properties:
      ConfigRuleName: rds-logging-enabled
      Scope:
        ComplianceResourceTypes:
        - AWS::RDS::DBInstance
      Source:
        Owner: AWS
        SourceIdentifier: RDS_LOGGING_ENABLED
    Type: AWS::Config::ConfigRule
  RdsMultiAzSupport:
    Properties:
      ConfigRuleName: rds-multi-az-support
      Scope:
        ComplianceResourceTypes:
        - AWS::RDS::DBInstance
      Source:
        Owner: AWS
        SourceIdentifier: RDS_MULTI_AZ_SUPPORT
    Type: AWS::Config::ConfigRule
  RdsSnapshotEncrypted:
    Properties:
      ConfigRuleName: rds-snapshot-encrypted
      Scope:
        ComplianceResourceTypes:
        - AWS::RDS::DBSnapshot
        - AWS::RDS::DBClusterSnapshot
      Source:
        Owner: AWS
        SourceIdentifier: RDS_SNAPSHOT_ENCRYPTED
    Type: AWS::Config::ConfigRule
  RdsSnapshotsPublicProhibited:
    Properties:
      ConfigRuleName: rds-snapshots-public-prohibited
      Scope:
        ComplianceResourceTypes:
        - AWS::RDS::DBSnapshot
        - AWS::RDS::DBClusterSnapshot
      Source:
        Owner: AWS
        SourceIdentifier: RDS_SNAPSHOTS_PUBLIC_PROHIBITED
    Type: AWS::Config::ConfigRule
  RdsStorageEncrypted:
    Properties:
      ConfigRuleName: rds-storage-encrypted
      Scope:
        ComplianceResourceTypes:
        - AWS::RDS::DBInstance
      Source:
        Owner: AWS
        SourceIdentifier: RDS_STORAGE_ENCRYPTED
    Type: AWS::Config::ConfigRule
  RedshiftBackupEnabled:
    Properties:
      ConfigRuleName: redshift-backup-enabled
      Scope:
        ComplianceResourceTypes:
        - AWS::Redshift::Cluster
      Source:
        Owner: AWS
        SourceIdentifier: REDSHIFT_BACKUP_ENABLED
    Type: AWS::Config::ConfigRule
  RedshiftClusterConfigurationCheck:
    Properties:
      ConfigRuleName: redshift-cluster-configuration-check
      InputParameters:
        clusterDbEncrypted: 'true'
        loggingEnabled: 'true'
      Scope:
        ComplianceResourceTypes:
        - AWS::Redshift::Cluster
      Source:
        Owner: AWS
        SourceIdentifier: REDSHIFT_CLUSTER_CONFIGURATION_CHECK
    Type: AWS::Config::ConfigRule
  RedshiftClusterKmsEnabled:
    Properties:
      ConfigRuleName: redshift-cluster-kms-enabled
      Scope:
        ComplianceResourceTypes:
        - AWS::Redshift::Cluster
      Source:
        Owner: AWS
        SourceIdentifier: REDSHIFT_CLUSTER_KMS_ENABLED
    Type: AWS::Config::ConfigRule
  RedshiftClusterMaintenancesettingsCheck:
    Properties:
      ConfigRuleName: redshift-cluster-maintenancesettings-check
      InputParameters:
        allowVersionUpgrade:
          Fn::If:
          - redshiftClusterMaintenancesettingsCheckParamAllowVersionUpgrade
          - Ref: RedshiftClusterMaintenancesettingsCheckParamAllowVersionUpgrade
          - Ref: AWS::NoValue
      Scope:
        ComplianceResourceTypes:
        - AWS::Redshift::Cluster
      Source:
        Owner: AWS
        SourceIdentifier: REDSHIFT_CLUSTER_MAINTENANCESETTINGS_CHECK
    Type: AWS::Config::ConfigRule
  RedshiftClusterPublicAccessCheck:
    Properties:
      ConfigRuleName: redshift-cluster-public-access-check
      Scope:
        ComplianceResourceTypes:
        - AWS::Redshift::Cluster
      Source:
        Owner: AWS
        SourceIdentifier: REDSHIFT_CLUSTER_PUBLIC_ACCESS_CHECK
    Type: AWS::Config::ConfigRule
  RedshiftEnhancedVpcRoutingEnabled:
    Properties:
      ConfigRuleName: redshift-enhanced-vpc-routing-enabled
      Scope:
        ComplianceResourceTypes:
        - AWS::Redshift::Cluster
      Source:
        Owner: AWS
        SourceIdentifier: REDSHIFT_ENHANCED_VPC_ROUTING_ENABLED
    Type: AWS::Config::ConfigRule
  RedshiftRequireTlsSsl:
    Properties:
      ConfigRuleName: redshift-require-tls-ssl
      Scope:
        ComplianceResourceTypes:
        - AWS::Redshift::Cluster
      Source:
        Owner: AWS
        SourceIdentifier: REDSHIFT_REQUIRE_TLS_SSL
    Type: AWS::Config::ConfigRule
  RestrictedIncomingTraffic:
    Properties:
      ConfigRuleName: restricted-common-ports
      InputParameters:
        blockedPort1:
          Fn::If:
          - restrictedIncomingTrafficParamBlockedPort1
          - Ref: RestrictedIncomingTrafficParamBlockedPort1
          - Ref: AWS::NoValue
        blockedPort2:
          Fn::If:
          - restrictedIncomingTrafficParamBlockedPort2
          - Ref: RestrictedIncomingTrafficParamBlockedPort2
          - Ref: AWS::NoValue
        blockedPort3:
          Fn::If:
          - restrictedIncomingTrafficParamBlockedPort3
          - Ref: RestrictedIncomingTrafficParamBlockedPort3
          - Ref: AWS::NoValue
        blockedPort4:
          Fn::If:
          - restrictedIncomingTrafficParamBlockedPort4
          - Ref: RestrictedIncomingTrafficParamBlockedPort4
          - Ref: AWS::NoValue
        blockedPort5:
          Fn::If:
          - restrictedIncomingTrafficParamBlockedPort5
          - Ref: RestrictedIncomingTrafficParamBlockedPort5
          - Ref: AWS::NoValue
      Scope:
        ComplianceResourceTypes:
        - AWS::EC2::SecurityGroup
      Source:
        Owner: AWS
        SourceIdentifier: RESTRICTED_INCOMING_TRAFFIC
    Type: AWS::Config::ConfigRule
  RootAccountHardwareMfaEnabled:
    Properties:
      ConfigRuleName: root-account-hardware-mfa-enabled
      Source:
        Owner: AWS
        SourceIdentifier: ROOT_ACCOUNT_HARDWARE_MFA_ENABLED
    Type: AWS::Config::ConfigRule
  RootAccountMfaEnabled:
    Properties:
      ConfigRuleName: root-account-mfa-enabled
      Source:
        Owner: AWS
        SourceIdentifier: ROOT_ACCOUNT_MFA_ENABLED
    Type: AWS::Config::ConfigRule
  S3AccountLevelPublicAccessBlocksPeriodic:
    Properties:
      ConfigRuleName: s3-account-level-public-access-blocks-periodic
      Source:
        Owner: AWS
        SourceIdentifier: S3_ACCOUNT_LEVEL_PUBLIC_ACCESS_BLOCKS_PERIODIC
    Type: AWS::Config::ConfigRule
  S3BucketLevelPublicAccessProhibited:
    Properties:
      ConfigRuleName: s3-bucket-level-public-access-prohibited
      Scope:
        ComplianceResourceTypes:
        - AWS::S3::Bucket
      Source:
        Owner: AWS
        SourceIdentifier: S3_BUCKET_LEVEL_PUBLIC_ACCESS_PROHIBITED
    Type: AWS::Config::ConfigRule
  S3BucketLoggingEnabled:
    Properties:
      ConfigRuleName: s3-bucket-logging-enabled
      Scope:
        ComplianceResourceTypes:
        - AWS::S3::Bucket
      Source:
        Owner: AWS
        SourceIdentifier: S3_BUCKET_LOGGING_ENABLED
    Type: AWS::Config::ConfigRule
  S3BucketPublicReadProhibited:
    Properties:
      ConfigRuleName: s3-bucket-public-read-prohibited
      Scope:
        ComplianceResourceTypes:
        - AWS::S3::Bucket
      Source:
        Owner: AWS
        SourceIdentifier: S3_BUCKET_PUBLIC_READ_PROHIBITED
    Type: AWS::Config::ConfigRule
  S3BucketPublicWriteProhibited:
    Properties:
      ConfigRuleName: s3-bucket-public-write-prohibited
      Scope:
        ComplianceResourceTypes:
        - AWS::S3::Bucket
      Source:
        Owner: AWS
        SourceIdentifier: S3_BUCKET_PUBLIC_WRITE_PROHIBITED
    Type: AWS::Config::ConfigRule
  S3BucketReplicationEnabled:
    Properties:
      ConfigRuleName: s3-bucket-replication-enabled
      Scope:
        ComplianceResourceTypes:
        - AWS::S3::Bucket
      Source:
        Owner: AWS
        SourceIdentifier: S3_BUCKET_REPLICATION_ENABLED
    Type: AWS::Config::ConfigRule
  S3BucketServerSideEncryptionEnabled:
    Properties:
      ConfigRuleName: s3-bucket-server-side-encryption-enabled
      Scope:
        ComplianceResourceTypes:
        - AWS::S3::Bucket
      Source:
        Owner: AWS
        SourceIdentifier: S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED
    Type: AWS::Config::ConfigRule
  S3BucketSslRequestsOnly:
    Properties:
      ConfigRuleName: s3-bucket-ssl-requests-only
      Scope:
        ComplianceResourceTypes:
        - AWS::S3::Bucket
      Source:
        Owner: AWS
        SourceIdentifier: S3_BUCKET_SSL_REQUESTS_ONLY
    Type: AWS::Config::ConfigRule
  S3BucketVersioningEnabled:
    Properties:
      ConfigRuleName: s3-bucket-versioning-enabled
      Scope:
        ComplianceResourceTypes:
        - AWS::S3::Bucket
      Source:
        Owner: AWS
        SourceIdentifier: S3_BUCKET_VERSIONING_ENABLED
    Type: AWS::Config::ConfigRule
  S3DefaultEncryptionKms:
    Properties:
      ConfigRuleName: s3-default-encryption-kms
      Scope:
        ComplianceResourceTypes:
        - AWS::S3::Bucket
      Source:
        Owner: AWS
        SourceIdentifier: S3_DEFAULT_ENCRYPTION_KMS
    Type: AWS::Config::ConfigRule
  SagemakerEndpointConfigurationKmsKeyConfigured:
    Properties:
      ConfigRuleName: sagemaker-endpoint-configuration-kms-key-configured
      Source:
        Owner: AWS
        SourceIdentifier: SAGEMAKER_ENDPOINT_CONFIGURATION_KMS_KEY_CONFIGURED
    Type: AWS::Config::ConfigRule
  SagemakerNotebookInstanceKmsKeyConfigured:
    Properties:
      ConfigRuleName: sagemaker-notebook-instance-kms-key-configured
      Source:
        Owner: AWS
        SourceIdentifier: SAGEMAKER_NOTEBOOK_INSTANCE_KMS_KEY_CONFIGURED
    Type: AWS::Config::ConfigRule
  SagemakerNotebookNoDirectInternetAccess:
    Properties:
      ConfigRuleName: sagemaker-notebook-no-direct-internet-access
      Source:
        Owner: AWS
        SourceIdentifier: SAGEMAKER_NOTEBOOK_NO_DIRECT_INTERNET_ACCESS
    Type: AWS::Config::ConfigRule
  SecretsmanagerRotationEnabledCheck:
    Properties:
      ConfigRuleName: secretsmanager-rotation-enabled-check
      Scope:
        ComplianceResourceTypes:
        - AWS::SecretsManager::Secret
      Source:
        Owner: AWS
        SourceIdentifier: SECRETSMANAGER_ROTATION_ENABLED_CHECK
    Type: AWS::Config::ConfigRule
  SecurityhubEnabled:
    Properties:
      ConfigRuleName: securityhub-enabled
      Source:
        Owner: AWS
        SourceIdentifier: SECURITYHUB_ENABLED
    Type: AWS::Config::ConfigRule
  SsmDocumentNotPublic:
    Properties:
      ConfigRuleName: ssm-document-not-public
      Source:
        Owner: AWS
        SourceIdentifier: SSM_DOCUMENT_NOT_PUBLIC
    Type: AWS::Config::ConfigRule
  SubnetAutoAssignPublicIpDisabled:
    Properties:
      ConfigRuleName: subnet-auto-assign-public-ip-disabled
      Scope:
        ComplianceResourceTypes:
        - AWS::EC2::Subnet
      Source:
        Owner: AWS
        SourceIdentifier: SUBNET_AUTO_ASSIGN_PUBLIC_IP_DISABLED
    Type: AWS::Config::ConfigRule
  VpcDefaultSecurityGroupClosed:
    Properties:
      ConfigRuleName: vpc-default-security-group-closed
      Scope:
        ComplianceResourceTypes:
        - AWS::EC2::SecurityGroup
      Source:
        Owner: AWS
        SourceIdentifier: VPC_DEFAULT_SECURITY_GROUP_CLOSED
    Type: AWS::Config::ConfigRule
  VpcFlowLogsEnabled:
    Properties:
      ConfigRuleName: vpc-flow-logs-enabled
      Source:
        Owner: AWS
        SourceIdentifier: VPC_FLOW_LOGS_ENABLED
    Type: AWS::Config::ConfigRule
  VpcSgOpenOnlyToAuthorizedPorts:
    Properties:
      ConfigRuleName: vpc-sg-open-only-to-authorized-ports
      InputParameters:
        authorizedTcpPorts:
          Fn::If:
          - vpcSgOpenOnlyToAuthorizedPortsParamAuthorizedTcpPorts
          - Ref: VpcSgOpenOnlyToAuthorizedPortsParamAuthorizedTcpPorts
          - Ref: AWS::NoValue
      Scope:
        ComplianceResourceTypes:
        - AWS::EC2::SecurityGroup
      Source:
        Owner: AWS
        SourceIdentifier: VPC_SG_OPEN_ONLY_TO_AUTHORIZED_PORTS
    Type: AWS::Config::ConfigRule
  VpcVpn2TunnelsUp:
    Properties:
      ConfigRuleName: vpc-vpn-2-tunnels-up
      Scope:
        ComplianceResourceTypes:
        - AWS::EC2::VPNConnection
      Source:
        Owner: AWS
        SourceIdentifier: VPC_VPN_2_TUNNELS_UP
    Type: AWS::Config::ConfigRule
  Wafv2LoggingEnabled:
    Properties:
      ConfigRuleName: wafv2-logging-enabled
      Source:
        Owner: AWS
        SourceIdentifier: WAFV2_LOGGING_ENABLED
    Type: AWS::Config::ConfigRule
  ResponsePlanExistsMaintained:
    Properties:
      ConfigRuleName: response-plan-exists-maintained
      Description: Ensure incident response plans are established, maintained, and distributed to responsible personnel.
      Source:
        Owner: AWS
        SourceIdentifier: AWS_CONFIG_PROCESS_CHECK
    Type: AWS::Config::ConfigRule
  AnnualRiskAssessmentPerformed:
    Properties:
      ConfigRuleName: annual-risk-assessment-performed
      Description: Perform an annual risk assessment on your organization. Risk assessments can assist in determining the likelihood and impact of identified risks and/or vulnerabilities affecting an organization.
      Source:
        Owner: AWS
        SourceIdentifier: AWS_CONFIG_PROCESS_CHECK
    Type: AWS::Config::ConfigRule
Conditions:
  accessKeysRotatedParamMaxAccessKeyAge:
    Fn::Not:
    - Fn::Equals:
      - ''
      - Ref: AccessKeysRotatedParamMaxAccessKeyAge
  acmCertificateExpirationCheckParamDaysToExpiration:
    Fn::Not:
    - Fn::Equals:
      - ''
      - Ref: AcmCertificateExpirationCheckParamDaysToExpiration
  backupPlanMinFrequencyAndMinRetentionCheckParamRequiredFrequencyUnit:
    Fn::Not:
    - Fn::Equals:
      - ''
      - Ref: BackupPlanMinFrequencyAndMinRetentionCheckParamRequiredFrequencyUnit
  backupPlanMinFrequencyAndMinRetentionCheckParamRequiredFrequencyValue:
    Fn::Not:
    - Fn::Equals:
      - ''
      - Ref: BackupPlanMinFrequencyAndMinRetentionCheckParamRequiredFrequencyValue
  backupPlanMinFrequencyAndMinRetentionCheckParamRequiredRetentionDays:
    Fn::Not:
    - Fn::Equals:
      - ''
      - Ref: BackupPlanMinFrequencyAndMinRetentionCheckParamRequiredRetentionDays
  dynamodbThroughputLimitCheckParamAccountRCUThresholdPercentage:
    Fn::Not:
    - Fn::Equals:
      - ''
      - Ref: DynamodbThroughputLimitCheckParamAccountRCUThresholdPercentage
  dynamodbThroughputLimitCheckParamAccountWCUThresholdPercentage:
    Fn::Not:
    - Fn::Equals:
      - ''
      - Ref: DynamodbThroughputLimitCheckParamAccountWCUThresholdPercentage
  ec2VolumeInuseCheckParamDeleteOnTermination:
    Fn::Not:
    - Fn::Equals:
      - ''
      - Ref: Ec2VolumeInuseCheckParamDeleteOnTermination
  iamCustomerPolicyBlockedKmsActionsParamBlockedActionsPatterns:
    Fn::Not:
    - Fn::Equals:
      - ''
      - Ref: IamCustomerPolicyBlockedKmsActionsParamBlockedActionsPatterns
  iamInlinePolicyBlockedKmsActionsParamBlockedActionsPatterns:
    Fn::Not:
    - Fn::Equals:
      - ''
      - Ref: IamInlinePolicyBlockedKmsActionsParamBlockedActionsPatterns
  iamPasswordPolicyParamMaxPasswordAge:
    Fn::Not:
    - Fn::Equals:
      - ''
      - Ref: IamPasswordPolicyParamMaxPasswordAge
  iamPasswordPolicyParamMinimumPasswordLength:
    Fn::Not:
    - Fn::Equals:
      - ''
      - Ref: IamPasswordPolicyParamMinimumPasswordLength
  iamPasswordPolicyParamPasswordReusePrevention:
    Fn::Not:
    - Fn::Equals:
      - ''
      - Ref: IamPasswordPolicyParamPasswordReusePrevention
  iamPasswordPolicyParamRequireLowercaseCharacters:
    Fn::Not:
    - Fn::Equals:
      - ''
      - Ref: IamPasswordPolicyParamRequireLowercaseCharacters
  iamPasswordPolicyParamRequireNumbers:
    Fn::Not:
    - Fn::Equals:
      - ''
      - Ref: IamPasswordPolicyParamRequireNumbers
  iamPasswordPolicyParamRequireSymbols:
    Fn::Not:
    - Fn::Equals:
      - ''
      - Ref: IamPasswordPolicyParamRequireSymbols
  iamPasswordPolicyParamRequireUppercaseCharacters:
    Fn::Not:
    - Fn::Equals:
      - ''
      - Ref: IamPasswordPolicyParamRequireUppercaseCharacters
  iamUserUnusedCredentialsCheckParamMaxCredentialUsageAge:
    Fn::Not:
    - Fn::Equals:
      - ''
      - Ref: IamUserUnusedCredentialsCheckParamMaxCredentialUsageAge
  lambdaConcurrencyCheckParamConcurrencyLimitHigh:
    Fn::Not:
    - Fn::Equals:
      - ''
      - Ref: LambdaConcurrencyCheckParamConcurrencyLimitHigh
  lambdaConcurrencyCheckParamConcurrencyLimitLow:
    Fn::Not:
    - Fn::Equals:
      - ''
      - Ref: LambdaConcurrencyCheckParamConcurrencyLimitLow
  redshiftClusterMaintenancesettingsCheckParamAllowVersionUpgrade:
    Fn::Not:
    - Fn::Equals:
      - ''
      - Ref: RedshiftClusterMaintenancesettingsCheckParamAllowVersionUpgrade
  restrictedIncomingTrafficParamBlockedPort1:
    Fn::Not:
    - Fn::Equals:
      - ''
      - Ref: RestrictedIncomingTrafficParamBlockedPort1
  restrictedIncomingTrafficParamBlockedPort2:
    Fn::Not:
    - Fn::Equals:
      - ''
      - Ref: RestrictedIncomingTrafficParamBlockedPort2
  restrictedIncomingTrafficParamBlockedPort3:
    Fn::Not:
    - Fn::Equals:
      - ''
      - Ref: RestrictedIncomingTrafficParamBlockedPort3
  restrictedIncomingTrafficParamBlockedPort4:
    Fn::Not:
    - Fn::Equals:
      - ''
      - Ref: RestrictedIncomingTrafficParamBlockedPort4
  restrictedIncomingTrafficParamBlockedPort5:
    Fn::Not:
    - Fn::Equals:
      - ''
      - Ref: RestrictedIncomingTrafficParamBlockedPort5
  vpcSgOpenOnlyToAuthorizedPortsParamAuthorizedTcpPorts:
    Fn::Not:
    - Fn::Equals:
      - ''
      - Ref: VpcSgOpenOnlyToAuthorizedPortsParamAuthorizedTcpPorts


  EOT
}


# resource "aws_config_conformance_pack" "nist" {
#   name = ""
#   depends_on = [aws_config_configuration_recorder.socialjar]

#   template_body = <<EOT
#     Parameters:
#   AccessKeysRotatedParamMaxAccessKeyAge:
#     Default: '90'
#     Type: String
#   AcmCertificateExpirationCheckParamDaysToExpiration:
#     Default: '90'
#     Type: String
#   BackupPlanMinFrequencyAndMinRetentionCheckParamRequiredFrequencyUnit:
#     Default: days
#     Type: String
#   BackupPlanMinFrequencyAndMinRetentionCheckParamRequiredFrequencyValue:
#     Default: '1'
#     Type: String
#   BackupPlanMinFrequencyAndMinRetentionCheckParamRequiredRetentionDays:
#     Default: '35'
#     Type: String
#   DynamodbThroughputLimitCheckParamAccountRCUThresholdPercentage:
#     Default: '80'
#     Type: String
#   DynamodbThroughputLimitCheckParamAccountWCUThresholdPercentage:
#     Default: '80'
#     Type: String
#   Ec2VolumeInuseCheckParamDeleteOnTermination:
#     Default: 'true'
#     Type: String
#   IamCustomerPolicyBlockedKmsActionsParamBlockedActionsPatterns:
#     Default: kms:Decrypt,kms:ReEncryptFrom
#     Type: String
#   IamInlinePolicyBlockedKmsActionsParamBlockedActionsPatterns:
#     Default: kms:Decrypt,kms:ReEncryptFrom
#     Type: String
#   IamPasswordPolicyParamMaxPasswordAge:
#     Default: '90'
#     Type: String
#   IamPasswordPolicyParamMinimumPasswordLength:
#     Default: '14'
#     Type: String
#   IamPasswordPolicyParamPasswordReusePrevention:
#     Default: '24'
#     Type: String
#   IamPasswordPolicyParamRequireLowercaseCharacters:
#     Default: 'true'
#     Type: String
#   IamPasswordPolicyParamRequireNumbers:
#     Default: 'true'
#     Type: String
#   IamPasswordPolicyParamRequireSymbols:
#     Default: 'true'
#     Type: String
#   IamPasswordPolicyParamRequireUppercaseCharacters:
#     Default: 'true'
#     Type: String
#   IamUserUnusedCredentialsCheckParamMaxCredentialUsageAge:
#     Default: '90'
#     Type: String
#   LambdaConcurrencyCheckParamConcurrencyLimitHigh:
#     Default: '1000'
#     Type: String
#   LambdaConcurrencyCheckParamConcurrencyLimitLow:
#     Default: '500'
#     Type: String
#   RedshiftClusterMaintenancesettingsCheckParamAllowVersionUpgrade:
#     Default: 'true'
#     Type: String
#   RestrictedIncomingTrafficParamBlockedPort1:
#     Default: '20'
#     Type: String
#   RestrictedIncomingTrafficParamBlockedPort2:
#     Default: '21'
#     Type: String
#   RestrictedIncomingTrafficParamBlockedPort3:
#     Default: '3389'
#     Type: String
#   RestrictedIncomingTrafficParamBlockedPort4:
#     Default: '3306'
#     Type: String
#   RestrictedIncomingTrafficParamBlockedPort5:
#     Default: '4333'
#     Type: String
#   VpcSgOpenOnlyToAuthorizedPortsParamAuthorizedTcpPorts:
#     Default: '443'
#     Type: String
# Resources:
#   AccessKeysRotated:
#     Properties:
#       ConfigRuleName: access-keys-rotated
#       InputParameters:
#         maxAccessKeyAge:
#           Fn::If:
#           - accessKeysRotatedParamMaxAccessKeyAge
#           - Ref: AccessKeysRotatedParamMaxAccessKeyAge
#           - Ref: AWS::NoValue
#       Source:
#         Owner: AWS
#         SourceIdentifier: ACCESS_KEYS_ROTATED
#     Type: AWS::Config::ConfigRule
#   AccountPartOfOrganizations:
#     Properties:
#       ConfigRuleName: account-part-of-organizations
#       Source:
#         Owner: AWS
#         SourceIdentifier: ACCOUNT_PART_OF_ORGANIZATIONS
#     Type: AWS::Config::ConfigRule
#   AcmCertificateExpirationCheck:
#     Properties:
#       ConfigRuleName: acm-certificate-expiration-check
#       InputParameters:
#         daysToExpiration:
#           Fn::If:
#           - acmCertificateExpirationCheckParamDaysToExpiration
#           - Ref: AcmCertificateExpirationCheckParamDaysToExpiration
#           - Ref: AWS::NoValue
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::ACM::Certificate
#       Source:
#         Owner: AWS
#         SourceIdentifier: ACM_CERTIFICATE_EXPIRATION_CHECK
#     Type: AWS::Config::ConfigRule
#   AlbHttpToHttpsRedirectionCheck:
#     Properties:
#       ConfigRuleName: alb-http-to-https-redirection-check
#       Source:
#         Owner: AWS
#         SourceIdentifier: ALB_HTTP_TO_HTTPS_REDIRECTION_CHECK
#     Type: AWS::Config::ConfigRule
#   AlbWafEnabled:
#     Properties:
#       ConfigRuleName: alb-waf-enabled
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::ElasticLoadBalancingV2::LoadBalancer
#       Source:
#         Owner: AWS
#         SourceIdentifier: ALB_WAF_ENABLED
#     Type: AWS::Config::ConfigRule
#   ApiGwAssociatedWithWaf:
#     Properties:
#       ConfigRuleName: api-gw-associated-with-waf
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::ApiGateway::Stage
#       Source:
#         Owner: AWS
#         SourceIdentifier: API_GW_ASSOCIATED_WITH_WAF
#     Type: AWS::Config::ConfigRule
#   ApiGwCacheEnabledAndEncrypted:
#     Properties:
#       ConfigRuleName: api-gw-cache-enabled-and-encrypted
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::ApiGateway::Stage
#       Source:
#         Owner: AWS
#         SourceIdentifier: API_GW_CACHE_ENABLED_AND_ENCRYPTED
#     Type: AWS::Config::ConfigRule
#   ApiGwExecutionLoggingEnabled:
#     Properties:
#       ConfigRuleName: api-gw-execution-logging-enabled
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::ApiGateway::Stage
#         - AWS::ApiGatewayV2::Stage
#       Source:
#         Owner: AWS
#         SourceIdentifier: API_GW_EXECUTION_LOGGING_ENABLED
#     Type: AWS::Config::ConfigRule
#   ApiGwSslEnabled:
#     Properties:
#       ConfigRuleName: api-gw-ssl-enabled
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::ApiGateway::Stage
#       Source:
#         Owner: AWS
#         SourceIdentifier: API_GW_SSL_ENABLED
#     Type: AWS::Config::ConfigRule
#   AutoscalingGroupElbHealthcheckRequired:
#     Properties:
#       ConfigRuleName: autoscaling-group-elb-healthcheck-required
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::AutoScaling::AutoScalingGroup
#       Source:
#         Owner: AWS
#         SourceIdentifier: AUTOSCALING_GROUP_ELB_HEALTHCHECK_REQUIRED
#     Type: AWS::Config::ConfigRule
#   AutoscalingLaunchConfigPublicIpDisabled:
#     Properties:
#       ConfigRuleName: autoscaling-launch-config-public-ip-disabled
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::AutoScaling::LaunchConfiguration
#       Source:
#         Owner: AWS
#         SourceIdentifier: AUTOSCALING_LAUNCH_CONFIG_PUBLIC_IP_DISABLED
#     Type: AWS::Config::ConfigRule
#   BackupPlanMinFrequencyAndMinRetentionCheck:
#     Properties:
#       ConfigRuleName: backup-plan-min-frequency-and-min-retention-check
#       InputParameters:
#         requiredFrequencyUnit:
#           Fn::If:
#           - backupPlanMinFrequencyAndMinRetentionCheckParamRequiredFrequencyUnit
#           - Ref: BackupPlanMinFrequencyAndMinRetentionCheckParamRequiredFrequencyUnit
#           - Ref: AWS::NoValue
#         requiredFrequencyValue:
#           Fn::If:
#           - backupPlanMinFrequencyAndMinRetentionCheckParamRequiredFrequencyValue
#           - Ref: BackupPlanMinFrequencyAndMinRetentionCheckParamRequiredFrequencyValue
#           - Ref: AWS::NoValue
#         requiredRetentionDays:
#           Fn::If:
#           - backupPlanMinFrequencyAndMinRetentionCheckParamRequiredRetentionDays
#           - Ref: BackupPlanMinFrequencyAndMinRetentionCheckParamRequiredRetentionDays
#           - Ref: AWS::NoValue
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::Backup::BackupPlan
#       Source:
#         Owner: AWS
#         SourceIdentifier: BACKUP_PLAN_MIN_FREQUENCY_AND_MIN_RETENTION_CHECK
#     Type: AWS::Config::ConfigRule
#   BackupRecoveryPointEncrypted:
#     Properties:
#       ConfigRuleName: backup-recovery-point-encrypted
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::Backup::RecoveryPoint
#       Source:
#         Owner: AWS
#         SourceIdentifier: BACKUP_RECOVERY_POINT_ENCRYPTED
#     Type: AWS::Config::ConfigRule
#   BackupRecoveryPointManualDeletionDisabled:
#     Properties:
#       ConfigRuleName: backup-recovery-point-manual-deletion-disabled
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::Backup::BackupVault
#       Source:
#         Owner: AWS
#         SourceIdentifier: BACKUP_RECOVERY_POINT_MANUAL_DELETION_DISABLED
#     Type: AWS::Config::ConfigRule
#   BeanstalkEnhancedHealthReportingEnabled:
#     Properties:
#       ConfigRuleName: beanstalk-enhanced-health-reporting-enabled
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::ElasticBeanstalk::Environment
#       Source:
#         Owner: AWS
#         SourceIdentifier: BEANSTALK_ENHANCED_HEALTH_REPORTING_ENABLED
#     Type: AWS::Config::ConfigRule
#   CloudTrailCloudWatchLogsEnabled:
#     Properties:
#       ConfigRuleName: cloud-trail-cloud-watch-logs-enabled
#       Source:
#         Owner: AWS
#         SourceIdentifier: CLOUD_TRAIL_CLOUD_WATCH_LOGS_ENABLED
#     Type: AWS::Config::ConfigRule
#   CloudTrailEnabled:
#     Properties:
#       ConfigRuleName: cloudtrail-enabled
#       Source:
#         Owner: AWS
#         SourceIdentifier: CLOUD_TRAIL_ENABLED
#     Type: AWS::Config::ConfigRule
#   CloudTrailEncryptionEnabled:
#     Properties:
#       ConfigRuleName: cloud-trail-encryption-enabled
#       Source:
#         Owner: AWS
#         SourceIdentifier: CLOUD_TRAIL_ENCRYPTION_ENABLED
#     Type: AWS::Config::ConfigRule
#   CloudTrailLogFileValidationEnabled:
#     Properties:
#       ConfigRuleName: cloud-trail-log-file-validation-enabled
#       Source:
#         Owner: AWS
#         SourceIdentifier: CLOUD_TRAIL_LOG_FILE_VALIDATION_ENABLED
#     Type: AWS::Config::ConfigRule
#   CloudtrailS3DataeventsEnabled:
#     Properties:
#       ConfigRuleName: cloudtrail-s3-dataevents-enabled
#       Source:
#         Owner: AWS
#         SourceIdentifier: CLOUDTRAIL_S3_DATAEVENTS_ENABLED
#     Type: AWS::Config::ConfigRule
#   CloudwatchAlarmActionCheck:
#     Properties:
#       ConfigRuleName: cloudwatch-alarm-action-check
#       InputParameters:
#         alarmActionRequired: 'true'
#         insufficientDataActionRequired: 'true'
#         okActionRequired: 'false'
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::CloudWatch::Alarm
#       Source:
#         Owner: AWS
#         SourceIdentifier: CLOUDWATCH_ALARM_ACTION_CHECK
#     Type: AWS::Config::ConfigRule
#   CmkBackingKeyRotationEnabled:
#     Properties:
#       ConfigRuleName: cmk-backing-key-rotation-enabled
#       Source:
#         Owner: AWS
#         SourceIdentifier: CMK_BACKING_KEY_ROTATION_ENABLED
#     Type: AWS::Config::ConfigRule
#   CodebuildProjectEnvvarAwscredCheck:
#     Properties:
#       ConfigRuleName: codebuild-project-envvar-awscred-check
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::CodeBuild::Project
#       Source:
#         Owner: AWS
#         SourceIdentifier: CODEBUILD_PROJECT_ENVVAR_AWSCRED_CHECK
#     Type: AWS::Config::ConfigRule
#   CodebuildProjectSourceRepoUrlCheck:
#     Properties:
#       ConfigRuleName: codebuild-project-source-repo-url-check
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::CodeBuild::Project
#       Source:
#         Owner: AWS
#         SourceIdentifier: CODEBUILD_PROJECT_SOURCE_REPO_URL_CHECK
#     Type: AWS::Config::ConfigRule
#   CwLoggroupRetentionPeriodCheck:
#     Properties:
#       ConfigRuleName: cw-loggroup-retention-period-check
#       Source:
#         Owner: AWS
#         SourceIdentifier: CW_LOGGROUP_RETENTION_PERIOD_CHECK
#     Type: AWS::Config::ConfigRule
#   DbInstanceBackupEnabled:
#     Properties:
#       ConfigRuleName: db-instance-backup-enabled
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::RDS::DBInstance
#       Source:
#         Owner: AWS
#         SourceIdentifier: DB_INSTANCE_BACKUP_ENABLED
#     Type: AWS::Config::ConfigRule
#   DmsReplicationNotPublic:
#     Properties:
#       ConfigRuleName: dms-replication-not-public
#       Scope:
#         ComplianceResourceTypes: []
#       Source:
#         Owner: AWS
#         SourceIdentifier: DMS_REPLICATION_NOT_PUBLIC
#     Type: AWS::Config::ConfigRule
#   DynamodbAutoscalingEnabled:
#     Properties:
#       ConfigRuleName: dynamodb-autoscaling-enabled
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::DynamoDB::Table
#       Source:
#         Owner: AWS
#         SourceIdentifier: DYNAMODB_AUTOSCALING_ENABLED
#     Type: AWS::Config::ConfigRule
#   DynamodbInBackupPlan:
#     Properties:
#       ConfigRuleName: dynamodb-in-backup-plan
#       Source:
#         Owner: AWS
#         SourceIdentifier: DYNAMODB_IN_BACKUP_PLAN
#     Type: AWS::Config::ConfigRule
#   DynamodbPitrEnabled:
#     Properties:
#       ConfigRuleName: dynamodb-pitr-enabled
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::DynamoDB::Table
#       Source:
#         Owner: AWS
#         SourceIdentifier: DYNAMODB_PITR_ENABLED
#     Type: AWS::Config::ConfigRule
#   DynamodbResourcesProtectedByBackupPlan:
#     Properties:
#       ConfigRuleName: dynamodb-resources-protected-by-backup-plan
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::DynamoDB::Table
#       Source:
#         Owner: AWS
#         SourceIdentifier: DYNAMODB_RESOURCES_PROTECTED_BY_BACKUP_PLAN
#     Type: AWS::Config::ConfigRule
#   DynamodbThroughputLimitCheck:
#     Properties:
#       ConfigRuleName: dynamodb-throughput-limit-check
#       InputParameters:
#         accountRCUThresholdPercentage:
#           Fn::If:
#           - dynamodbThroughputLimitCheckParamAccountRCUThresholdPercentage
#           - Ref: DynamodbThroughputLimitCheckParamAccountRCUThresholdPercentage
#           - Ref: AWS::NoValue
#         accountWCUThresholdPercentage:
#           Fn::If:
#           - dynamodbThroughputLimitCheckParamAccountWCUThresholdPercentage
#           - Ref: DynamodbThroughputLimitCheckParamAccountWCUThresholdPercentage
#           - Ref: AWS::NoValue
#       Source:
#         Owner: AWS
#         SourceIdentifier: DYNAMODB_THROUGHPUT_LIMIT_CHECK
#     Type: AWS::Config::ConfigRule
#   EbsInBackupPlan:
#     Properties:
#       ConfigRuleName: ebs-in-backup-plan
#       Source:
#         Owner: AWS
#         SourceIdentifier: EBS_IN_BACKUP_PLAN
#     Type: AWS::Config::ConfigRule
#   EbsSnapshotPublicRestorableCheck:
#     Properties:
#       ConfigRuleName: ebs-snapshot-public-restorable-check
#       Source:
#         Owner: AWS
#         SourceIdentifier: EBS_SNAPSHOT_PUBLIC_RESTORABLE_CHECK
#     Type: AWS::Config::ConfigRule
#   Ec2EbsEncryptionByDefault:
#     Properties:
#       ConfigRuleName: ec2-ebs-encryption-by-default
#       Source:
#         Owner: AWS
#         SourceIdentifier: EC2_EBS_ENCRYPTION_BY_DEFAULT
#     Type: AWS::Config::ConfigRule
#   Ec2InstanceDetailedMonitoringEnabled:
#     Properties:
#       ConfigRuleName: ec2-instance-detailed-monitoring-enabled
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::EC2::Instance
#       Source:
#         Owner: AWS
#         SourceIdentifier: EC2_INSTANCE_DETAILED_MONITORING_ENABLED
#     Type: AWS::Config::ConfigRule
#   Ec2InstanceManagedBySsm:
#     Properties:
#       ConfigRuleName: ec2-instance-managed-by-systems-manager
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::EC2::Instance
#         - AWS::SSM::ManagedInstanceInventory
#       Source:
#         Owner: AWS
#         SourceIdentifier: EC2_INSTANCE_MANAGED_BY_SSM
#     Type: AWS::Config::ConfigRule
#   Ec2InstanceNoPublicIp:
#     Properties:
#       ConfigRuleName: ec2-instance-no-public-ip
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::EC2::Instance
#       Source:
#         Owner: AWS
#         SourceIdentifier: EC2_INSTANCE_NO_PUBLIC_IP
#     Type: AWS::Config::ConfigRule
#   Ec2InstanceProfileAttached:
#     Properties:
#       ConfigRuleName: ec2-instance-profile-attached
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::EC2::Instance
#       Source:
#         Owner: AWS
#         SourceIdentifier: EC2_INSTANCE_PROFILE_ATTACHED
#     Type: AWS::Config::ConfigRule
#   Ec2ManagedinstanceAssociationComplianceStatusCheck:
#     Properties:
#       ConfigRuleName: ec2-managedinstance-association-compliance-status-check
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::SSM::AssociationCompliance
#       Source:
#         Owner: AWS
#         SourceIdentifier: EC2_MANAGEDINSTANCE_ASSOCIATION_COMPLIANCE_STATUS_CHECK
#     Type: AWS::Config::ConfigRule
#   Ec2ManagedinstancePatchComplianceStatusCheck:
#     Properties:
#       ConfigRuleName: ec2-managedinstance-patch-compliance-status-check
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::SSM::PatchCompliance
#       Source:
#         Owner: AWS
#         SourceIdentifier: EC2_MANAGEDINSTANCE_PATCH_COMPLIANCE_STATUS_CHECK
#     Type: AWS::Config::ConfigRule
#   Ec2ResourcesProtectedByBackupPlan:
#     Properties:
#       ConfigRuleName: ec2-resources-protected-by-backup-plan
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::EC2::Instance
#       Source:
#         Owner: AWS
#         SourceIdentifier: EC2_RESOURCES_PROTECTED_BY_BACKUP_PLAN
#     Type: AWS::Config::ConfigRule
#   Ec2StoppedInstance:
#     Properties:
#       ConfigRuleName: ec2-stopped-instance
#       Source:
#         Owner: AWS
#         SourceIdentifier: EC2_STOPPED_INSTANCE
#     Type: AWS::Config::ConfigRule
#   Ec2VolumeInuseCheck:
#     Properties:
#       ConfigRuleName: ec2-volume-inuse-check
#       InputParameters:
#         deleteOnTermination:
#           Fn::If:
#           - ec2VolumeInuseCheckParamDeleteOnTermination
#           - Ref: Ec2VolumeInuseCheckParamDeleteOnTermination
#           - Ref: AWS::NoValue
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::EC2::Volume
#       Source:
#         Owner: AWS
#         SourceIdentifier: EC2_VOLUME_INUSE_CHECK
#     Type: AWS::Config::ConfigRule
#   EcsTaskDefinitionUserForHostModeCheck:
#     Properties:
#       ConfigRuleName: ecs-task-definition-user-for-host-mode-check
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::ECS::TaskDefinition
#       Source:
#         Owner: AWS
#         SourceIdentifier: ECS_TASK_DEFINITION_USER_FOR_HOST_MODE_CHECK
#     Type: AWS::Config::ConfigRule
#   EfsEncryptedCheck:
#     Properties:
#       ConfigRuleName: efs-encrypted-check
#       Source:
#         Owner: AWS
#         SourceIdentifier: EFS_ENCRYPTED_CHECK
#     Type: AWS::Config::ConfigRule
#   EfsInBackupPlan:
#     Properties:
#       ConfigRuleName: efs-in-backup-plan
#       Source:
#         Owner: AWS
#         SourceIdentifier: EFS_IN_BACKUP_PLAN
#     Type: AWS::Config::ConfigRule
#   ElasticBeanstalkManagedUpdatesEnabled:
#     Properties:
#       ConfigRuleName: elastic-beanstalk-managed-updates-enabled
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::ElasticBeanstalk::Environment
#       Source:
#         Owner: AWS
#         SourceIdentifier: ELASTIC_BEANSTALK_MANAGED_UPDATES_ENABLED
#     Type: AWS::Config::ConfigRule
#   ElasticacheRedisClusterAutomaticBackupCheck:
#     Properties:
#       ConfigRuleName: elasticache-redis-cluster-automatic-backup-check
#       Source:
#         Owner: AWS
#         SourceIdentifier: ELASTICACHE_REDIS_CLUSTER_AUTOMATIC_BACKUP_CHECK
#     Type: AWS::Config::ConfigRule
#   ElasticsearchEncryptedAtRest:
#     Properties:
#       ConfigRuleName: elasticsearch-encrypted-at-rest
#       Source:
#         Owner: AWS
#         SourceIdentifier: ELASTICSEARCH_ENCRYPTED_AT_REST
#     Type: AWS::Config::ConfigRule
#   ElasticsearchInVpcOnly:
#     Properties:
#       ConfigRuleName: elasticsearch-in-vpc-only
#       Source:
#         Owner: AWS
#         SourceIdentifier: ELASTICSEARCH_IN_VPC_ONLY
#     Type: AWS::Config::ConfigRule
#   ElasticsearchLogsToCloudwatch:
#     Properties:
#       ConfigRuleName: elasticsearch-logs-to-cloudwatch
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::Elasticsearch::Domain
#       Source:
#         Owner: AWS
#         SourceIdentifier: ELASTICSEARCH_LOGS_TO_CLOUDWATCH
#     Type: AWS::Config::ConfigRule
#   ElasticsearchNodeToNodeEncryptionCheck:
#     Properties:
#       ConfigRuleName: elasticsearch-node-to-node-encryption-check
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::Elasticsearch::Domain
#       Source:
#         Owner: AWS
#         SourceIdentifier: ELASTICSEARCH_NODE_TO_NODE_ENCRYPTION_CHECK
#     Type: AWS::Config::ConfigRule
#   ElbAcmCertificateRequired:
#     Properties:
#       ConfigRuleName: elb-acm-certificate-required
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::ElasticLoadBalancing::LoadBalancer
#       Source:
#         Owner: AWS
#         SourceIdentifier: ELB_ACM_CERTIFICATE_REQUIRED
#     Type: AWS::Config::ConfigRule
#   ElbCrossZoneLoadBalancingEnabled:
#     Properties:
#       ConfigRuleName: elb-cross-zone-load-balancing-enabled
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::ElasticLoadBalancing::LoadBalancer
#       Source:
#         Owner: AWS
#         SourceIdentifier: ELB_CROSS_ZONE_LOAD_BALANCING_ENABLED
#     Type: AWS::Config::ConfigRule
#   ElbDeletionProtectionEnabled:
#     Properties:
#       ConfigRuleName: elb-deletion-protection-enabled
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::ElasticLoadBalancingV2::LoadBalancer
#       Source:
#         Owner: AWS
#         SourceIdentifier: ELB_DELETION_PROTECTION_ENABLED
#     Type: AWS::Config::ConfigRule
#   ElbLoggingEnabled:
#     Properties:
#       ConfigRuleName: elb-logging-enabled
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::ElasticLoadBalancing::LoadBalancer
#         - AWS::ElasticLoadBalancingV2::LoadBalancer
#       Source:
#         Owner: AWS
#         SourceIdentifier: ELB_LOGGING_ENABLED
#     Type: AWS::Config::ConfigRule
#   ElbTlsHttpsListenersOnly:
#     Properties:
#       ConfigRuleName: elb-tls-https-listeners-only
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::ElasticLoadBalancing::LoadBalancer
#       Source:
#         Owner: AWS
#         SourceIdentifier: ELB_TLS_HTTPS_LISTENERS_ONLY
#     Type: AWS::Config::ConfigRule
#   Elbv2AcmCertificateRequired:
#     Properties:
#       ConfigRuleName: elbv2-acm-certificate-required
#       Source:
#         Owner: AWS
#         SourceIdentifier: ELBV2_ACM_CERTIFICATE_REQUIRED
#     Type: AWS::Config::ConfigRule
#   EmrKerberosEnabled:
#     Properties:
#       ConfigRuleName: emr-kerberos-enabled
#       Source:
#         Owner: AWS
#         SourceIdentifier: EMR_KERBEROS_ENABLED
#     Type: AWS::Config::ConfigRule
#   EmrMasterNoPublicIp:
#     Properties:
#       ConfigRuleName: emr-master-no-public-ip
#       Scope:
#         ComplianceResourceTypes: []
#       Source:
#         Owner: AWS
#         SourceIdentifier: EMR_MASTER_NO_PUBLIC_IP
#     Type: AWS::Config::ConfigRule
#   EncryptedVolumes:
#     Properties:
#       ConfigRuleName: encrypted-volumes
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::EC2::Volume
#       Source:
#         Owner: AWS
#         SourceIdentifier: ENCRYPTED_VOLUMES
#     Type: AWS::Config::ConfigRule
#   GuarddutyEnabledCentralized:
#     Properties:
#       ConfigRuleName: guardduty-enabled-centralized
#       Source:
#         Owner: AWS
#         SourceIdentifier: GUARDDUTY_ENABLED_CENTRALIZED
#     Type: AWS::Config::ConfigRule
#   IamCustomerPolicyBlockedKmsActions:
#     Properties:
#       ConfigRuleName: iam-customer-policy-blocked-kms-actions
#       InputParameters:
#         blockedActionsPatterns:
#           Fn::If:
#           - iamCustomerPolicyBlockedKmsActionsParamBlockedActionsPatterns
#           - Ref: IamCustomerPolicyBlockedKmsActionsParamBlockedActionsPatterns
#           - Ref: AWS::NoValue
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::IAM::Policy
#       Source:
#         Owner: AWS
#         SourceIdentifier: IAM_CUSTOMER_POLICY_BLOCKED_KMS_ACTIONS
#     Type: AWS::Config::ConfigRule
#   IamGroupHasUsersCheck:
#     Properties:
#       ConfigRuleName: iam-group-has-users-check
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::IAM::Group
#       Source:
#         Owner: AWS
#         SourceIdentifier: IAM_GROUP_HAS_USERS_CHECK
#     Type: AWS::Config::ConfigRule
#   IamInlinePolicyBlockedKmsActions:
#     Properties:
#       ConfigRuleName: iam-inline-policy-blocked-kms-actions
#       InputParameters:
#         blockedActionsPatterns:
#           Fn::If:
#           - iamInlinePolicyBlockedKmsActionsParamBlockedActionsPatterns
#           - Ref: IamInlinePolicyBlockedKmsActionsParamBlockedActionsPatterns
#           - Ref: AWS::NoValue
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::IAM::Group
#         - AWS::IAM::Role
#         - AWS::IAM::User
#       Source:
#         Owner: AWS
#         SourceIdentifier: IAM_INLINE_POLICY_BLOCKED_KMS_ACTIONS
#     Type: AWS::Config::ConfigRule
#   IamNoInlinePolicyCheck:
#     Properties:
#       ConfigRuleName: iam-no-inline-policy-check
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::IAM::User
#         - AWS::IAM::Role
#         - AWS::IAM::Group
#       Source:
#         Owner: AWS
#         SourceIdentifier: IAM_NO_INLINE_POLICY_CHECK
#     Type: AWS::Config::ConfigRule
#   IamPasswordPolicy:
#     Properties:
#       ConfigRuleName: iam-password-policy
#       InputParameters:
#         MaxPasswordAge:
#           Fn::If:
#           - iamPasswordPolicyParamMaxPasswordAge
#           - Ref: IamPasswordPolicyParamMaxPasswordAge
#           - Ref: AWS::NoValue
#         MinimumPasswordLength:
#           Fn::If:
#           - iamPasswordPolicyParamMinimumPasswordLength
#           - Ref: IamPasswordPolicyParamMinimumPasswordLength
#           - Ref: AWS::NoValue
#         PasswordReusePrevention:
#           Fn::If:
#           - iamPasswordPolicyParamPasswordReusePrevention
#           - Ref: IamPasswordPolicyParamPasswordReusePrevention
#           - Ref: AWS::NoValue
#         RequireLowercaseCharacters:
#           Fn::If:
#           - iamPasswordPolicyParamRequireLowercaseCharacters
#           - Ref: IamPasswordPolicyParamRequireLowercaseCharacters
#           - Ref: AWS::NoValue
#         RequireNumbers:
#           Fn::If:
#           - iamPasswordPolicyParamRequireNumbers
#           - Ref: IamPasswordPolicyParamRequireNumbers
#           - Ref: AWS::NoValue
#         RequireSymbols:
#           Fn::If:
#           - iamPasswordPolicyParamRequireSymbols
#           - Ref: IamPasswordPolicyParamRequireSymbols
#           - Ref: AWS::NoValue
#         RequireUppercaseCharacters:
#           Fn::If:
#           - iamPasswordPolicyParamRequireUppercaseCharacters
#           - Ref: IamPasswordPolicyParamRequireUppercaseCharacters
#           - Ref: AWS::NoValue
#       Source:
#         Owner: AWS
#         SourceIdentifier: IAM_PASSWORD_POLICY
#     Type: AWS::Config::ConfigRule
#   IamPolicyNoStatementsWithAdminAccess:
#     Properties:
#       ConfigRuleName: iam-policy-no-statements-with-admin-access
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::IAM::Policy
#       Source:
#         Owner: AWS
#         SourceIdentifier: IAM_POLICY_NO_STATEMENTS_WITH_ADMIN_ACCESS
#     Type: AWS::Config::ConfigRule
#   IamPolicyNoStatementsWithFullAccess:
#     Properties:
#       ConfigRuleName: iam-policy-no-statements-with-full-access
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::IAM::Policy
#       Source:
#         Owner: AWS
#         SourceIdentifier: IAM_POLICY_NO_STATEMENTS_WITH_FULL_ACCESS
#     Type: AWS::Config::ConfigRule
#   IamRootAccessKeyCheck:
#     Properties:
#       ConfigRuleName: iam-root-access-key-check
#       Source:
#         Owner: AWS
#         SourceIdentifier: IAM_ROOT_ACCESS_KEY_CHECK
#     Type: AWS::Config::ConfigRule
#   IamUserGroupMembershipCheck:
#     Properties:
#       ConfigRuleName: iam-user-group-membership-check
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::IAM::User
#       Source:
#         Owner: AWS
#         SourceIdentifier: IAM_USER_GROUP_MEMBERSHIP_CHECK
#     Type: AWS::Config::ConfigRule
#   IamUserMfaEnabled:
#     Properties:
#       ConfigRuleName: iam-user-mfa-enabled
#       Source:
#         Owner: AWS
#         SourceIdentifier: IAM_USER_MFA_ENABLED
#     Type: AWS::Config::ConfigRule
#   IamUserNoPoliciesCheck:
#     Properties:
#       ConfigRuleName: iam-user-no-policies-check
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::IAM::User
#       Source:
#         Owner: AWS
#         SourceIdentifier: IAM_USER_NO_POLICIES_CHECK
#     Type: AWS::Config::ConfigRule
#   IamUserUnusedCredentialsCheck:
#     Properties:
#       ConfigRuleName: iam-user-unused-credentials-check
#       InputParameters:
#         maxCredentialUsageAge:
#           Fn::If:
#           - iamUserUnusedCredentialsCheckParamMaxCredentialUsageAge
#           - Ref: IamUserUnusedCredentialsCheckParamMaxCredentialUsageAge
#           - Ref: AWS::NoValue
#       Source:
#         Owner: AWS
#         SourceIdentifier: IAM_USER_UNUSED_CREDENTIALS_CHECK
#     Type: AWS::Config::ConfigRule
#   IncomingSshDisabled:
#     Properties:
#       ConfigRuleName: restricted-ssh
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::EC2::SecurityGroup
#       Source:
#         Owner: AWS
#         SourceIdentifier: INCOMING_SSH_DISABLED
#     Type: AWS::Config::ConfigRule
#   InstancesInVpc:
#     Properties:
#       ConfigRuleName: ec2-instances-in-vpc
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::EC2::Instance
#       Source:
#         Owner: AWS
#         SourceIdentifier: INSTANCES_IN_VPC
#     Type: AWS::Config::ConfigRule
#   KmsCmkNotScheduledForDeletion:
#     Properties:
#       ConfigRuleName: kms-cmk-not-scheduled-for-deletion
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::KMS::Key
#       Source:
#         Owner: AWS
#         SourceIdentifier: KMS_CMK_NOT_SCHEDULED_FOR_DELETION
#     Type: AWS::Config::ConfigRule
#   LambdaConcurrencyCheck:
#     Properties:
#       ConfigRuleName: lambda-concurrency-check
#       InputParameters:
#         ConcurrencyLimitHigh:
#           Fn::If:
#           - lambdaConcurrencyCheckParamConcurrencyLimitHigh
#           - Ref: LambdaConcurrencyCheckParamConcurrencyLimitHigh
#           - Ref: AWS::NoValue
#         ConcurrencyLimitLow:
#           Fn::If:
#           - lambdaConcurrencyCheckParamConcurrencyLimitLow
#           - Ref: LambdaConcurrencyCheckParamConcurrencyLimitLow
#           - Ref: AWS::NoValue
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::Lambda::Function
#       Source:
#         Owner: AWS
#         SourceIdentifier: LAMBDA_CONCURRENCY_CHECK
#     Type: AWS::Config::ConfigRule
#   LambdaDlqCheck:
#     Properties:
#       ConfigRuleName: lambda-dlq-check
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::Lambda::Function
#       Source:
#         Owner: AWS
#         SourceIdentifier: LAMBDA_DLQ_CHECK
#     Type: AWS::Config::ConfigRule
#   LambdaFunctionPublicAccessProhibited:
#     Properties:
#       ConfigRuleName: lambda-function-public-access-prohibited
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::Lambda::Function
#       Source:
#         Owner: AWS
#         SourceIdentifier: LAMBDA_FUNCTION_PUBLIC_ACCESS_PROHIBITED
#     Type: AWS::Config::ConfigRule
#   LambdaInsideVpc:
#     Properties:
#       ConfigRuleName: lambda-inside-vpc
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::Lambda::Function
#       Source:
#         Owner: AWS
#         SourceIdentifier: LAMBDA_INSIDE_VPC
#     Type: AWS::Config::ConfigRule
#   MfaEnabledForIamConsoleAccess:
#     Properties:
#       ConfigRuleName: mfa-enabled-for-iam-console-access
#       Source:
#         Owner: AWS
#         SourceIdentifier: MFA_ENABLED_FOR_IAM_CONSOLE_ACCESS
#     Type: AWS::Config::ConfigRule
#   MultiRegionCloudTrailEnabled:
#     Properties:
#       ConfigRuleName: multi-region-cloudtrail-enabled
#       Source:
#         Owner: AWS
#         SourceIdentifier: MULTI_REGION_CLOUD_TRAIL_ENABLED
#     Type: AWS::Config::ConfigRule
#   NoUnrestrictedRouteToIgw:
#     Properties:
#       ConfigRuleName: no-unrestricted-route-to-igw
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::EC2::RouteTable
#       Source:
#         Owner: AWS
#         SourceIdentifier: NO_UNRESTRICTED_ROUTE_TO_IGW
#     Type: AWS::Config::ConfigRule
#   RdsAutomaticMinorVersionUpgradeEnabled:
#     Properties:
#       ConfigRuleName: rds-automatic-minor-version-upgrade-enabled
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::RDS::DBInstance
#       Source:
#         Owner: AWS
#         SourceIdentifier: RDS_AUTOMATIC_MINOR_VERSION_UPGRADE_ENABLED
#     Type: AWS::Config::ConfigRule
#   RdsEnhancedMonitoringEnabled:
#     Properties:
#       ConfigRuleName: rds-enhanced-monitoring-enabled
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::RDS::DBInstance
#       Source:
#         Owner: AWS
#         SourceIdentifier: RDS_ENHANCED_MONITORING_ENABLED
#     Type: AWS::Config::ConfigRule
#   RdsInBackupPlan:
#     Properties:
#       ConfigRuleName: rds-in-backup-plan
#       Source:
#         Owner: AWS
#         SourceIdentifier: RDS_IN_BACKUP_PLAN
#     Type: AWS::Config::ConfigRule
#   RdsInstanceDeletionProtectionEnabled:
#     Properties:
#       ConfigRuleName: rds-instance-deletion-protection-enabled
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::RDS::DBInstance
#       Source:
#         Owner: AWS
#         SourceIdentifier: RDS_INSTANCE_DELETION_PROTECTION_ENABLED
#     Type: AWS::Config::ConfigRule
#   RdsInstancePublicAccessCheck:
#     Properties:
#       ConfigRuleName: rds-instance-public-access-check
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::RDS::DBInstance
#       Source:
#         Owner: AWS
#         SourceIdentifier: RDS_INSTANCE_PUBLIC_ACCESS_CHECK
#     Type: AWS::Config::ConfigRule
#   RdsLoggingEnabled:
#     Properties:
#       ConfigRuleName: rds-logging-enabled
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::RDS::DBInstance
#       Source:
#         Owner: AWS
#         SourceIdentifier: RDS_LOGGING_ENABLED
#     Type: AWS::Config::ConfigRule
#   RdsMultiAzSupport:
#     Properties:
#       ConfigRuleName: rds-multi-az-support
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::RDS::DBInstance
#       Source:
#         Owner: AWS
#         SourceIdentifier: RDS_MULTI_AZ_SUPPORT
#     Type: AWS::Config::ConfigRule
#   RdsSnapshotEncrypted:
#     Properties:
#       ConfigRuleName: rds-snapshot-encrypted
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::RDS::DBSnapshot
#         - AWS::RDS::DBClusterSnapshot
#       Source:
#         Owner: AWS
#         SourceIdentifier: RDS_SNAPSHOT_ENCRYPTED
#     Type: AWS::Config::ConfigRule
#   RdsSnapshotsPublicProhibited:
#     Properties:
#       ConfigRuleName: rds-snapshots-public-prohibited
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::RDS::DBSnapshot
#         - AWS::RDS::DBClusterSnapshot
#       Source:
#         Owner: AWS
#         SourceIdentifier: RDS_SNAPSHOTS_PUBLIC_PROHIBITED
#     Type: AWS::Config::ConfigRule
#   RdsStorageEncrypted:
#     Properties:
#       ConfigRuleName: rds-storage-encrypted
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::RDS::DBInstance
#       Source:
#         Owner: AWS
#         SourceIdentifier: RDS_STORAGE_ENCRYPTED
#     Type: AWS::Config::ConfigRule
#   RedshiftBackupEnabled:
#     Properties:
#       ConfigRuleName: redshift-backup-enabled
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::Redshift::Cluster
#       Source:
#         Owner: AWS
#         SourceIdentifier: REDSHIFT_BACKUP_ENABLED
#     Type: AWS::Config::ConfigRule
#   RedshiftClusterConfigurationCheck:
#     Properties:
#       ConfigRuleName: redshift-cluster-configuration-check
#       InputParameters:
#         clusterDbEncrypted: 'true'
#         loggingEnabled: 'true'
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::Redshift::Cluster
#       Source:
#         Owner: AWS
#         SourceIdentifier: REDSHIFT_CLUSTER_CONFIGURATION_CHECK
#     Type: AWS::Config::ConfigRule
#   RedshiftClusterKmsEnabled:
#     Properties:
#       ConfigRuleName: redshift-cluster-kms-enabled
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::Redshift::Cluster
#       Source:
#         Owner: AWS
#         SourceIdentifier: REDSHIFT_CLUSTER_KMS_ENABLED
#     Type: AWS::Config::ConfigRule
#   RedshiftClusterMaintenancesettingsCheck:
#     Properties:
#       ConfigRuleName: redshift-cluster-maintenancesettings-check
#       InputParameters:
#         allowVersionUpgrade:
#           Fn::If:
#           - redshiftClusterMaintenancesettingsCheckParamAllowVersionUpgrade
#           - Ref: RedshiftClusterMaintenancesettingsCheckParamAllowVersionUpgrade
#           - Ref: AWS::NoValue
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::Redshift::Cluster
#       Source:
#         Owner: AWS
#         SourceIdentifier: REDSHIFT_CLUSTER_MAINTENANCESETTINGS_CHECK
#     Type: AWS::Config::ConfigRule
#   RedshiftClusterPublicAccessCheck:
#     Properties:
#       ConfigRuleName: redshift-cluster-public-access-check
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::Redshift::Cluster
#       Source:
#         Owner: AWS
#         SourceIdentifier: REDSHIFT_CLUSTER_PUBLIC_ACCESS_CHECK
#     Type: AWS::Config::ConfigRule
#   RedshiftEnhancedVpcRoutingEnabled:
#     Properties:
#       ConfigRuleName: redshift-enhanced-vpc-routing-enabled
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::Redshift::Cluster
#       Source:
#         Owner: AWS
#         SourceIdentifier: REDSHIFT_ENHANCED_VPC_ROUTING_ENABLED
#     Type: AWS::Config::ConfigRule
#   RedshiftRequireTlsSsl:
#     Properties:
#       ConfigRuleName: redshift-require-tls-ssl
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::Redshift::Cluster
#       Source:
#         Owner: AWS
#         SourceIdentifier: REDSHIFT_REQUIRE_TLS_SSL
#     Type: AWS::Config::ConfigRule
#   RestrictedIncomingTraffic:
#     Properties:
#       ConfigRuleName: restricted-common-ports
#       InputParameters:
#         blockedPort1:
#           Fn::If:
#           - restrictedIncomingTrafficParamBlockedPort1
#           - Ref: RestrictedIncomingTrafficParamBlockedPort1
#           - Ref: AWS::NoValue
#         blockedPort2:
#           Fn::If:
#           - restrictedIncomingTrafficParamBlockedPort2
#           - Ref: RestrictedIncomingTrafficParamBlockedPort2
#           - Ref: AWS::NoValue
#         blockedPort3:
#           Fn::If:
#           - restrictedIncomingTrafficParamBlockedPort3
#           - Ref: RestrictedIncomingTrafficParamBlockedPort3
#           - Ref: AWS::NoValue
#         blockedPort4:
#           Fn::If:
#           - restrictedIncomingTrafficParamBlockedPort4
#           - Ref: RestrictedIncomingTrafficParamBlockedPort4
#           - Ref: AWS::NoValue
#         blockedPort5:
#           Fn::If:
#           - restrictedIncomingTrafficParamBlockedPort5
#           - Ref: RestrictedIncomingTrafficParamBlockedPort5
#           - Ref: AWS::NoValue
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::EC2::SecurityGroup
#       Source:
#         Owner: AWS
#         SourceIdentifier: RESTRICTED_INCOMING_TRAFFIC
#     Type: AWS::Config::ConfigRule
#   RootAccountHardwareMfaEnabled:
#     Properties:
#       ConfigRuleName: root-account-hardware-mfa-enabled
#       Source:
#         Owner: AWS
#         SourceIdentifier: ROOT_ACCOUNT_HARDWARE_MFA_ENABLED
#     Type: AWS::Config::ConfigRule
#   RootAccountMfaEnabled:
#     Properties:
#       ConfigRuleName: root-account-mfa-enabled
#       Source:
#         Owner: AWS
#         SourceIdentifier: ROOT_ACCOUNT_MFA_ENABLED
#     Type: AWS::Config::ConfigRule
#   S3AccountLevelPublicAccessBlocksPeriodic:
#     Properties:
#       ConfigRuleName: s3-account-level-public-access-blocks-periodic
#       Source:
#         Owner: AWS
#         SourceIdentifier: S3_ACCOUNT_LEVEL_PUBLIC_ACCESS_BLOCKS_PERIODIC
#     Type: AWS::Config::ConfigRule
#   S3BucketLevelPublicAccessProhibited:
#     Properties:
#       ConfigRuleName: s3-bucket-level-public-access-prohibited
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::S3::Bucket
#       Source:
#         Owner: AWS
#         SourceIdentifier: S3_BUCKET_LEVEL_PUBLIC_ACCESS_PROHIBITED
#     Type: AWS::Config::ConfigRule
#   S3BucketLoggingEnabled:
#     Properties:
#       ConfigRuleName: s3-bucket-logging-enabled
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::S3::Bucket
#       Source:
#         Owner: AWS
#         SourceIdentifier: S3_BUCKET_LOGGING_ENABLED
#     Type: AWS::Config::ConfigRule
#   S3BucketPublicReadProhibited:
#     Properties:
#       ConfigRuleName: s3-bucket-public-read-prohibited
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::S3::Bucket
#       Source:
#         Owner: AWS
#         SourceIdentifier: S3_BUCKET_PUBLIC_READ_PROHIBITED
#     Type: AWS::Config::ConfigRule
#   S3BucketPublicWriteProhibited:
#     Properties:
#       ConfigRuleName: s3-bucket-public-write-prohibited
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::S3::Bucket
#       Source:
#         Owner: AWS
#         SourceIdentifier: S3_BUCKET_PUBLIC_WRITE_PROHIBITED
#     Type: AWS::Config::ConfigRule
#   S3BucketReplicationEnabled:
#     Properties:
#       ConfigRuleName: s3-bucket-replication-enabled
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::S3::Bucket
#       Source:
#         Owner: AWS
#         SourceIdentifier: S3_BUCKET_REPLICATION_ENABLED
#     Type: AWS::Config::ConfigRule
#   S3BucketServerSideEncryptionEnabled:
#     Properties:
#       ConfigRuleName: s3-bucket-server-side-encryption-enabled
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::S3::Bucket
#       Source:
#         Owner: AWS
#         SourceIdentifier: S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED
#     Type: AWS::Config::ConfigRule
#   S3BucketSslRequestsOnly:
#     Properties:
#       ConfigRuleName: s3-bucket-ssl-requests-only
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::S3::Bucket
#       Source:
#         Owner: AWS
#         SourceIdentifier: S3_BUCKET_SSL_REQUESTS_ONLY
#     Type: AWS::Config::ConfigRule
#   S3BucketVersioningEnabled:
#     Properties:
#       ConfigRuleName: s3-bucket-versioning-enabled
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::S3::Bucket
#       Source:
#         Owner: AWS
#         SourceIdentifier: S3_BUCKET_VERSIONING_ENABLED
#     Type: AWS::Config::ConfigRule
#   S3DefaultEncryptionKms:
#     Properties:
#       ConfigRuleName: s3-default-encryption-kms
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::S3::Bucket
#       Source:
#         Owner: AWS
#         SourceIdentifier: S3_DEFAULT_ENCRYPTION_KMS
#     Type: AWS::Config::ConfigRule
#   SagemakerEndpointConfigurationKmsKeyConfigured:
#     Properties:
#       ConfigRuleName: sagemaker-endpoint-configuration-kms-key-configured
#       Source:
#         Owner: AWS
#         SourceIdentifier: SAGEMAKER_ENDPOINT_CONFIGURATION_KMS_KEY_CONFIGURED
#     Type: AWS::Config::ConfigRule
#   SagemakerNotebookInstanceKmsKeyConfigured:
#     Properties:
#       ConfigRuleName: sagemaker-notebook-instance-kms-key-configured
#       Source:
#         Owner: AWS
#         SourceIdentifier: SAGEMAKER_NOTEBOOK_INSTANCE_KMS_KEY_CONFIGURED
#     Type: AWS::Config::ConfigRule
#   SagemakerNotebookNoDirectInternetAccess:
#     Properties:
#       ConfigRuleName: sagemaker-notebook-no-direct-internet-access
#       Source:
#         Owner: AWS
#         SourceIdentifier: SAGEMAKER_NOTEBOOK_NO_DIRECT_INTERNET_ACCESS
#     Type: AWS::Config::ConfigRule
#   SecretsmanagerRotationEnabledCheck:
#     Properties:
#       ConfigRuleName: secretsmanager-rotation-enabled-check
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::SecretsManager::Secret
#       Source:
#         Owner: AWS
#         SourceIdentifier: SECRETSMANAGER_ROTATION_ENABLED_CHECK
#     Type: AWS::Config::ConfigRule
#   SecurityhubEnabled:
#     Properties:
#       ConfigRuleName: securityhub-enabled
#       Source:
#         Owner: AWS
#         SourceIdentifier: SECURITYHUB_ENABLED
#     Type: AWS::Config::ConfigRule
#   SsmDocumentNotPublic:
#     Properties:
#       ConfigRuleName: ssm-document-not-public
#       Source:
#         Owner: AWS
#         SourceIdentifier: SSM_DOCUMENT_NOT_PUBLIC
#     Type: AWS::Config::ConfigRule
#   SubnetAutoAssignPublicIpDisabled:
#     Properties:
#       ConfigRuleName: subnet-auto-assign-public-ip-disabled
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::EC2::Subnet
#       Source:
#         Owner: AWS
#         SourceIdentifier: SUBNET_AUTO_ASSIGN_PUBLIC_IP_DISABLED
#     Type: AWS::Config::ConfigRule
#   VpcDefaultSecurityGroupClosed:
#     Properties:
#       ConfigRuleName: vpc-default-security-group-closed
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::EC2::SecurityGroup
#       Source:
#         Owner: AWS
#         SourceIdentifier: VPC_DEFAULT_SECURITY_GROUP_CLOSED
#     Type: AWS::Config::ConfigRule
#   VpcFlowLogsEnabled:
#     Properties:
#       ConfigRuleName: vpc-flow-logs-enabled
#       Source:
#         Owner: AWS
#         SourceIdentifier: VPC_FLOW_LOGS_ENABLED
#     Type: AWS::Config::ConfigRule
#   VpcSgOpenOnlyToAuthorizedPorts:
#     Properties:
#       ConfigRuleName: vpc-sg-open-only-to-authorized-ports
#       InputParameters:
#         authorizedTcpPorts:
#           Fn::If:
#           - vpcSgOpenOnlyToAuthorizedPortsParamAuthorizedTcpPorts
#           - Ref: VpcSgOpenOnlyToAuthorizedPortsParamAuthorizedTcpPorts
#           - Ref: AWS::NoValue
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::EC2::SecurityGroup
#       Source:
#         Owner: AWS
#         SourceIdentifier: VPC_SG_OPEN_ONLY_TO_AUTHORIZED_PORTS
#     Type: AWS::Config::ConfigRule
#   VpcVpn2TunnelsUp:
#     Properties:
#       ConfigRuleName: vpc-vpn-2-tunnels-up
#       Scope:
#         ComplianceResourceTypes:
#         - AWS::EC2::VPNConnection
#       Source:
#         Owner: AWS
#         SourceIdentifier: VPC_VPN_2_TUNNELS_UP
#     Type: AWS::Config::ConfigRule
#   Wafv2LoggingEnabled:
#     Properties:
#       ConfigRuleName: wafv2-logging-enabled
#       Source:
#         Owner: AWS
#         SourceIdentifier: WAFV2_LOGGING_ENABLED
#     Type: AWS::Config::ConfigRule
#   ResponsePlanExistsMaintained:
#     Properties:
#       ConfigRuleName: response-plan-exists-maintained
#       Description: Ensure incident response plans are established, maintained, and distributed to responsible personnel.
#       Source:
#         Owner: AWS
#         SourceIdentifier: AWS_CONFIG_PROCESS_CHECK
#     Type: AWS::Config::ConfigRule
#   AnnualRiskAssessmentPerformed:
#     Properties:
#       ConfigRuleName: annual-risk-assessment-performed
#       Description: Perform an annual risk assessment on your organization. Risk assessments can assist in determining the likelihood and impact of identified risks and/or vulnerabilities affecting an organization.
#       Source:
#         Owner: AWS
#         SourceIdentifier: AWS_CONFIG_PROCESS_CHECK
#     Type: AWS::Config::ConfigRule
# Conditions:
#   accessKeysRotatedParamMaxAccessKeyAge:
#     Fn::Not:
#     - Fn::Equals:
#       - ''
#       - Ref: AccessKeysRotatedParamMaxAccessKeyAge
#   acmCertificateExpirationCheckParamDaysToExpiration:
#     Fn::Not:
#     - Fn::Equals:
#       - ''
#       - Ref: AcmCertificateExpirationCheckParamDaysToExpiration
#   backupPlanMinFrequencyAndMinRetentionCheckParamRequiredFrequencyUnit:
#     Fn::Not:
#     - Fn::Equals:
#       - ''
#       - Ref: BackupPlanMinFrequencyAndMinRetentionCheckParamRequiredFrequencyUnit
#   backupPlanMinFrequencyAndMinRetentionCheckParamRequiredFrequencyValue:
#     Fn::Not:
#     - Fn::Equals:
#       - ''
#       - Ref: BackupPlanMinFrequencyAndMinRetentionCheckParamRequiredFrequencyValue
#   backupPlanMinFrequencyAndMinRetentionCheckParamRequiredRetentionDays:
#     Fn::Not:
#     - Fn::Equals:
#       - ''
#       - Ref: BackupPlanMinFrequencyAndMinRetentionCheckParamRequiredRetentionDays
#   dynamodbThroughputLimitCheckParamAccountRCUThresholdPercentage:
#     Fn::Not:
#     - Fn::Equals:
#       - ''
#       - Ref: DynamodbThroughputLimitCheckParamAccountRCUThresholdPercentage
#   dynamodbThroughputLimitCheckParamAccountWCUThresholdPercentage:
#     Fn::Not:
#     - Fn::Equals:
#       - ''
#       - Ref: DynamodbThroughputLimitCheckParamAccountWCUThresholdPercentage
#   ec2VolumeInuseCheckParamDeleteOnTermination:
#     Fn::Not:
#     - Fn::Equals:
#       - ''
#       - Ref: Ec2VolumeInuseCheckParamDeleteOnTermination
#   iamCustomerPolicyBlockedKmsActionsParamBlockedActionsPatterns:
#     Fn::Not:
#     - Fn::Equals:
#       - ''
#       - Ref: IamCustomerPolicyBlockedKmsActionsParamBlockedActionsPatterns
#   iamInlinePolicyBlockedKmsActionsParamBlockedActionsPatterns:
#     Fn::Not:
#     - Fn::Equals:
#       - ''
#       - Ref: IamInlinePolicyBlockedKmsActionsParamBlockedActionsPatterns
#   iamPasswordPolicyParamMaxPasswordAge:
#     Fn::Not:
#     - Fn::Equals:
#       - ''
#       - Ref: IamPasswordPolicyParamMaxPasswordAge
#   iamPasswordPolicyParamMinimumPasswordLength:
#     Fn::Not:
#     - Fn::Equals:
#       - ''
#       - Ref: IamPasswordPolicyParamMinimumPasswordLength
#   iamPasswordPolicyParamPasswordReusePrevention:
#     Fn::Not:
#     - Fn::Equals:
#       - ''
#       - Ref: IamPasswordPolicyParamPasswordReusePrevention
#   iamPasswordPolicyParamRequireLowercaseCharacters:
#     Fn::Not:
#     - Fn::Equals:
#       - ''
#       - Ref: IamPasswordPolicyParamRequireLowercaseCharacters
#   iamPasswordPolicyParamRequireNumbers:
#     Fn::Not:
#     - Fn::Equals:
#       - ''
#       - Ref: IamPasswordPolicyParamRequireNumbers
#   iamPasswordPolicyParamRequireSymbols:
#     Fn::Not:
#     - Fn::Equals:
#       - ''
#       - Ref: IamPasswordPolicyParamRequireSymbols
#   iamPasswordPolicyParamRequireUppercaseCharacters:
#     Fn::Not:
#     - Fn::Equals:
#       - ''
#       - Ref: IamPasswordPolicyParamRequireUppercaseCharacters
#   iamUserUnusedCredentialsCheckParamMaxCredentialUsageAge:
#     Fn::Not:
#     - Fn::Equals:
#       - ''
#       - Ref: IamUserUnusedCredentialsCheckParamMaxCredentialUsageAge
#   lambdaConcurrencyCheckParamConcurrencyLimitHigh:
#     Fn::Not:
#     - Fn::Equals:
#       - ''
#       - Ref: LambdaConcurrencyCheckParamConcurrencyLimitHigh
#   lambdaConcurrencyCheckParamConcurrencyLimitLow:
#     Fn::Not:
#     - Fn::Equals:
#       - ''
#       - Ref: LambdaConcurrencyCheckParamConcurrencyLimitLow
#   redshiftClusterMaintenancesettingsCheckParamAllowVersionUpgrade:
#     Fn::Not:
#     - Fn::Equals:
#       - ''
#       - Ref: RedshiftClusterMaintenancesettingsCheckParamAllowVersionUpgrade
#   restrictedIncomingTrafficParamBlockedPort1:
#     Fn::Not:
#     - Fn::Equals:
#       - ''
#       - Ref: RestrictedIncomingTrafficParamBlockedPort1
#   restrictedIncomingTrafficParamBlockedPort2:
#     Fn::Not:
#     - Fn::Equals:
#       - ''
#       - Ref: RestrictedIncomingTrafficParamBlockedPort2
#   restrictedIncomingTrafficParamBlockedPort3:
#     Fn::Not:
#     - Fn::Equals:
#       - ''
#       - Ref: RestrictedIncomingTrafficParamBlockedPort3
#   restrictedIncomingTrafficParamBlockedPort4:
#     Fn::Not:
#     - Fn::Equals:
#       - ''
#       - Ref: RestrictedIncomingTrafficParamBlockedPort4
#   restrictedIncomingTrafficParamBlockedPort5:
#     Fn::Not:
#     - Fn::Equals:
#       - ''
#       - Ref: RestrictedIncomingTrafficParamBlockedPort5
#   vpcSgOpenOnlyToAuthorizedPortsParamAuthorizedTcpPorts:
#     Fn::Not:
#     - Fn::Equals:
#       - ''
#       - Ref: VpcSgOpenOnlyToAuthorizedPortsParamAuthorizedTcpPorts


#   EOT
# }