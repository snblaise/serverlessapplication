# Variables for bootstrap infrastructure

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "github_repository" {
  description = "GitHub repository in the format 'owner/repo'"
  type        = string
  default     = "snblaise/serverlessapplication"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "lambda-production-readiness"
}