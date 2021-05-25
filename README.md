# terraform-aws-cms-ars-saf-ecs-rds-mysql-runner

This repository contains a Terraform module to deploy a scheduled ECS task. The ECS task runs a [cinc-auditor](https://cinc.sh/start/auditor/) (read: Chef Inspec) scan against an RDS instance. This profile is configured to run against a mysql instance.

This module supports the following features:
* Run an ECS task and stream its output to Cloudwatch
* Ability to run the task on a cron based cadence
* Use a user defined ECR repo to run ECS tasks

## Usage

```hcl
module "ecs_saf_rds_mysql_runner" {
  source = "github.com/CMSgov/terraform-aws-cms-ars-saf-ecs-rds-mysql-runner?ref=f72c13c718e9bcbfc2bc5cc4a025e64d8d30bfaa"
  app_name    = local.app_name
  environment = local.environment

  task_name                 = "CIS-RDS-mysql"
  ecs_vpc_id                = data.aws_vpc.mac_fc_example_east_sandbox.id
  ecs_subnet_ids            = data.aws_subnet_ids.private.ids
  repo_url                  = module.cms_ars_repo.repo_url
  repo_tag                  = "latest"
  schedule_task_expression  = "cron(30 9 * * ? *)"
  repo_arn                  = module.cms_ars_repo.arn
  logs_cloudwatch_group_arn = aws_cloudwatch_log_group.main.arn

  ecs_cluster_arn               = "arn:aws:ecs:us-east-1:037370603820:cluster/aws-scanner-inspec"
  s3_results_bucket             = join("", ["s3://", aws_s3_bucket.saf_rds_mysql_results.bucket])

  
  // if using AWS Secrets Manager
  secret_rds_credentials_arn    = data.aws_secretsmanager_secret_version.rds_credentials.arn

  // if using AWS Parameter Store
  kms_key_arn                     = aws_kms_key.kms_key_for_rds_secrets.arn
  # secret_mysql_username_arn     = aws_ssm_parameter.username.arn
  # secret_mysql_password_arn     = aws_ssm_parameter.password.arn
  # secret_mysql_hostname_arn     = aws_ssm_parameter.hostname.arn

  mysql_port                    = "3306"
  mysql_version                 = "5.7.33"
  mysql_users                   = ["complete_mysql"]
  worker_configured             = false
  admin_users                   = ["complete_mysql"]
  read_write_users              = ["complete_mysql"]
}
```
## Required Parameters

You must provide EITHER an AWS Secrets Manager secret (secret_rds_credentials_arn) OR AWS Parameter Store secrets (secret_mysql_username_arn, secret_mysql_password_arn, secret_mysql_hostname_arn) and a corresponding AWS KMS key, as shown above.

In addition, the mysql_port, version, users, etc. are also required.
## Optional Parameters

| Name | Default Value | Description |
|------|---------|---------|
| logs_cloudwatch_group_arn | "" | CloudWatch log group arn, overrides values of logs_cloudwatch_retention & logs_cloudwatch_group |
| ecs_cluster_arn | "" | You can provide your own ECS Cluster ARN to prevent a new provisioning of one for this task |
| s3_results_bucket | "" | Bucket value to store scan results, if value is a valid bucket path json files will be streamed to it. |

## Outputs

| Name | Description |
|------|---------|
| task_execution_role_arn | ARN for the IAM role that is executing the scanner |

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 0.12 |

## Modules

No Modules.