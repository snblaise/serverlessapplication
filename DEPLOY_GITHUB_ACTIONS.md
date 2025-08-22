# GitHub Actions Deployment Guide

This guide will walk you through deploying the Lambda CI/CD pipeline using GitHub Actions.

## Prerequisites Checklist

Before deploying, ensure you have completed all prerequisites:

### ✅ 1. AWS Infrastructure Setup

**Required AWS Resources:**
- [ ] AWS Account with appropriate permissions
- [ ] IAM roles for GitHub Actions OIDC authentication
- [ ] Lambda function (will be created/updated by the workflow)
- [ ] CodeDeploy application and deployment group
- [ ] S3 bucket for deployment artifacts
- [ ] AWS Signer profile for code signing
- [ ] CloudWatch alarms for monitoring

### ✅ 2. GitHub Repository Setup

**Repository Configuration:**
- [ ] Repository has the workflow file at `.github/workflows/lambda-cicd.yml`
- [ ] Repository has the source code in `src/` directory
- [ ] Repository has all required scripts in `scripts/` directory
- [ ] Repository has `package.json` with proper dependencies

### ✅ 3. GitHub Secrets Configuration

**Required Secrets:**
- [ ] `AWS_ACCOUNT_ID_STAGING` - AWS account ID for staging environment
- [ ] `AWS_ACCOUNT_ID_PROD` - AWS account ID for production environment

### ✅ 4. GitHub Environments Setup

**Environment Configuration:**
- [ ] `staging` environment with protection rules
- [ ] `production` environment with protection rules and approvals

## Step-by-Step Deployment

### Step 1: Verify Prerequisites

Run the testing script to validate your setup:

```bash
# Test GitHub Actions workflow and Terraform infrastructure
./scripts/test-github-actions-terraform.sh

# Check the test results
cat test-results/github-actions-terraform/test-report.md
```

### Step 2: Set Up AWS Infrastructure

If you haven't already, deploy the Terraform infrastructure:

```bash
# Navigate to infrastructure directory
cd infrastructure

# Initialize Terraform
terraform init

# Create staging workspace
terraform workspace new staging
terraform workspace select staging

# Plan and apply staging infrastructure
terraform plan -var-file="environments/staging/terraform.tfvars"
terraform apply -var-file="environments/staging/terraform.tfvars"

# Create production workspace
terraform workspace new production
terraform workspace select production

# Plan and apply production infrastructure
terraform plan -var-file="environments/production/terraform.tfvars"
terraform apply -var-file="environments/production/terraform.tfvars"
```

### Step 3: Configure GitHub Secrets

Add the required secrets to your GitHub repository:

1. Go to your GitHub repository
2. Navigate to Settings → Secrets and variables → Actions
3. Add the following repository secrets:

```bash
# Get your AWS account IDs
aws sts get-caller-identity --query Account --output text
```

**Add these secrets:**
- `AWS_ACCOUNT_ID_STAGING`: Your staging AWS account ID
- `AWS_ACCOUNT_ID_PROD`: Your production AWS account ID

### Step 4: Set Up GitHub Environments

1. Go to Settings → Environments in your GitHub repository
2. Create `staging` environment:
   - Add protection rule: Require 1 reviewer
   - Add deployment branches: `develop`, `feature/*`
3. Create `production` environment:
   - Add protection rule: Require 2 reviewers
   - Add wait timer: 5 minutes
   - Add deployment branches: `main` only

### Step 5: Test the Workflow

#### Option A: Manual Trigger (Recommended for first deployment)

1. Go to Actions tab in your GitHub repository
2. Select "Lambda CI/CD Pipeline" workflow
3. Click "Run workflow"
4. Select `staging` environment
5. Click "Run workflow"

#### Option B: Push to Trigger Branch

```bash
# Create a test branch
git checkout -b test/deploy-workflow

# Make a small change
echo "# Test deployment" >> README.md
git add README.md
git commit -m "test: trigger GitHub Actions workflow"

# Push to trigger workflow
git push origin test/deploy-workflow
```

### Step 6: Monitor the Deployment

1. **Watch the workflow execution:**
   - Go to Actions tab in GitHub
   - Click on the running workflow
   - Monitor each job's progress

2. **Check AWS resources:**
   - Lambda function deployment
   - CodeDeploy deployment progress
   - CloudWatch logs and metrics

3. **Verify deployment success:**
   - Check Lambda function version
   - Test function invocation
   - Verify monitoring alarms

## Workflow Jobs Explained

### 1. Setup Job
- Determines target environment based on branch/trigger
- Sets up AWS role ARNs for OIDC authentication
- Configures environment variables

### 2. Lint and Test Job
- Runs ESLint for code quality
- Executes Jest tests with coverage
- Uploads test results as artifacts

### 3. Security Scan Job
- Runs CodeQL for static analysis
- Performs npm audit for dependency vulnerabilities
- Executes Checkov for infrastructure security
- Uploads findings to AWS Security Hub

### 4. Build and Package Job
- Installs production dependencies
- Builds optimized Lambda package
- Signs package with AWS Signer
- Validates package integrity

### 5. Deploy Job
- Downloads build artifacts
- Deploys using CodeDeploy canary strategy
- Monitors deployment health
- Uploads deployment reports

### 6. Rollback Job (if needed)
- Triggers on deployment failure
- Performs emergency rollback
- Reports rollback status

## Troubleshooting Common Issues

### Issue 1: OIDC Authentication Failure

**Error:** `Error: Could not assume role with OIDC`

**Solution:**
1. Verify AWS IAM role trust policy includes GitHub OIDC provider
2. Check role ARN format in workflow
3. Ensure GitHub secrets are correctly set

```bash
# Verify OIDC provider exists
aws iam list-open-id-connect-providers

# Check role trust policy
aws iam get-role --role-name GitHubActions-Lambda-Staging
```

### Issue 2: Missing Dependencies

**Error:** `npm ci` fails or dependencies not found

**Solution:**
1. Ensure `package.json` is committed to repository
2. Check Node.js version compatibility
3. Verify npm registry access

```bash
# Test locally
npm ci
npm run lint
npm test
```

### Issue 3: Script Permissions

**Error:** `Permission denied` when executing scripts

**Solution:**
Scripts should be executable. The workflow includes `chmod +x` commands, but verify locally:

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Test script execution
./scripts/build-lambda-package.sh
```

### Issue 4: AWS Resource Not Found

**Error:** Lambda function or CodeDeploy application not found

**Solution:**
1. Verify Terraform infrastructure was deployed
2. Check resource names match workflow expectations
3. Ensure correct AWS region

```bash
# Check Lambda function exists
aws lambda get-function --function-name lambda-function-staging

# Check CodeDeploy application
aws deploy get-application --application-name lambda-app-staging
```

### Issue 5: Code Signing Failure

**Error:** Code signing fails or signature verification fails

**Solution:**
1. Verify AWS Signer profile exists and is active
2. Check signing certificate validity
3. Ensure proper permissions for signing

```bash
# Check signing profile
aws signer get-signing-profile --profile-name lambda-staging

# List signing jobs
aws signer list-signing-jobs --status InProgress
```

## Monitoring and Maintenance

### Daily Monitoring
- [ ] Check workflow execution status
- [ ] Review Security Hub findings
- [ ] Monitor Lambda function metrics
- [ ] Check deployment success rates

### Weekly Maintenance
- [ ] Update dependencies via Dependabot PRs
- [ ] Review and address security findings
- [ ] Check CloudWatch alarm thresholds
- [ ] Validate backup and rollback procedures

### Monthly Tasks
- [ ] Rotate code signing certificates (if needed)
- [ ] Review and update IAM permissions
- [ ] Audit deployment logs and metrics
- [ ] Update Lambda runtime versions

## Advanced Configuration

### Custom Deployment Configurations

Modify the workflow for different deployment strategies:

```yaml
# In .github/workflows/lambda-cicd.yml
# Change CodeDeploy configuration
--config "CodeDeployDefault.LambdaAllAtOnce"  # Immediate deployment
--config "CodeDeployDefault.LambdaLinear10PercentEvery1Minute"  # Linear rollout
```

### Environment-Specific Settings

Customize settings per environment by modifying the setup job:

```yaml
# Add environment-specific configurations
if [[ "${ENVIRONMENT}" == "production" ]]; then
  echo "lambda-timeout=60" >> $GITHUB_OUTPUT
  echo "memory-size=512" >> $GITHUB_OUTPUT
else
  echo "lambda-timeout=30" >> $GITHUB_OUTPUT
  echo "memory-size=256" >> $GITHUB_OUTPUT
fi
```

### Additional Security Scans

Add more security scanning tools:

```yaml
# Add Snyk scanning
- name: Run Snyk security scan
  uses: snyk/actions/node@master
  env:
    SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
```

## Success Criteria

Your GitHub Actions deployment is successful when:

✅ **Workflow Execution:**
- All jobs complete successfully
- No failed steps or error messages
- Artifacts are generated and uploaded

✅ **Lambda Deployment:**
- Function is updated with new code
- Function version is incremented
- Alias points to new version

✅ **Security and Compliance:**
- Security scans complete without blocking issues
- Code signing verification passes
- Findings are uploaded to Security Hub

✅ **Monitoring and Observability:**
- CloudWatch logs show function execution
- Metrics are being collected
- Alarms are configured and functional

✅ **Rollback Capability:**
- Previous version is preserved
- Rollback procedures are tested and working
- Emergency rollback can be triggered

## Next Steps

After successful deployment:

1. **Set up monitoring dashboards** in CloudWatch
2. **Configure alerting** for critical metrics
3. **Document operational procedures** for your team
4. **Schedule regular security reviews** and updates
5. **Plan for disaster recovery** testing

## Support and Resources

- **GitHub Actions Documentation**: https://docs.github.com/en/actions
- **AWS Lambda Developer Guide**: https://docs.aws.amazon.com/lambda/
- **AWS CodeDeploy User Guide**: https://docs.aws.amazon.com/codedeploy/
- **Project Documentation**: See `docs/` directory for detailed guides

For issues or questions, check the troubleshooting section above or review the detailed logs in the GitHub Actions workflow execution.