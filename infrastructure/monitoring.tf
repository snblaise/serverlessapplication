# CloudWatch alarms for Lambda monitoring
resource "aws_cloudwatch_metric_alarm" "lambda_error_rate" {
  alarm_name          = "lambda-error-rate-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors lambda error rate"
  alarm_actions       = []

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  tags = {
    Environment = var.environment
    Project     = "lambda-production-readiness"
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "lambda-duration-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = "10000"
  alarm_description   = "This metric monitors lambda duration"
  alarm_actions       = []

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  tags = {
    Environment = var.environment
    Project     = "lambda-production-readiness"
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttle" {
  alarm_name          = "lambda-throttle-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "This metric monitors lambda throttles"
  alarm_actions       = []

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  tags = {
    Environment = var.environment
    Project     = "lambda-production-readiness"
  }
}