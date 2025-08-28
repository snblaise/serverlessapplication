# CodeDeploy service role
resource "aws_iam_role" "codedeploy_service_role" {
  count = local.codedeploy_role_exists ? 0 : 1
  name  = "CodeDeployServiceRole-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codedeploy.amazonaws.com"
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
    Environment = var.environment
    Project     = "lambda-production-readiness"
  }
}

resource "aws_iam_role_policy_attachment" "codedeploy_service_role" {
  count      = local.codedeploy_role_exists ? 0 : 1
  role       = aws_iam_role.codedeploy_service_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRoleForLambda"
}