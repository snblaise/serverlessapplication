variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (staging/production)"
  type        = string
  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "Environment must be either 'staging' or 'production'."
  }
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "code_signing_profile_arn" {
  description = "ARN of the AWS Signer profile for code signing"
  type        = string
  default     = ""
}

variable "enable_xray_tracing" {
  description = "Enable X-Ray tracing for Lambda function"
  type        = bool
  default     = true
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
  validation {
    condition     = var.lambda_timeout >= 1 && var.lambda_timeout <= 900
    error_message = "Lambda timeout must be between 1 and 900 seconds."
  }
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 256
  validation {
    condition     = var.lambda_memory_size >= 128 && var.lambda_memory_size <= 10240
    error_message = "Lambda memory size must be between 128 and 10240 MB."
  }
}

variable "enable_manual_approval" {
  description = "Enable manual approval for production deployments"
  type        = bool
  default     = true
}

variable "notification_email" {
  description = "Email address for Lambda function notifications"
  type        = string
  default     = ""
}

variable "github_repository" {
  description = "GitHub repository in the format 'owner/repo' for OIDC trust policy"
  type        = string
  default     = ""
}