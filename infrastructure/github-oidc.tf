# GitHub OIDC Provider and IAM Roles for GitHub Actions
# This enables GitHub Actions to assume AWS roles without storing credentials

# Get existing GitHub OIDC provider
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# Local values for configuration
locals {
  github_oidc_provider_arn = data.aws_iam_openid_connect_provider.github.arn
  
  # Default repository if not provided
  github_repository = var.github_repository != "" ? var.github_repository : "snblaise/serverlessapplication"
}

# IAM role for GitHub Actions (staging)
resource "aws_iam_role" "github_actions_staging" {
  count = var.environment == "staging" ? 1 : 0
  name  = "GitHubActions-Lambda-Staging"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.github_oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:${local.github_repository}:*"
            ]
          }
        }
      }
    ]
  })

  tags = {
    Environment = "staging"
    Project     = "lambda-production-ready"
    ManagedBy   = "terraform"
  }
}

# IAM role for GitHub Actions (production)
resource "aws_iam_role" "github_actions_production" {
  count = var.environment == "production" ? 1 : 0
  name  = "GitHubActions-Lambda-Production"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.github_oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:${local.github_repository}:*"
            ]
          }
        }
      }
    ]
  })

  tags = {
    Environment = "production"
    Project     = "lambda-production-ready"
    ManagedBy   = "terraform"
  }
}

# IAM policy for GitHub Actions (common permissions)
resource "aws_iam_role_policy" "github_actions_policy" {
  count = var.environment == "staging" ? 1 : (var.environment == "production" ? 1 : 0)
  name  = "GitHubActions-Lambda-${var.environment}-Policy"
  role  = var.environment == "staging" ? aws_iam_role.github_actions_staging[0].id : aws_iam_role.github_actions_production[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Lambda permissions
      {
        Effect = "Allow"
        Action = [
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:PublishVersion",
          "lambda:CreateAlias",
          "lambda:UpdateAlias",
          "lambda:GetAlias",
          "lambda:ListVersionsByFunction",
          "lambda:ListAliases"
        ]
        Resource = [
          "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:lambda-function-${var.environment}",
          "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:lambda-function-${var.environment}:*"
        ]
      },
      # S3 permissions for artifacts
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::lambda-artifacts-${var.environment}",
          "arn:aws:s3:::lambda-artifacts-${var.environment}/*"
        ]
      },
      # CodeDeploy permissions
      {
        Effect = "Allow"
        Action = [
          "codedeploy:CreateDeployment",
          "codedeploy:GetApplication",
          "codedeploy:GetApplicationRevision",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:RegisterApplicationRevision",
          "codedeploy:ListDeploymentConfigs",
          "codedeploy:ListApplications",
          "codedeploy:ListDeployments"
        ]
        Resource = "*"
      },
      # CloudWatch Logs permissions
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/lambda-function-${var.environment}*"
      },
      # CloudWatch metrics and alarms
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "cloudwatch:DescribeAlarms"
        ]
        Resource = "*"
      },
      # X-Ray permissions
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      },
      # Security Hub permissions (for security scan results)
      {
        Effect = "Allow"
        Action = [
          "securityhub:BatchImportFindings",
          "securityhub:DescribeHub",
          "securityhub:GetFindings",
          "securityhub:EnableSecurityHub"
        ]
        Resource = "*"
      },
      # Code Signing permissions (optional)
      {
        Effect = "Allow"
        Action = [
          "signer:PutSigningProfile",
          "signer:GetSigningProfile",
          "signer:StartSigningJob",
          "signer:DescribeSigningJob"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      },
      # IAM permissions for role passing and OIDC provider access
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/lambda-function-${var.environment}-execution-role",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/CodeDeployServiceRole-${var.environment}"
        ]
      },
      # IAM permissions for infrastructure deployment (Terraform data sources)
      {
        Effect = "Allow"
        Action = [
          "iam:ListOpenIDConnectProviders",
          "iam:GetOpenIDConnectProvider",
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM role for GitHub Actions Security Scanning
resource "aws_iam_role" "github_actions_security_scan" {
  count = var.environment == "staging" || var.environment == "production" ? 1 : 0
  name  = "GitHubActions-SecurityScan"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.github_oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:${local.github_repository}:*"
            ]
          }
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    Project     = "lambda-production-ready"
    ManagedBy   = "terraform"
    Purpose     = "security-scanning"
  }
}

# IAM policy for Security Scanning role
resource "aws_iam_role_policy" "github_actions_security_scan_policy" {
  count = var.environment == "staging" || var.environment == "production" ? 1 : 0
  name  = "GitHubActions-SecurityScan-Policy"
  role  = aws_iam_role.github_actions_security_scan[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Security Hub permissions
      {
        Effect = "Allow"
        Action = [
          "securityhub:BatchImportFindings",
          "securityhub:DescribeHub",
          "securityhub:GetFindings",
          "securityhub:EnableSecurityHub",
          "securityhub:GetEnabledStandards",
          "securityhub:BatchUpdateFindings"
        ]
        Resource = "*"
      },
      # CloudWatch Logs for security scan logs
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/github-actions/security-scan*"
      }
    ]
  })
}

# Output the role ARNs for GitHub secrets configuration
output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions IAM role"
  value = var.environment == "staging" ? (
    length(aws_iam_role.github_actions_staging) > 0 ? aws_iam_role.github_actions_staging[0].arn : null
  ) : (
    length(aws_iam_role.github_actions_production) > 0 ? aws_iam_role.github_actions_production[0].arn : null
  )
}

output "aws_account_id" {
  description = "AWS Account ID for GitHub secrets"
  value       = data.aws_caller_identity.current.account_id
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = local.github_oidc_provider_arn
}

output "github_actions_security_scan_role_arn" {
  description = "ARN of the GitHub Actions Security Scan IAM role"
  value = length(aws_iam_role.github_actions_security_scan) > 0 ? aws_iam_role.github_actions_security_scan[0].arn : null
}