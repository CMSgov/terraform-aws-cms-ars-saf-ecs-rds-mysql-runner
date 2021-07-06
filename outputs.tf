output "task_execution_role_arn" {
  description = "ARN for the IAM role that is executing the scanner"
  value       = aws_iam_role.task_role.arn
}