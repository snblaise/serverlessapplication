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
      Environment = "bootstrap"
      ManagedBy   = "terraform"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Check if GitHub OIDC provider already exists
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# GitHub OIDC Provider (only create if it doesn't exist)
resource "aws_iam_openid_connect_provider" "github" {
  count = length(data.aws_iam_openid_connect_provider.github.arn) > 0 ? 0 : 1
  
  url = "https://token.actions.githubusercontent.com"
  
  client_id_list = [
    "sts.amazonaws.com"
  ]
  
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]
  
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      url,
      client_id_list,
      thumbprint_list
    ]
  }
  
  tags = {
    Name        = "GitHub Actions OIDC Provider"
    Environment = "bootstrap"
    Project     = "lambda-production-readiness"
  }
}

# IAM Role for GitHub Actions - Staging Environment
resource "aws_iam_role" "github_actions_staging" {
  name = "GitHubActions-Lambda-Staging"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = try(data.aws_iam_openid_connect_provider.github.arn, aws_iam_openid_connect_provider.github[0].arn)
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:*"
          }
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

  tags = {
    Environment = "staging"
    Project     = "lambda-production-readiness"
  }
}

# IAM Role for GitHub Actions - Production Environment
resource "aws_iam_role" "github_actions_production" {
  name = "GitHubActions-Lambda-Production"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = try(data.aws_iam_openid_connect_provider.github.arn, aws_iam_openid_connect_provider.github[0].arn)
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:*"
          }
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

  tags = {
    Environment = "production"
    Project     = "lambda-production-readiness"
  }
}

# IAM Role for Security Scanning
resource "aws_iam_role" "github_actions_security_scan" {
  name = "GitHubActions-SecurityScan"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = try(data.aws_iam_openid_connect_provider.github.arn, aws_iam_openid_connect_provider.github[0].arn)
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:*"
          }
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

  tags = {
    Environment = "security"
    Project     = "lambda-production-readiness"
  }
}

# Comprehensive IAM Policy for Staging Environment
resource "aws_iam_role_policy" "github_actions_staging_policy" {
  name = "GitHubActions-Lambda-staging-Policy"
  role = aws_iam_role.github_actions_staging.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Lambda permissions
      {
        Effect = "Allow"
        Action = [
          "lambda:*"
        ]
        Resource = [
          "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:*staging*",
          "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:lambda_function_staging*"
        ]
      },
      # S3 permissions for artifacts
      {
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = [
          "arn:aws:s3:::*staging*",
          "arn:aws:s3:::*staging*/*",
          "arn:aws:s3:::lambda-artifacts-staging*",
          "arn:aws:s3:::lambda-artifacts-staging*/*"
        ]
      },
      # IAM permissions for creating/managing roles
      {
        Effect = "Allow"
        Action = [
          "iam:*"
        ]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*staging*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/lambda*staging*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/codebuild*staging*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/codepipeline*staging*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/cloudformation*staging*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/CodeDeploy*staging*"
        ]
      },
      # IAM read permissions
      {
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:GetOpenIDConnectProvider",
          "iam:ListOpenIDConnectProviders"
        ]
        Resource = "*"
      },
      # CodeDeploy permissions
      {
        Effect = "Allow"
        Action = [
          "codedeploy:*"
        ]
        Resource = "*"
      },
      # CodeBuild permissions
      {
        Effect = "Allow"
        Action = [
          "codebuild:*"
        ]
        Resource = "*"
      },
      # CodePipeline permissions
      {
        Effect = "Allow"
        Action = [
          "codepipeline:*"
        ]
        Resource = "*"
      },
      # CloudFormation permissions
      {
        Effect = "Allow"
        Action = [
          "cloudformation:*"
        ]
        Resource = "*"
      },
      # CloudWatch permissions
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:*",
          "logs:*"
        ]
        Resource = "*"
      },
      # SNS permissions
      {
        Effect = "Allow"
        Action = [
          "sns:*"
        ]
        Resource = [
          "arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*staging*"
        ]
      },
      # SQS permissions
      {
        Effect = "Allow"
        Action = [
          "sqs:*"
        ]
        Resource = [
          "arn:aws:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*staging*"
        ]
      },
      # KMS permissions
      {
        Effect = "Allow"
        Action = [
          "kms:*"
        ]
        Resource = "*"
      },
      # Events permissions
      {
        Effect = "Allow"
        Action = [
          "events:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Policy for Production Environment (similar but for production resources)
resource "aws_iam_role_policy" "github_actions_production_policy" {
  name = "GitHubActions-Lambda-production-Policy"
  role = aws_iam_role.github_actions_production.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Lambda permissions
      {
        Effect = "Allow"
        Action = [
          "lambda:*"
        ]
        Resource = [
          "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:*production*",
          "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:lambda_function_production*"
        ]
      },
      # S3 permissions for artifacts
      {
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = [
          "arn:aws:s3:::*production*",
          "arn:aws:s3:::*production*/*",
          "arn:aws:s3:::lambda-artifacts-production*",
          "arn:aws:s3:::lambda-artifacts-production*/*"
        ]
      },
      # IAM permissions for creating/managing roles
      {
        Effect = "Allow"
        Action = [
          "iam:*"
        ]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*production*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/lambda*production*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/codebuild*production*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/codepipeline*production*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/cloudformation*production*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/CodeDeploy*production*"
        ]
      },
      # IAM read permissions
      {
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:GetOpenIDConnectProvider",
          "iam:ListOpenIDConnectProviders"
        ]
        Resource = "*"
      },
      # CodeDeploy permissions
      {
        Effect = "Allow"
        Action = [
          "codedeploy:*"
        ]
        Resource = "*"
      },
      # CodeBuild permissions
      {
        Effect = "Allow"
        Action = [
          "codebuild:*"
        ]
        Resource = "*"
      },
      # CodePipeline permissions
      {
        Effect = "Allow"
        Action = [
          "codepipeline:*"
        ]
        Resource = "*"
      },
      # CloudFormation permissions
      {
        Effect = "Allow"
        Action = [
          "cloudformation:*"
        ]
        Resource = "*"
      },
      # CloudWatch permissions
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:*",
          "logs:*"
        ]
        Resource = "*"
      },
      # SNS permissions
      {
        Effect = "Allow"
        Action = [
          "sns:*"
        ]
        Resource = [
          "arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*production*"
        ]
      },
      # SQS permissions
      {
        Effect = "Allow"
        Action = [
          "sqs:*"
        ]
        Resource = [
          "arn:aws:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*production*"
        ]
      },
      # KMS permissions
      {
        Effect = "Allow"
        Action = [
          "kms:*"
        ]
        Resource = "*"
      },
      # Events permissions
      {
        Effect = "Allow"
        Action = [
          "events:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Policy for Security Scanning
resource "aws_iam_role_policy" "github_actions_security_scan_policy" {
  name = "GitHubActions-SecurityScan-Policy"
  role = aws_iam_role.github_actions_security_scan.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
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
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/github-actions/security-scan*"
      }
    ]
  })
}