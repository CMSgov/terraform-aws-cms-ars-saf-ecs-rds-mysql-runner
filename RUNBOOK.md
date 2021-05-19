# AWS RDS Inspec/Cinc-Auditor Profile

| Author | Chikara Takahashi |
|------|---------|
| Team | MAC-FC |
| Sponsor | Vidit Majmudar |
---

## Summary

This runbook describes how to deploy the [AWS RDS Inspec (Cinc-Auditor) Profile](https://github.com/CMSgov/cms-ars-3.1-moderate-aws-rds-oracle-mysql-ee-5.7-cis-overlay) for Mysql databases.

## Inspec vs Cinc-Auditor

CMS profiles are moving to use CINC-Auditor, the open-source packaged binary version of Chef Inspec, compiled by the [CINC](https://cinc.sh) project. [CINC-Auditor](https://cinc.sh/start/auditor/) is also fully compatible with Chef Inspec and is functionally identical.

## Deploying the Profile

1. Create an instance of the [AWS RDS Mysql runner module](https://github.com/cmsgov/terraform-aws-cms-ars-saf-ecs-rds-mysql-runner) in your terraform environment.

```hcl
module "ecs_saf_rds_mysql_runner" {
  source = "github.com/CMSgov/terraform-aws-cms-ars-saf-ecs-rds-mysql-runner?ref=d28ca1bb5248808e69e9ebecec2f3055a229025a"
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

  kms_key_arn                   = aws_kms_key.kms_key_for_rds_secrets.arn

  secret_mysql_username_arn     = aws_ssm_parameter.username.arn
  secret_mysql_password_arn     = aws_ssm_parameter.password.arn
  secret_mysql_hostname_arn     = aws_ssm_parameter.hostname.arn
  mysql_port                    = "3306"
  mysql_version                 = "5.7.33"
  mysql_users                   = ["complete_mysql"]
  worker_configured             = false
  admin_users                   = ["complete_mysql"]
  read_write_users              = ["complete_mysql"]
}
```
2. Configure the module variables.
  * In the example above, we reference existing data resources for items like the vpc and subnet You can create your own instances as needed
  * The runner accepts several variables
    * If you do not provide cloudwatch log groupings, they will be created for you
    * Several input variables are directly related to accessing your RDS instance
      * These input variables can be gleaned from the [profile README](https://github.com/CMSgov/cms-ars-3.1-moderate-aws-rds-oracle-mysql-ee-5.7-cis-overlay#tailoring-to-your-environment).
    * The current configuration uses AWS Systems Manager Parameter Store to store secrets. The example below creates a unique AWS KMS key for encrypting the RDS username. Other sensitive values such as password and hostname should be similarly encrypted.

    ```hcl
    resource "aws_kms_key" "kms_key_for_rds_secrets" {
      description = "kms key to encrypt rds secret values"
    }

    resource "aws_ssm_parameter" "username" {
      name        = "/${local.app_name}-${local.environment}/username"
      description = "the mysql db username to run profile"
      type        = "SecureString"
      value       = "USERNAME"
      key_id      = aws_kms_key.kms_key_for_rds_secrets.key_id

      tags = {
        Name        = "aws-rds-mysql-scanner-dev"
        Environment = "dev"
        Automation  = "Terraform"

      }
      lifecycle {
        ignore_changes = [
          value
        ]
      }
    }

    ```
  * Similar to the AWS Moderate Inspec Profile, This module supports publishing JSON formatted results of the scanner to an S3 bucket
    * Note that an s3 bucket path is OPTIONAL for the scan to run - if not provided, the logs will still be written to AWS CloudWatch in the appropriate log grouping

    ```hcl
    resource "aws_s3_bucket_policy" "saf_rds_mysql_results_bucket_policy" {
      bucket = aws_s3_bucket.saf_rds_mysql_results.id
      policy = jsonencode({
        Version = "2012-10-17"
        Id      = "saf_rds_mysql_results_bucket"
        Statement = [
          {
            Sid       = "write-only"
            Effect    = "Allow"
            Principal = { AWS : [module.ecs_saf_rds_mysql_runner.task_execution_role_arn] }
            Action    = ["s3:PutObject"]
            Resource = [
              aws_s3_bucket.saf_rds_mysql_results.arn,
              "${aws_s3_bucket.saf_rds_mysql_results.arn}/*",
            ]
          }
        ]
      })
    }
    ```
3. Provide cross account permissions
* Similar to the [AWS Moderate Inspec Profile](https://confluenceent.cms.gov/display/CMCSMAC/AWS+Moderate+InSpec+Profile), you will need to request cross account permissions to pull the latest ECR image. Please send a slack message to the #dsg-fc channel with the following message:
  ```
  Please give our AWS account: xxyyzzaabbcc pull permissions for the AWS RDS Mysql Inspec Profile
  ```

## Common Issues/Challenges

### Permissions surrounding encryption of secrets

A challenge we faced when putting this profile together was putting adequate permissions together for encrypting RDS instance credentials. For our purposes, we used Amazon Parameter Store and provisioned our own KMS key as shown in the second code snippet in this document. This KMS key should be passed to the runner module, and the task execution role policy doc needs to be given sufficient permissions to access these parameters, like so:
```hcl
data "aws_iam_policy_document" "task_execution_role_policy_doc" {
  // ...
  // ...
  // omitted for brevity

  statement {
    actions = [
      "ssm:GetParameters",
    ]

    resources = [
      var.secret_mysql_password_arn,
      var.secret_mysql_username_arn,
      var.secret_mysql_hostname_arn
    ]
  }

  statement {
    actions = [
      "kms:Decrypt"
    ]

    resources = [
      var.kms_key_arn
    ]
  }
}
```

### Permissions for RDS Database access

??? db access permissions 