# Bootstrap Infrastructure Guide

This guide explains the bootstrap infrastructure deployment process for the Lambda CI/CD pipeline.

## Overview

The bootstrap infrastructure creates the foundational AWS resources needed for GitHub Actions to authenticate securely using OIDC (OpenID Connect). This is a one-time setup that must be completed before running the main CI/CD pipeline.

## What Gets Created

The bootstrap deployment creates:

1. **GitHub OIDC Provider**: Allows GitHub Actions to authenticate with AWS
2. **IAM Roles**: Three roles with specific permissions:
   - `GitHubActions-StagingRole`: For staging deployments
   - `GitHubActions-ProductionRole`: For production deployments  
   - `GitHubActions-SecurityScanRole`: For security scanning operations
3. **Trust Policies**: Configure which GitHub repositories can assume the roles

## Prerequisites

Before running the bootstrap deployment:

- AWS CLI installed and configured with admin permissions
- Terraform 1.5.0+ installed
- Access to the target AWS account

## Deployment Steps

### 1. Run Bootstrap Script

```bash
./scripts/deploy-bootstrap.sh
```

This script will:
- Check prerequisites (AWS CLI, Terraform)
- Verify if OIDC provider already exists
- Deploy the bootstrap infrastructure using Terraform
- Display the created role ARNs
- Test the OIDC authentication setup

### 2. Configure GitHub Secrets

After bootstrap deployment, add your AWS Account ID to GitHub secrets:

```bash
# Set the AWS_ACCOUNT_ID secret (required for role ARN construction)
gh secret set AWS_ACCOUNT_ID --body "123456789012"
```

Or use the automated script:

```bash
./scripts/setup-github-secrets.sh
```

### 3. Verify Setup

The workflow will automatically construct role ARNs using this pattern:
- Staging: `arn:aws:iam::ACCOUNT_ID:role/GitHubActions-StagingRole`
- Production: `arn:aws:iam::ACCOUNT_ID:role/GitHubActions-ProductionRole`
- Security Scan: `arn:aws:iam::ACCOUNT_ID:role/GitHubActions-SecurityScanRole`

## Manual Deployment (Alternative)

If you prefer to deploy manually:

```bash
# Navigate to bootstrap directory
cd infrastructure/bootstrap

# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Apply changes
terraform apply
```

## Troubleshooting

### OIDC Provider Already Exists

If you see this warning:
```
GitHub OIDC provider already exists
```

This is normal if you've used GitHub Actions OIDC with this AWS account before. The script will update the roles while keeping the existing provider.

### Permission Errors

Ensure your AWS credentials have the following permissions:
- `iam:CreateOpenIDConnectProvider`
- `iam:CreateRole`
- `iam:AttachRolePolicy`
- `iam:CreatePolicy`

### Role ARN Not Found

If the workflow fails with "role ARN not found":
1. Verify bootstrap deployment completed successfully
2. Check that `AWS_ACCOUNT_ID` secret is set correctly
3. Ensure role names match the expected pattern

## Security Considerations

- Bootstrap uses your AWS credentials for initial setup only
- GitHub Actions workflow uses temporary OIDC credentials
- Roles follow least-privilege principle
- Trust policies restrict access to your specific repository

## Cleanup

To remove bootstrap infrastructure:

```bash
cd infrastructure/bootstrap
terraform destroy
```

**Warning**: This will break the GitHub Actions workflow until redeployed.

## Next Steps

After successful bootstrap deployment:
1. Run the GitHub Actions workflow
2. Monitor deployment in AWS Console
3. Review created resources and permissions
4. Test the deployed Lambda function

For more information, see:
- [GitHub Actions Setup Guide](GITHUB_ACTIONS_SETUP.md)
- [CI/CD Pipeline Documentation](CICD_PIPELINE.md)
- [Implementation Guide](IMPLEMENTATION_GUIDE.md)