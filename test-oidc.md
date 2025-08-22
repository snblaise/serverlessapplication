# OIDC Test

This file is created to test the GitHub OIDC integration.

- ✅ OIDC Provider: Created
- ✅ IAM Role: GitHubActions-Lambda-Staging
- ✅ GitHub Secrets: AWS_ACCOUNT_ID_STAGING set
- ✅ Trust Policy: Configured for snblaise/serverlessapplication

The next GitHub Actions run should successfully authenticate with AWS using OIDC instead of stored credentials.

Created at: $(date)