variable "app_name" {
  type        = string
  description = "Name of the application"
}

variable "task_name" {
  type        = string
  description = "Name of the task to be run"
}

variable "parameter_store_enc_kms_key" {
  type        = string
  description = "KMS key for parameter store secret decryption"
  default     = ""
}

variable "ecs_cluster_arn" {
  description = "ECS cluster ARN to use for running this profile"
  type        = string
  default     = ""
}

variable "ecs_vpc_id" {
  description = "VPC ID to be used by ECS."
  type        = string
}

variable "ecs_subnet_ids" {
  description = "Subnet IDs for the ECS tasks."
  type        = list(string)
}

variable "logs_cloudwatch_retention" {
  description = "Number of days you want to retain log events in the log group"
  default     = 731 //  two years
  type        = number
}

variable "logs_cloudwatch_group_arn" {
  description = "CloudWatch log group arn for container logs"
  type        = string
}

variable "repo_url" {
  type        = string
  description = "The url of the ECR repo to pull images and run in ecs"
}

variable "repo_tag" {
  type        = string
  description = "The tag to identify and pull the image in ECR repo"
  default     = "latest"
}

variable "schedule_task_expression" {
  type        = string
  description = "Cron based schedule task to run on a cadence"
  default     = "cron(30 9 * * ? *)" // run 9:30 everyday"
}

variable "repo_arn" {
  type        = string
  description = "Arn of the ecr repo hosting the scanner container image"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "tags" {
  type        = map(any)
  description = "Additional tags to apply."
  default     = {}
}

variable "scan_on_push" {
  type        = bool
  description = "Scan image on push to repo."
  default     = true
}

variable "s3_results_bucket" {
  type        = string
  description = "Bucket to store scan results"
  default     = ""
}

variable "secret_rds_credentials_arn" {
  type        = string
  description = "ARN of RDS credentials stored in AWS Secrets Manager"
  default     = ""
}

variable "secret_mysql_username_arn" {
  type        = string
  description = "ARN of Mysql database username"
  default     = ""
}

variable "secret_mysql_password_arn" {
  type        = string
  description = "ARN of Mysql database password"
  default     = ""
}

variable "secret_mysql_hostname_arn" {
  type        = string
  description = "ARN of Mysql database hostname"
  default     = ""
}

variable "mysql_port" {
  type        = string
  description = "Mysql port"
}

variable "mysql_version" {
  type        = string
  description = "Mysql version"
}

variable "mysql_users" {
  type        = list(string)
  description = "Mysql users"
  default     = []
}

variable "worker_configured" {
  type        = bool
  description = "Mysql worker configuration - true/false"
}

variable "admin_users" {
  type        = list(string)
  description = "Mysql admin users"
}

variable "read_write_users" {
  type        = list(string)
  description = "Mysql read write users"
}