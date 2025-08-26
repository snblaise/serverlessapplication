# GitHub Actions Setup Guide

This guide explains how to set up the GitHub Actions CI/CD pipeline for the Lambda serverless application.

## Prerequisites

Before running the GitHub Actions workflow, you need to configure AWS credentials as GitHub repository secrets.

## Required GitHub Secrets

The workflow requires the following secrets to be configured in your GitHub repository:

### 1. AWS Access Keys (for Bootstrap)

These are used only for the initial bootstrap step to create OIDC roles:

- `AWS_ACCESS_KEY_ID` - AWS Access Key ID with administrative permissions
- `AWS_SECRET_ACCESS_KEY` - AWS Secret Access Key

### 2. AWS Account Information (Optional)

- `AWS_ACCOUNT_ID_STAGING` - AWS Account ID for staging (optional)
- `AWS_ACCOUNT_ID_PROD` - AWS Account ID for production (optional)

## How to Add Secrets

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret with the exact name and value

## Workflow Process

The GitHub Actions workflow follows this process:

### 1. Bootstrap Infrastructure (Automatic)

The workflow automatically:
- Creates GitHub OIDC provider in AWS (if it doesn't exist)
- Creates IAM roles for staging, production, and security scanning
- Configures trust relationships for GitHub Actions
- Tests OIDC authentication

### 2. Application Deployment

After bootstrap completes, the workflow:
- Uses OIDC authentication for all subsequent steps
- Deploys infrastructure using Terraform
- Builds and deploys the Lambda function
- Runs security scans and tests
- Supports both staging and production environments

## Running the Workflow

### Automatic Triggers

The workflow runs automatically on:
- Push to `main` branch (deploys to production)
- Push to `develop` branch (deploys to staging)
- Pull requests to `main` branch (runs tests only)

### Manual Triggers

You can manually trigger the workflow:

```bash
# Deploy to staging
gh workflow run "Lambda CI/CD Pipeline" --field environment=staging

# Deploy to production
gh workflow run "Lambda CI/CD Pipeline" --field environment=production

# Force bootstrap (if needed)
gh workflow run "Lambda CI/CD Pipeline" --field environment=staging --field force_bootstrap=true
```

## Troubleshooting

### Bootstrap Fails

If the bootstrap step fails:

1. **Check AWS Credentials**: Ensure `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are correctly set
2. **Check Permissions**: The AWS user must have administrative permissions to create IAM roles and OIDC providers
3. **Check Region**: The workflow uses `us-east-1` by default

### OIDC Authentication Fails

If OIDC authentication fails after bootstrap:

1. **Wait**: OIDC roles may take a few minutes to propagate
2. **Check Trust Policy**: Ensure the repository name in the trust policy matches your repository
3. **Re-run Bootstrap**: Use the `force_bootstrap=true` option

### Infrastructure Deployment Fails

If Terraform deployment fails:

1. **Check Resources**: Ensure no conflicting resources exist in AWS
2. **Check Permissions**: Ensure the OIDC roles have sufficient permissions
3. **Check State**: Terraform state is managed automatically by the workflow

## Security Considerations

- **Access Keys**: Only used for initial bootstrap, not for regular operations
- **OIDC Roles**: Scoped to specific GitHub repository and environments
- **Least Privilege**: Each role has minimal required permissions
- **Temporary Credentials**: OIDC provides temporary, rotating credentials

## Architecture

```
GitHub Actions Workflow
├── Bootstrap (AWS Access Keys)
│   ├── Create OIDC Provider
│   ├── Create IAM Roles
│   └── Test OIDC Authentication
├── Setup (OIDC Authentication)
│   └── Environment Configuration
├── Security Scan (OIDC)
├── Build & Package (OIDC)
├── Deploy Infrastructure (OIDC)
├── Deploy Application (OIDC)
└── Rollback (OIDC, if needed)
```

## Next Steps

After setup is complete:

1. The workflow will run automatically on code changes
2. Monitor deployments in the GitHub Actions tab
3. Check AWS resources in the AWS Console
4. Review security scan results in GitHub Security tab

For more information, see:
- [CI/CD Pipeline Documentation](CICD_PIPELINE.md)
- [GitHub OIDC Setup](GITHUB_OIDC_SETUP.md)
- [Staging to Production Workflow](STAGING_TO_PRODUCTION_WORKFLOW.md)