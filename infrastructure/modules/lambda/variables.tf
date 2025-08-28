variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "environment" {
  description = "Environment name (staging/production)"
  type        = string
}

variable "deployment_package" {
  description = "Path to the deployment package zip file"
  type        = string
}

variable "reserved_concurrency" {
  description = "Reserved concurrency for the Lambda function"
  type        = number
  default     = null
}

variable "environment_variables" {
  description = "Environment variables for the Lambda function"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}

variable "memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 256
}

variable "enable_xray_tracing" {
  description = "Enable X-Ray tracing for Lambda function"
  type        = bool
  default     = true
}

variable "code_signing_config_arn" {
  description = "ARN of the code signing configuration"
  type        = string
  default     = ""
}

variable "code_signing_profile_arn" {
  description = "ARN of the AWS Signer profile for code signing"
  type        = string
  default     = ""
}

variable "adopt_existing_resources" {
  description = "Whether to adopt existing AWS resources instead of creating new ones"
  type        = bool
  default     = true
}