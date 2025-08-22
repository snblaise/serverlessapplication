resource "aws_lambda_function" "main" {
  function_name = var.function_name
  role         = aws_iam_role.lambda_execution.arn
  handler      = "index.handler"
  runtime      = "nodejs18.x"
  timeout      = var.timeout
  memory_size  = var.memory_size
  
  filename         = var.deployment_package
  source_code_hash = filebase64sha256(var.deployment_package)
  
  code_signing_config_arn = var.code_signing_config_arn != "" ? var.code_signing_config_arn : null
  
  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }
  
  environment {
    variables = var.environment_variables
  }
  
  dead_letter_config {
    target_arn = aws_sqs_queue.dlq.arn
  }
  
  # reserved_concurrency = var.reserved_concurrency
  
  tags = var.tags
}

resource "aws_lambda_alias" "live" {
  name             = "live"
  description      = "Live alias for production traffic"
  function_name    = aws_lambda_function.main.function_name
  function_version = "$LATEST"
}

# Lambda execution role
resource "aws_iam_role" "lambda_execution" {
  name = "${var.function_name}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_xray_write_only" {
  count      = var.enable_xray_tracing ? 1 : 0
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# Dead letter queue
resource "aws_sqs_queue" "dlq" {
  name = "${var.function_name}-dlq"
  
  message_retention_seconds = 1209600 # 14 days
  
  tags = var.tags
}

resource "aws_iam_role_policy" "lambda_dlq_policy" {
  name = "${var.function_name}-dlq-policy"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.dlq.arn
      }
    ]
  })
}

# Code signing configuration (if provided)
resource "aws_lambda_code_signing_config" "main" {
  count = var.code_signing_profile_arn != "" ? 1 : 0
  
  allowed_publishers {
    signing_profile_version_arns = [var.code_signing_profile_arn]
  }

  policies {
    untrusted_artifact_on_deployment = "Enforce"
  }

  description = "Code signing config for ${var.function_name}"
  
  tags = var.tags
}