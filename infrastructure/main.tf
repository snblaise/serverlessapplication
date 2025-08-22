terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
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
  
  function_name        = var.lambda_function_name
  environment         = var.environment
  deployment_package  = "../lambda-function.zip"
  reserved_concurrency = var.environment == "production" ? 100 : 50
  
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
  compute_platform = "Lambda"
  name             = "lambda-app-${var.environment}"
  
  tags = {
    Environment = var.environment
    Project     = "lambda-production-readiness"
  }
}

# CodeDeploy deployment group
resource "aws_codedeploy_deployment_group" "lambda_deployment_group" {
  app_name              = aws_codedeploy_app.lambda_app.name
  deployment_group_name = "lambda-deployment-group"
  service_role_arn      = aws_iam_role.codedeploy_service_role.arn
  
  deployment_config_name = var.environment == "production" ? "CodeDeployDefault.LambdaCanary10Percent10Minutes" : "CodeDeployDefault.LambdaCanary10Percent5Minutes"
  
  deployment_style {
    deployment_type   = "BLUE_GREEN"
    deployment_option = "WITH_TRAFFIC_CONTROL"
  }
  
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
  }
  
  tags = {
    Environment = var.environment
    Project     = "lambda-production-readiness"
  }
}

# S3 bucket for deployment artifacts
resource "aws_s3_bucket" "lambda_artifacts" {
  bucket = "lambda-artifacts-${var.environment}-${random_id.bucket_suffix.hex}"
  
  tags = {
    Environment = var.environment
    Project     = "lambda-production-readiness"
  }
}

resource "aws_s3_bucket_versioning" "lambda_artifacts" {
  bucket = aws_s3_bucket.lambda_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "lambda_artifacts" {
  bucket = aws_s3_bucket.lambda_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}