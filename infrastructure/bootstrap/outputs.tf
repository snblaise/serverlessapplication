# Outputs for bootstrap infrastructure

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = try(data.aws_iam_openid_connect_provider.github.arn, aws_iam_openid_connect_provider.github[0].arn)
}

output "github_actions_staging_role_arn" {
  description = "ARN of the GitHub Actions staging role"
  value       = aws_iam_role.github_actions_staging.arn
}

output "github_actions_production_role_arn" {
  description = "ARN of the GitHub Actions production role"
  value       = aws_iam_role.github_actions_production.arn
}

output "github_actions_security_scan_role_arn" {
  description = "ARN of the GitHub Actions security scan role"
  value       = aws_iam_role.github_actions_security_scan.arn
}

output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS Region"
  value       = data.aws_region.current.name
}