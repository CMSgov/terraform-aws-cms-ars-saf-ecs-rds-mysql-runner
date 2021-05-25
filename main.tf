locals {
  awslogs_group   = var.logs_cloudwatch_group_arn == "" ? "/ecs/${var.environment}/${var.app_name}" : split(":", var.logs_cloudwatch_group_arn)[6]
  cloudwatch_arn  = var.logs_cloudwatch_group_arn == "" ? aws_cloudwatch_log_group.main[0].arn : var.logs_cloudwatch_group_arn
  ecs_cluster_arn = var.ecs_cluster_arn == "" ? aws_ecs_cluster.inspec_cluster[0].arn : var.ecs_cluster_arn
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "cloudwatch_logs_allow_kms" {
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
      ]
    }

    actions = [
      "kms:*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "Allow logs KMS access"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
    }

    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]
    resources = ["*"]
  }
}

# Create a data source to pull the latest active revision from
data "aws_ecs_task_definition" "scheduled_task_def" {
  task_definition = aws_ecs_task_definition.scheduled_task_def.family
  depends_on      = [aws_ecs_task_definition.scheduled_task_def] # ensures at least one task def exists
}

# Assume Role policies

data "aws_partition" "current" {}

data "aws_region" "current" {}

data "aws_iam_policy_document" "ecs_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    effect = "Allow"
  }
}

data "aws_iam_policy_document" "events_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    effect = "Allow"
  }
}

resource "aws_kms_key" "log_enc_key" {
  description         = "KMS key for encrypting logs"
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.cloudwatch_logs_allow_kms.json
  count               = var.logs_cloudwatch_group_arn == "" ? 1 : 0 // do not create resource if cloudwatch log group arn is supplied as a variable


  tags = {
    Automation = "Terraform"
  }
}

resource "aws_ecs_cluster" "inspec_cluster" {
  name = "${var.app_name}-inspec"

  tags = {
    Environment = var.environment
    Automation  = "Terraform"
  }
  lifecycle {
    create_before_destroy = true
  }
  count = var.ecs_cluster_arn == "" ? 1 : 0
}

#  ecs service components

resource "aws_cloudwatch_log_group" "main" {
  name              = local.awslogs_group
  retention_in_days = var.logs_cloudwatch_retention

  kms_key_id = aws_kms_key.log_enc_key[0].arn
  count      = var.logs_cloudwatch_group_arn == "" ? 1 : 0 // do not create resource if it is supplied as a variable

  tags = {
    Name        = "${var.app_name}-${var.environment}"
    Environment = var.environment
    Automation  = "Terraform"
  }
}

# SG - ECS

resource "aws_security_group" "ecs_sg" {
  name        = "ecs-${var.app_name}-${var.environment}"
  description = "${var.app_name}-${var.environment} container security group"
  vpc_id      = var.ecs_vpc_id

  tags = {
    Name        = "ecs-${var.app_name}-${var.environment}"
    Environment = var.environment
    Automation  = "Terraform"
  }
}

resource "aws_security_group_rule" "app_ecs_allow_outbound" {
  description       = "Allow all outbound"
  security_group_id = aws_security_group.ecs_sg.id

  type        = "egress"
  from_port   = 3306
  to_port     = 3306
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}

## ECS schedule task

# Allows CloudWatch Rule to run ECS Task

data "aws_iam_policy_document" "cloudwatch_target_role_policy_doc" {
  statement {
    actions   = ["iam:PassRole"]
    resources = ["*"]
  }

  statement {
    actions   = ["ecs:RunTask"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "cloudwatch_target_role" {
  name               = "cw-target-role-${var.app_name}-${var.environment}-${var.task_name}"
  description        = "Role allowing CloudWatch Events to run the task"
  assume_role_policy = data.aws_iam_policy_document.events_assume_role_policy.json
}

resource "aws_iam_role_policy" "cloudwatch_target_role_policy" {
  name   = "${aws_iam_role.cloudwatch_target_role.name}-policy"
  role   = aws_iam_role.cloudwatch_target_role.name
  policy = data.aws_iam_policy_document.cloudwatch_target_role_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "read_only_everything" {
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
  role       = aws_iam_role.task_role.name
}

resource "aws_iam_role" "task_role" {
  name               = "ecs-task-role-${var.app_name}-${var.environment}-${var.task_name}"
  description        = "Role allowing container definition to execute"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role_policy.json
}

resource "aws_iam_role" "task_execution_role" {
  name               = "ecs-task-exec-role-${var.app_name}-${var.environment}-${var.task_name}"
  description        = "Role allowing ECS tasks to execute"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role_policy.json
}

resource "aws_iam_role_policy" "task_execution_role_policy" {
  name   = "${aws_iam_role.task_execution_role.name}-policy"
  role   = aws_iam_role.task_execution_role.name
  policy = templatefile("${path.module}/parameter-store-policy.tpl", {
    cloudwatch_arn     = local.cloudwatch_arn,
    repo_arn           = var.repo_arn,
    partition          = data.aws_partition.current.partition,
    region             = data.aws_region.current.name,
    caller_id          = data.aws_caller_identity.current.account_id,
    app_name           = var.app_name,
    environment        = var.environment,
    secretsManager_arn = var.secret_rds_credentials_arn,
    username_arn       = var.secret_mysql_username_arn,
    password_arn       = var.secret_mysql_password_arn,
    hostname_arn       = var.secret_mysql_hostname_arn,
    kms_key_arn        = var.kms_key_arn
  })
}

#
# CloudWatch
#

resource "aws_cloudwatch_event_rule" "run_command" {
  name                = "${var.task_name}-${var.environment}"
  description         = "Scheduled task for ${var.task_name} in ${var.environment}"
  schedule_expression = var.schedule_task_expression
}

resource "aws_cloudwatch_event_target" "ecs_scheduled_task" {
  target_id = "run-scheduled-task-${var.task_name}-${var.environment}"
  arn       = local.ecs_cluster_arn
  rule      = aws_cloudwatch_event_rule.run_command.name
  role_arn  = aws_iam_role.cloudwatch_target_role.arn

  ecs_target {
    launch_type = "FARGATE"
    task_count  = 1

    # Use latest active revision
    task_definition_arn = aws_ecs_task_definition.scheduled_task_def.arn

    network_configuration {
      subnets          = var.ecs_subnet_ids
      security_groups  = [aws_security_group.ecs_sg.id]
      assign_public_ip = false
    }
  }
}

# ECS task details

resource "aws_ecs_task_definition" "scheduled_task_def" {
  family        = "${var.app_name}-${var.environment}-${var.task_name}"
  network_mode  = "awsvpc"
  task_role_arn = aws_iam_role.task_role.arn

  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "1024"
  execution_role_arn       = join("", aws_iam_role.task_execution_role.*.arn)

  container_definitions = templatefile("${path.module}/container-definitions.tpl",
    {
      app_name = var.app_name,
      environment = var.environment,
      task_name = var.task_name,
      awslogs_group = local.awslogs_group,
      awslogs_region = data.aws_region.current.name,
      repo_url = var.repo_url,
      repo_tag = var.repo_tag,
      s3_results_bucket = var.s3_results_bucket,
      mysql_port = var.mysql_port,
      mysql_version = var.mysql_version,
      mysql_users = var.mysql_users,
      worker_configured = var.worker_configured,
      admin_users = var.admin_users,
      read_write_users = var.read_write_users,
      secretsManager_arn = var.secret_rds_credentials_arn,
      username_arn       = var.secret_mysql_username_arn,
      password_arn       = var.secret_mysql_password_arn,
      hostname_arn       = var.secret_mysql_hostname_arn
    }
  )
}

