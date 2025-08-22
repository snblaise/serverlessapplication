# GitHub Secrets Setup for OIDC Authentication

This guide explains how to set up GitHub secrets for secure OIDC authentication with AWS.

## 🔐 Required Secrets

Your GitHub repository needs these secrets for OIDC authentication:

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `AWS_ACCOUNT_ID_STAGING` | AWS Account ID for staging | `948572562675` |
| `AWS_ACCOUNT_ID_PROD` | AWS Account ID for production | `948572562675` |
| `AWS_ROLE_NAME_STAGING` | IAM role name for staging | `GitHubActions-Lambda-Staging` |
| `AWS_ROLE_NAME_PROD` | IAM role name for production | `GitHubActions-Lambda-Production` |

## 🚀 Quick Setup

### Option 1: Automated Setup (Recommended)
```bash
# Run the setup script
./scripts/setup-github-secrets.sh snblaise serverlessapplication

# The script will automatically:
# 1. Get your AWS Account ID
# 2. Set all required GitHub secrets
# 3. Verify the setup
```

### Option 2: Manual Setup
1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret from the table above

## 🔧 How It Works

### Before (Hardcoded Role Names)
```yaml
role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID_STAGING }}:role/GitHubActions-Lambda-Staging
```

### After (Flexible with Secrets)
```yaml
role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID_STAGING }}:role/${{ secrets.AWS_ROLE_NAME_STAGING }}
```

## 🎯 Benefits

### 1. **Flexibility**
- Easy to change role names without modifying workflow files
- Support for different naming conventions across environments

### 2. **Security**
- Role names are stored securely as GitHub secrets
- No sensitive information in workflow files

### 3. **Multi-Environment Support**
- Separate secrets for staging and production
- Easy environment-specific configuration

### 4. **Maintainability**
- Centralized secret management
- Easy to update across multiple workflows

## 🔍 Verification

### Check Secrets via GitHub CLI
```bash
# List all secrets
gh secret list --repo snblaise/serverlessapplication

# Check specific secret (won't show value, just confirms existence)
gh secret list --repo snblaise/serverlessapplication | grep AWS_ROLE_NAME_STAGING
```

### Check Secrets via GitHub Web UI
1. Go to `https://github.com/snblaise/serverlessapplication/settings/secrets/actions`
2. Verify all 4 secrets are listed
3. Secrets will show "Updated X time ago" but not the actual values

### Test with Workflow
```bash
# Trigger the test workflow
gh workflow run test-oidc-simple.yml --repo snblaise/serverlessapplication

# Check the run
gh run list --workflow=test-oidc-simple.yml --repo snblaise/serverlessapplication
```

## 🛠️ Troubleshooting

### Error: "Secret not found"
**Cause**: Secret name mismatch or secret not set.

**Solution**:
```bash
# Check if secret exists
gh secret list --repo snblaise/serverlessapplication | grep AWS_ROLE_NAME

# Set missing secret
gh secret set AWS_ROLE_NAME_STAGING --body "GitHubActions-Lambda-Staging" --repo snblaise/serverlessapplication
```

### Error: "Role does not exist"
**Cause**: The IAM role name in the secret doesn't match the actual role.

**Solution**:
```bash
# Check actual role name in AWS
aws iam list-roles --query 'Roles[?contains(RoleName, `GitHubActions`)].RoleName' --output table

# Update secret with correct role name
gh secret set AWS_ROLE_NAME_STAGING --body "CORRECT_ROLE_NAME" --repo snblaise/serverlessapplication
```

### Error: "Invalid account ID"
**Cause**: Wrong AWS Account ID in secret.

**Solution**:
```bash
# Get correct account ID
aws sts get-caller-identity --query 'Account' --output text

# Update secret
gh secret set AWS_ACCOUNT_ID_STAGING --body "123456789012" --repo snblaise/serverlessapplication
```

## 🔄 Updating Secrets

### Update Single Secret
```bash
gh secret set AWS_ROLE_NAME_STAGING --body "NewRoleName" --repo snblaise/serverlessapplication
```

### Update All Secrets
```bash
# Re-run the setup script
./scripts/setup-github-secrets.sh snblaise serverlessapplication
```

### Bulk Update via GitHub CLI
```bash
# Set multiple secrets at once
gh secret set AWS_ACCOUNT_ID_STAGING --body "123456789012" --repo snblaise/serverlessapplication
gh secret set AWS_ACCOUNT_ID_PROD --body "123456789012" --repo snblaise/serverlessapplication
gh secret set AWS_ROLE_NAME_STAGING --body "GitHubActions-Lambda-Staging" --repo snblaise/serverlessapplication
gh secret set AWS_ROLE_NAME_PROD --body "GitHubActions-Lambda-Production" --repo snblaise/serverlessapplication
```

## 🌍 Multi-Repository Setup

If you have multiple repositories using the same AWS account:

### Organization Secrets (Recommended)
1. Go to your GitHub organization settings
2. Navigate to **Secrets and variables** → **Actions**
3. Create organization-level secrets
4. Select which repositories can access them

### Repository-Specific Secrets
Each repository needs its own set of secrets if using different AWS accounts or role names.

## 🔒 Security Best Practices

### 1. **Principle of Least Privilege**
- Only grant necessary permissions to IAM roles
- Use environment-specific roles with appropriate restrictions

### 2. **Secret Rotation**
- Regularly review and update secrets
- Monitor secret usage in GitHub Actions logs

### 3. **Access Control**
- Limit who can modify repository secrets
- Use branch protection rules for production deployments

### 4. **Audit Trail**
- Monitor AWS CloudTrail for role usage
- Review GitHub Actions logs for authentication events

## 📋 Complete Setup Checklist

- [ ] AWS OIDC provider created
- [ ] IAM roles created (staging and production)
- [ ] Trust policies configured
- [ ] GitHub secrets set:
  - [ ] `AWS_ACCOUNT_ID_STAGING`
  - [ ] `AWS_ACCOUNT_ID_PROD`
  - [ ] `AWS_ROLE_NAME_STAGING`
  - [ ] `AWS_ROLE_NAME_PROD`
- [ ] Workflow updated to use secrets
- [ ] Test workflow runs successfully
- [ ] Production deployment tested

## 🆘 Getting Help

If you encounter issues:

1. **Run the diagnostic script**:
   ```bash
   ./scripts/diagnose-oidc.sh snblaise serverlessapplication staging
   ```

2. **Check GitHub Actions logs** for detailed error messages

3. **Verify AWS resources**:
   ```bash
   # Check OIDC provider
   aws iam list-open-id-connect-providers
   
   # Check IAM roles
   aws iam list-roles --query 'Roles[?contains(RoleName, `GitHubActions`)].RoleName'
   ```

4. **Test authentication manually**:
   ```bash
   # From within GitHub Actions
   aws sts get-caller-identity
   ```

## 📚 Related Documentation

- [GitHub OIDC Setup Guide](./GITHUB_OIDC_SETUP.md)
- [CI/CD Pipeline Documentation](./CICD_PIPELINE.md)
- [GitHub Actions Secrets Documentation](https://docs.github.com/en/actions/security-guides/encrypted-secrets)