output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = module.lambda_function.function_arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = module.lambda_function.function_name
}

output "lambda_alias_arn" {
  description = "ARN of the Lambda function live alias"
  value       = module.lambda_function.alias_arn
}

output "codedeploy_application_name" {
  description = "Name of the CodeDeploy application"
  value       = aws_codedeploy_app.lambda_app.name
}

output "codedeploy_deployment_group_name" {
  description = "Name of the CodeDeploy deployment group"
  value       = aws_codedeploy_deployment_group.lambda_deployment_group.deployment_group_name
}

output "s3_artifacts_bucket" {
  description = "Name of the S3 bucket for deployment artifacts"
  value       = aws_s3_bucket.lambda_artifacts.bucket
}

output "cloudwatch_alarms" {
  description = "CloudWatch alarm names for monitoring"
  value = {
    error_rate = aws_cloudwatch_metric_alarm.lambda_error_rate.alarm_name
    duration   = aws_cloudwatch_metric_alarm.lambda_duration.alarm_name
    throttle   = aws_cloudwatch_metric_alarm.lambda_throttle.alarm_name
  }
}