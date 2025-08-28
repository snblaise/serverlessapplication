terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "lambda-production-readiness"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Lambda function module
module "lambda_function" {
  source = "./modules/lambda"
  
  function_name           = var.lambda_function_name
  environment            = var.environment
  deployment_package     = "../lambda-function.zip"
  reserved_concurrency   = var.environment == "production" ? 100 : 50
  adopt_existing_resources = var.adopt_existing_resources
  
  environment_variables = {
    NODE_ENV    = var.environment
    LOG_LEVEL   = var.environment == "production" ? "info" : "debug"
    ENVIRONMENT = var.environment
  }
  
  tags = {
    Environment = var.environment
    Project     = "lambda-production-readiness"
  }
}

# CodeDeploy application for canary deployments
resource "aws_codedeploy_app" "lambda_app" {
  count            = local.codedeploy_app_exists ? 0 : 1
  compute_platform = "Lambda"
  name             = "lambda-app-${var.environment}"
  
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      name,
      compute_platform
    ]
  }
  
  tags = {
    Environment = var.environment
    Project     = "lambda-production-readiness"
  }
}

# CodeDeploy deployment group
resource "aws_codedeploy_deployment_group" "lambda_deployment_group" {
  app_name              = local.codedeploy_app_name
  deployment_group_name = "lambda-deployment-group"
  service_role_arn      = local.codedeploy_role_arn
  
  deployment_config_name = var.environment == "production" ? "CodeDeployDefault.LambdaCanary10Percent10Minutes" : "CodeDeployDefault.LambdaCanary10Percent5Minutes"
  
  deployment_style {
    deployment_type   = "BLUE_GREEN"
    deployment_option = "WITH_TRAFFIC_CONTROL"
  }
  
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
  }
  
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      deployment_group_name,
      deployment_config_name
    ]
  }
  
  tags = {
    Environment = var.environment
    Project     = "lambda-production-readiness"
  }
}

# S3 bucket for deployment artifacts with static unique name
resource "aws_s3_bucket" "lambda_artifacts" {
  count         = local.s3_bucket_exists ? 0 : 1
  bucket        = "lambda-artifacts-${var.environment}-snblaise-serverless-2025"
  force_destroy = var.environment != "production"
  
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      bucket,
      force_destroy
    ]
  }
  
  tags = {
    Environment = var.environment
    Project     = "lambda-production-readiness"
  }
}

resource "aws_s3_bucket_versioning" "lambda_artifacts" {
  count  = local.s3_bucket_exists ? 0 : 1
  bucket = aws_s3_bucket.lambda_artifacts[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "lambda_artifacts" {
  count  = local.s3_bucket_exists ? 0 : 1
  bucket = aws_s3_bucket.lambda_artifacts[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "lambda_artifacts" {
  count  = local.s3_bucket_exists ? 0 : 1
  bucket = aws_s3_bucket.lambda_artifacts[0].id

  rule {
    id     = "cleanup_old_versions"
    status = "Enabled"

    filter {
      prefix = ""
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_public_access_block" "lambda_artifacts" {
  count  = local.s3_bucket_exists ? 0 : 1
  bucket = aws_s3_bucket.lambda_artifacts[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}