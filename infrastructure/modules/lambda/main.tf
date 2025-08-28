resource "aws_lambda_function" "main" {
  function_name = var.function_name
  role         = local.lambda_role_arn
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
    target_arn = local.dlq_arn
  }
  
  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash
    ]
  }
  
  # reserved_concurrency = var.reserved_concurrency
  
  tags = var.tags
}

resource "aws_lambda_alias" "live" {
  name             = "live"
  description      = "Live alias for production traffic"
  function_name    = aws_lambda_function.main.function_name
  function_version = "$LATEST"
  
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      name,
      description
    ]
  }
}

locals {
  # Use adoption script to import existing resources instead of data sources
  lambda_role_exists = false  # Will be imported by adoption script if exists
  lambda_role_arn    = aws_iam_role.lambda_execution[0].arn
}

# Lambda execution role
resource "aws_iam_role" "lambda_execution" {
  count = local.lambda_role_exists ? 0 : 1
  name  = "${var.function_name}-execution-role"

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

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      name,
      assume_role_policy
    ]
  }

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  count      = local.lambda_role_exists ? 0 : 1
  role       = aws_iam_role.lambda_execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_xray_write_only" {
  count      = var.enable_xray_tracing && !local.lambda_role_exists ? 1 : 0
  role       = aws_iam_role.lambda_execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

locals {
  # Use adoption script to import existing resources instead of data sources  
  dlq_exists = false  # Will be imported by adoption script if exists
  dlq_arn    = aws_sqs_queue.dlq[0].arn
}

# Dead letter queue
resource "aws_sqs_queue" "dlq" {
  count = local.dlq_exists ? 0 : 1
  name  = "${var.function_name}-dlq"
  
  message_retention_seconds = 1209600 # 14 days
  
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      name
    ]
  }
  
  tags = var.tags
}

resource "aws_iam_role_policy" "lambda_dlq_policy" {
  count = local.lambda_role_exists ? 0 : 1
  name  = "${var.function_name}-dlq-policy"
  role  = aws_iam_role.lambda_execution[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = local.dlq_arn
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