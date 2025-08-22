# OIDC Trust Policy Fix for New Workflow Structure

## 🔍 Problem Identified

The OIDC authorization error was occurring because the IAM role trust policies were not updated to accommodate the new workflow structure with GitHub Environments.

### Root Cause:
When GitHub Actions runs jobs with `environment:` configurations, the OIDC token's `sub` claim changes from:
- `repo:owner/repo:ref:refs/heads/branch` 
- To: `repo:owner/repo:environment:environment-name`

## 🛠️ Solution Applied

Updated the trust policies for both IAM roles to include the new environment-based subject patterns.

### Staging Role Trust Policy:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::948572562675:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:snblaise/serverlessapplication:ref:refs/heads/main",
            "repo:snblaise/serverlessapplication:ref:refs/heads/develop",
            "repo:snblaise/serverlessapplication:pull_request",
            "repo:snblaise/serverlessapplication:environment:staging",
            "repo:snblaise/serverlessapplication:environment:staging-rollback"
          ]
        }
      }
    }
  ]
}
```

### Production Role Trust Policy:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::948572562675:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:snblaise/serverlessapplication:ref:refs/heads/main",
            "repo:snblaise/serverlessapplication:environment:production",
            "repo:snblaise/serverlessapplication:environment:production-approval",
            "repo:snblaise/serverlessapplication:environment:production-rollback"
          ]
        }
      }
    }
  ]
}
```

## 🎯 Key Changes Made

### 1. **Added Environment-Based Subject Patterns**
- `repo:snblaise/serverlessapplication:environment:staging`
- `repo:snblaise/serverlessapplication:environment:staging-rollback`
- `repo:snblaise/serverlessapplication:environment:production`
- `repo:snblaise/serverlessapplication:environment:production-approval`
- `repo:snblaise/serverlessapplication:environment:production-rollback`

### 2. **Maintained Branch-Based Patterns**
- Kept existing branch and PR patterns for backward compatibility
- `repo:snblaise/serverlessapplication:ref:refs/heads/main`
- `repo:snblaise/serverlessapplication:ref:refs/heads/develop`
- `repo:snblaise/serverlessapplication:pull_request`

## 🔧 Commands Used to Fix

```bash
# Create staging trust policy
cat > staging-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::948572562675:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:snblaise/serverlessapplication:ref:refs/heads/main",
            "repo:snblaise/serverlessapplication:ref:refs/heads/develop",
            "repo:snblaise/serverlessapplication:pull_request",
            "repo:snblaise/serverlessapplication:environment:staging",
            "repo:snblaise/serverlessapplication:environment:staging-rollback"
          ]
        }
      }
    }
  ]
}
EOF

# Update staging role trust policy
aws iam update-assume-role-policy --role-name GitHubActions-Lambda-Staging --policy-document file://staging-trust-policy.json

# Create production trust policy
cat > production-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::948572562675:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:snblaise/serverlessapplication:ref:refs/heads/main",
            "repo:snblaise/serverlessapplication:environment:production",
            "repo:snblaise/serverlessapplication:environment:production-approval",
            "repo:snblaise/serverlessapplication:environment:production-rollback"
          ]
        }
      }
    }
  ]
}
EOF

# Update production role trust policy
aws iam update-assume-role-policy --role-name GitHubActions-Lambda-Production --policy-document file://production-trust-policy.json
```

## ✅ Verification

Both roles now pass the diagnostic checks:
- ✅ GitHub OIDC provider exists
- ✅ IAM roles exist
- ✅ Trust policies have correct audience condition
- ✅ Trust policies allow repository access
- ✅ Roles have proper inline policies

## 🎯 Expected Behavior

The workflow should now successfully authenticate for:

### Staging Jobs:
- `deploy-staging` job with `environment: staging`
- `rollback-staging` job with `environment: staging-rollback`

### Production Jobs:
- `request-production-approval` job with `environment: production-approval`
- `deploy-production` job with `environment: production`
- `rollback-production` job with `environment: production-rollback`

### Manual Jobs:
- `manual-rollback` job with dynamic environment names

## 🚀 Next Steps

The OIDC authorization issue should now be resolved. You can test the workflow by:

1. **Testing Staging Deployment:**
   ```bash
   git push origin develop
   ```

2. **Testing Production Flow:**
   ```bash
   git push origin main
   ```

3. **Testing Manual Rollback:**
   - Use workflow dispatch from GitHub Actions tab
   - Select environment and trigger manual rollback

## 📚 Understanding OIDC Subject Claims

### Branch-based workflows:
- Subject: `repo:owner/repo:ref:refs/heads/branch-name`

### Environment-based workflows:
- Subject: `repo:owner/repo:environment:environment-name`

### Pull request workflows:
- Subject: `repo:owner/repo:pull_request`

This is why the trust policies needed to be updated to include the environment-based patterns for the new workflow structure.