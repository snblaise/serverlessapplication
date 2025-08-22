output "function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.main.arn
}

output "function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.main.function_name
}

output "alias_arn" {
  description = "ARN of the Lambda function live alias"
  value       = aws_lambda_alias.live.arn
}

output "execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.arn
}

output "dlq_arn" {
  description = "ARN of the dead letter queue"
  value       = aws_sqs_queue.dlq.arn
}

output "code_signing_config_arn" {
  description = "ARN of the code signing configuration"
  value       = var.code_signing_profile_arn != "" ? aws_lambda_code_signing_config.main[0].arn : null
}