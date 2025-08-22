# GitHub Secrets Configuration

## Overview
The GitHub OIDC provider and IAM roles have been successfully configured. You now need to add the following secrets to your GitHub repository to enable the CI/CD workflow.

## Repository Information
- **Repository**: `snblaise/serverlessapplication`
- **AWS Account ID**: `948572562675`
- **AWS Region**: `us-east-1`

## Required GitHub Secrets

### Staging Environment Secrets
Add these secrets to your GitHub repository:

1. **AWS_ACCOUNT_ID_STAGING**
   - Value: `948572562675`
   - Description: AWS Account ID for staging environment

2. **AWS_ROLE_NAME_STAGING**
   - Value: `GitHubActions-Lambda-Staging`
   - Description: IAM role name for GitHub Actions in staging

3. **AWS_REGION**
   - Value: `us-east-1`
   - Description: AWS region for deployments

### Production Environment Secrets (when ready)
For production deployments, you'll also need:

1. **AWS_ACCOUNT_ID_PROD**
   - Value: `948572562675` (or your production account ID)
   - Description: AWS Account ID for production environment

2. **AWS_ROLE_NAME_PROD**
   - Value: `GitHubActions-Lambda-Production`
   - Description: IAM role name for GitHub Actions in production

## How to Add Secrets

### Step 1: Navigate to Repository Settings
1. Go to your GitHub repository: https://github.com/snblaise/serverlessapplication
2. Click on **Settings** tab
3. In the left sidebar, click **Secrets and variables** → **Actions**

### Step 2: Add Repository Secrets
1. Click **New repository secret**
2. Add each secret with the name and value specified above
3. Click **Add secret** for each one

## GitHub Environments Setup

### Required Environments
Create the following environments in your repository:

1. **staging**
   - For staging Lambda deployments
   - No protection rules needed initially

2. **staging-infrastructure**
   - For staging infrastructure deployments
   - Consider adding protection rules for infrastructure changes

3. **production** (when ready)
   - For production Lambda deployments
   - **Recommended**: Add required reviewers and deployment windows

4. **production-infrastructure** (when ready)
   - For production infrastructure deployments
   - **Recommended**: Add required reviewers for infrastructure changes

5. **production-approval**
   - For manual production deployment approval
   - **Recommended**: Add required reviewers

### How to Create Environments
1. Go to **Settings** → **Environments**
2. Click **New environment**
3. Enter the environment name
4. Configure protection rules as needed
5. Click **Configure environment**

## IAM Role Configuration

### Staging Role Details
- **Role Name**: `GitHubActions-Lambda-Staging`
- **Role ARN**: `arn:aws:iam::948572562675:role/GitHubActions-Lambda-Staging`
- **OIDC Provider**: `arn:aws:iam::948572562675:oidc-provider/token.actions.githubusercontent.com`

### Trust Policy
The role trusts the following GitHub repository patterns:
- `repo:snblaise/serverlessapplication:ref:refs/heads/main`
- `repo:snblaise/serverlessapplication:ref:refs/heads/develop`
- `repo:snblaise/serverlessapplication:pull_request`

### Permissions
The role has permissions for:
- Lambda function management
- S3 artifacts bucket access
- CodeDeploy operations
- CloudWatch logs and metrics
- X-Ray tracing
- Security Hub findings
- Code signing (optional)

## Testing the Configuration

### Test 1: Manual Workflow Trigger
1. Go to **Actions** tab in your repository
2. Select the **Lambda CI/CD Pipeline** workflow
3. Click **Run workflow**
4. Select **staging** environment
5. Click **Run workflow**

### Test 2: Push to Develop Branch
1. Make a small change to your code
2. Commit and push to the `develop` branch
3. The workflow should trigger automatically for staging deployment

### Test 3: Push to Main Branch
1. Merge changes to the `main` branch
2. The workflow should trigger for production deployment (with approval)

## Troubleshooting

### Common Issues

#### 1. "Error: Could not assume role"
- **Cause**: Incorrect role ARN or missing secrets
- **Solution**: Verify the role ARN and secret values match exactly

#### 2. "Error: No identity-based policy allows the sts:AssumeRoleWithWebIdentity action"
- **Cause**: Trust policy doesn't match the repository
- **Solution**: Verify the repository name in the trust policy

#### 3. "Error: Access denied"
- **Cause**: Role doesn't have required permissions
- **Solution**: Check the IAM role permissions and policies

### Verification Commands
You can verify the setup using AWS CLI:

```bash
# Check if the role exists
aws iam get-role --role-name GitHubActions-Lambda-Staging

# Check the trust policy
aws iam get-role --role-name GitHubActions-Lambda-Staging --query 'Role.AssumeRolePolicyDocument'

# Check attached policies
aws iam list-attached-role-policies --role-name GitHubActions-Lambda-Staging
aws iam list-role-policies --role-name GitHubActions-Lambda-Staging
```

## Next Steps

1. ✅ **Add GitHub Secrets** - Configure the required secrets in your repository
2. ✅ **Create Environments** - Set up the GitHub environments with appropriate protection rules
3. ✅ **Test Workflow** - Run a test deployment to verify everything works
4. ✅ **Set Up Production** - Configure production environment when ready
5. ✅ **Monitor Deployments** - Use the pipeline monitoring and reporting features

## Security Best Practices

### Repository Protection
- Enable branch protection rules for `main` and `develop` branches
- Require pull request reviews for code changes
- Require status checks to pass before merging

### Environment Protection
- Add required reviewers for production environments
- Set deployment windows for production deployments
- Use environment-specific secrets when possible

### IAM Security
- Follow principle of least privilege
- Regularly review and audit IAM permissions
- Use separate AWS accounts for production when possible

The GitHub credentials are now properly configured and ready for use with your CI/CD pipeline!