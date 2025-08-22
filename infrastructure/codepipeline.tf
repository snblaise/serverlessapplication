# AWS CodePipeline for Lambda function CI/CD
# Integrates CodeBuild compilation with deployment pipeline

resource "aws_codepipeline" "lambda_pipeline" {
  name     = "lambda-function-${var.environment}-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.lambda_artifacts.bucket
    type     = "S3"

    encryption_key {
      id   = aws_kms_key.pipeline_key.arn
      type = "KMS"
    }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        S3Bucket    = aws_s3_bucket.lambda_artifacts.bucket
        S3ObjectKey = "source/source.zip"
        PollForSourceChanges = false
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.lambda_build.name
        EnvironmentVariables = jsonencode([
          {
            name  = "ENVIRONMENT"
            value = var.environment
          },
          {
            name  = "AWS_DEFAULT_REGION"
            value = var.aws_region
          },
          {
            name  = "ARTIFACTS_BUCKET"
            value = aws_s3_bucket.lambda_artifacts.bucket
          }
        ])
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "CreateChangeSet"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CloudFormation"
      input_artifacts = ["build_output"]
      version         = "1"
      run_order       = 1

      configuration = {
        ActionMode     = "CHANGE_SET_REPLACE"
        Capabilities   = "CAPABILITY_IAM"
        ChangeSetName  = "lambda-changeset-${var.environment}"
        RoleArn        = aws_iam_role.cloudformation_role.arn
        StackName      = "lambda-function-${var.environment}"
        TemplatePath   = "build_output::lambda-deployment-template.yaml"
        ParameterOverrides = jsonencode({
          Environment    = var.environment
          FunctionName   = "lambda-function-${var.environment}"
          PackageKey     = "builds/lambda-function.zip"
          BucketName     = aws_s3_bucket.lambda_artifacts.bucket
        })
      }
    }

    action {
      name            = "ExecuteChangeSet"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CloudFormation"
      version         = "1"
      run_order       = 2

      configuration = {
        ActionMode    = "CHANGE_SET_EXECUTE"
        ChangeSetName = "lambda-changeset-${var.environment}"
        StackName     = "lambda-function-${var.environment}"
      }
    }
  }

  # Optional: Manual approval for production
  dynamic "stage" {
    for_each = var.environment == "production" ? [1] : []
    content {
      name = "ManualApproval"

      action {
        name     = "ManualApproval"
        category = "Approval"
        owner    = "AWS"
        provider = "Manual"
        version  = "1"
        run_order = 1

        configuration = {
          NotificationArn = aws_sns_topic.pipeline_notifications.arn
          CustomData      = "Please review the deployment to ${var.environment} environment"
        }
      }
    }
  }

  # Integration testing stage
  stage {
    name = "IntegrationTest"

    action {
      name             = "IntegrationTest"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["build_output"]
      output_artifacts = ["test_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.lambda_integration_test.name
        EnvironmentVariables = jsonencode([
          {
            name  = "ENVIRONMENT"
            value = var.environment
          },
          {
            name  = "FUNCTION_NAME"
            value = "lambda-function-${var.environment}"
          }
        ])
      }
    }
  }

  tags = {
    Environment = var.environment
    Project     = "lambda-production-ready"
    ManagedBy   = "terraform"
  }
}

# CodeBuild project for integration testing
resource "aws_codebuild_project" "lambda_integration_test" {
  name          = "lambda-function-${var.environment}-integration-test"
  description   = "Integration tests for Lambda function in ${var.environment} environment"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                      = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                       = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "ENVIRONMENT"
      value = var.environment
    }

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }
  }

  source {
    type = "CODEPIPELINE"
    buildspec = "buildspec-integration-test.yml"
  }

  tags = {
    Environment = var.environment
    Project     = "lambda-production-ready"
    ManagedBy   = "terraform"
  }
}

# IAM role for CodePipeline
resource "aws_iam_role" "codepipeline_role" {
  name = "codepipeline-lambda-${var.environment}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for CodePipeline
resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "codepipeline-lambda-${var.environment}-policy"
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketVersioning",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.lambda_artifacts.arn,
          "${aws_s3_bucket.lambda_artifacts.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        Resource = [
          aws_codebuild_project.lambda_build.arn,
          aws_codebuild_project.lambda_integration_test.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudformation:CreateStack",
          "cloudformation:DeleteStack",
          "cloudformation:DescribeStacks",
          "cloudformation:UpdateStack",
          "cloudformation:CreateChangeSet",
          "cloudformation:DeleteChangeSet",
          "cloudformation:DescribeChangeSet",
          "cloudformation:ExecuteChangeSet",
          "cloudformation:SetStackPolicy",
          "cloudformation:ValidateTemplate"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = aws_iam_role.cloudformation_role.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.pipeline_notifications.arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.pipeline_key.arn
      }
    ]
  })
}

# IAM role for CloudFormation
resource "aws_iam_role" "cloudformation_role" {
  name = "cloudformation-lambda-${var.environment}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "cloudformation.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for CloudFormation
resource "aws_iam_role_policy" "cloudformation_policy" {
  name = "cloudformation-lambda-${var.environment}-policy"
  role = aws_iam_role.cloudformation_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:*",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:PassRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:PutRetentionPolicy",
          "s3:GetObject",
          "codedeploy:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# KMS key for pipeline encryption
resource "aws_kms_key" "pipeline_key" {
  description             = "KMS key for Lambda pipeline ${var.environment}"
  deletion_window_in_days = 7

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CodePipeline to use the key"
        Effect = "Allow"
        Principal = {
          Service = [
            "codepipeline.amazonaws.com",
            "codebuild.amazonaws.com"
          ]
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Environment = var.environment
    Project     = "lambda-production-ready"
    ManagedBy   = "terraform"
  }
}

# KMS key alias
resource "aws_kms_alias" "pipeline_key_alias" {
  name          = "alias/lambda-pipeline-${var.environment}"
  target_key_id = aws_kms_key.pipeline_key.key_id
}

# SNS topic for pipeline notifications
resource "aws_sns_topic" "pipeline_notifications" {
  name = "lambda-pipeline-${var.environment}-notifications"

  tags = {
    Environment = var.environment
    Project     = "lambda-production-ready"
    ManagedBy   = "terraform"
  }
}

# CloudWatch Event Rule for pipeline state changes
resource "aws_cloudwatch_event_rule" "pipeline_state_change" {
  name        = "lambda-pipeline-${var.environment}-state-change"
  description = "Capture pipeline state changes"

  event_pattern = jsonencode({
    source      = ["aws.codepipeline"]
    detail-type = ["CodePipeline Pipeline Execution State Change"]
    detail = {
      pipeline = [aws_codepipeline.lambda_pipeline.name]
    }
  })
}

# CloudWatch Event Target for SNS
resource "aws_cloudwatch_event_target" "sns" {
  rule      = aws_cloudwatch_event_rule.pipeline_state_change.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.pipeline_notifications.arn
}

# Outputs
output "pipeline_name" {
  description = "Name of the CodePipeline"
  value       = aws_codepipeline.lambda_pipeline.name
}

output "pipeline_arn" {
  description = "ARN of the CodePipeline"
  value       = aws_codepipeline.lambda_pipeline.arn
}

output "pipeline_url" {
  description = "Console URL for the CodePipeline"
  value       = "https://${var.aws_region}.console.aws.amazon.com/codesuite/codepipeline/pipelines/${aws_codepipeline.lambda_pipeline.name}/view"
}