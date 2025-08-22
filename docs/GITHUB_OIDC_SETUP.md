# GitHub OIDC Setup Guide

This guide helps you set up OpenID Connect (OIDC) integration between GitHub Actions and AWS, eliminating the need to store AWS credentials as GitHub secrets.

## 🔐 Overview

GitHub OIDC allows GitHub Actions to assume AWS IAM roles without storing long-lived credentials. This is more secure and follows AWS best practices.

## 🚀 Quick Setup

### 1. Run the Setup Script
```bash
# Replace 'your-username/your-repo' with your actual GitHub repository
./scripts/setup-github-oidc.sh your-username/your-repo staging

# For production environment
./scripts/setup-github-oidc.sh your-username/your-repo production
```

### 2. Verify GitHub Secrets
The script will automatically set the required GitHub secrets:
- `AWS_ACCOUNT_ID_STAGING` (for staging environment)
- `AWS_ACCOUNT_ID_PROD` (for production environment)

### 3. Test the Integration
Push a commit to trigger GitHub Actions and verify OIDC authentication works.

## 🔧 Manual Setup (if script fails)

### 1. Create OIDC Provider
```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 1c58a3a8518e8759bf075b76b750d4f2df264fcd
```

### 2. Create IAM Role
```bash
# Create trust policy file
cat > github-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_USERNAME/YOUR_REPO:ref:refs/heads/main"
        }
      }
    }
  ]
}
EOF

# Create the role
aws iam create-role \
  --role-name GitHubActions-Lambda-Staging \
  --assume-role-policy-document file://github-trust-policy.json
```

### 3. Attach Permissions Policy
```bash
# Create permissions policy (see infrastructure/github-oidc.tf for full policy)
aws iam put-role-policy \
  --role-name GitHubActions-Lambda-Staging \
  --policy-name GitHubActions-Lambda-Staging-Policy \
  --policy-document file://github-permissions-policy.json
```

### 4. Set GitHub Secrets
Go to your GitHub repository settings and add:
- **Secret Name**: `AWS_ACCOUNT_ID_STAGING`
- **Secret Value**: Your AWS Account ID

## 🔍 Troubleshooting

### Error: "Could not assume role with OIDC: Request ARN is invalid"

**Cause**: The IAM role ARN is malformed or the role doesn't exist.

**Solutions**:
1. **Check if the role exists**:
   ```bash
   aws iam get-role --role-name GitHubActions-Lambda-Staging
   ```

2. **Verify the GitHub secret**:
   - Go to GitHub repository → Settings → Secrets and variables → Actions
   - Check that `AWS_ACCOUNT_ID_STAGING` or `AWS_ACCOUNT_ID_PROD` is set correctly
   - The value should be your 12-digit AWS Account ID (numbers only)

3. **Check the role ARN format**:
   - Should be: `arn:aws:iam::123456789012:role/GitHubActions-Lambda-Staging`
   - Not: `arn:aws:iam::undefined:role/GitHubActions-Lambda-Staging`

### Error: "Not authorized to perform sts:AssumeRoleWithWebIdentity"

**Cause**: The IAM role trust policy doesn't allow the GitHub repository.

**Solutions**:
1. **Check the trust policy**:
   ```bash
   aws iam get-role --role-name GitHubActions-Lambda-Staging --query 'Role.AssumeRolePolicyDocument'
   ```

2. **Verify repository name in trust policy**:
   - Should match exactly: `repo:your-username/your-repo:ref:refs/heads/main`
   - Case-sensitive
   - Include the branch reference

3. **Update trust policy if needed**:
   ```bash
   aws iam update-assume-role-policy \
     --role-name GitHubActions-Lambda-Staging \
     --policy-document file://corrected-trust-policy.json
   ```

### Error: "OIDC provider not found"

**Cause**: The GitHub OIDC provider doesn't exist in your AWS account.

**Solution**:
```bash
# Create the OIDC provider
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 1c58a3a8518e8759bf075b76b750d4f2df264fcd
```

### Error: "Token audience is invalid"

**Cause**: The OIDC token audience doesn't match the expected value.

**Solution**: Ensure the trust policy includes:
```json
{
  "StringEquals": {
    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
  }
}
```

### Error: "Token subject is invalid"

**Cause**: The GitHub repository or branch doesn't match the trust policy.

**Solutions**:
1. **Check repository name**: Ensure it matches exactly (case-sensitive)
2. **Check branch name**: Default is `main`, but might be `master` or another branch
3. **Allow multiple branches** (if needed):
   ```json
   {
     "StringLike": {
       "token.actions.githubusercontent.com:sub": [
         "repo:your-username/your-repo:ref:refs/heads/main",
         "repo:your-username/your-repo:ref:refs/heads/develop",
         "repo:your-username/your-repo:pull_request"
       ]
     }
   }
   ```

## 🔧 Validation Commands

### Check OIDC Provider
```bash
aws iam list-open-id-connect-providers
```

### Check IAM Role
```bash
aws iam get-role --role-name GitHubActions-Lambda-Staging
```

### Check Role Policies
```bash
aws iam list-role-policies --role-name GitHubActions-Lambda-Staging
aws iam get-role-policy --role-name GitHubActions-Lambda-Staging --policy-name GitHubActions-Lambda-Staging-Policy
```

### Test Role Assumption (from GitHub Actions)
```bash
# This should be run from within a GitHub Actions workflow
aws sts get-caller-identity
```

## 🌍 Multi-Environment Setup

For multiple environments, create separate roles:

### Staging Environment
- **Role Name**: `GitHubActions-Lambda-Staging`
- **GitHub Secret**: `AWS_ACCOUNT_ID_STAGING`
- **Allowed Branches**: `main`, `develop`, pull requests

### Production Environment
- **Role Name**: `GitHubActions-Lambda-Production`
- **GitHub Secret**: `AWS_ACCOUNT_ID_PROD`
- **Allowed Branches**: `main` only

## 🔒 Security Best Practices

### 1. Principle of Least Privilege
- Grant only the minimum permissions required
- Use resource-specific ARNs where possible
- Regularly review and audit permissions

### 2. Branch Protection
- Limit production role to `main` branch only
- Use branch protection rules
- Require pull request reviews

### 3. Monitoring and Auditing
- Enable CloudTrail for API calls
- Monitor role usage with CloudWatch
- Set up alerts for unusual activity

### 4. Token Conditions
- Use specific repository conditions
- Limit token validity time
- Consider IP restrictions if needed

## 📋 Complete Trust Policy Example

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:your-username/your-repo:ref:refs/heads/main",
            "repo:your-username/your-repo:ref:refs/heads/develop",
            "repo:your-username/your-repo:pull_request"
          ]
        }
      }
    }
  ]
}
```

## 🆘 Getting Help

If you're still having issues:

1. **Check GitHub Actions logs** for detailed error messages
2. **Verify all ARNs** are correct and resources exist
3. **Test with minimal permissions** first, then expand
4. **Use AWS CloudTrail** to see what API calls are being made
5. **Check AWS documentation** for the latest OIDC thumbprints

## 📚 Additional Resources

- [GitHub OIDC Documentation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [AWS IAM OIDC Documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [Configuring OpenID Connect in Amazon Web Services](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)