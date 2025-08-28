# Deployment Guide

This guide covers all deployment scenarios and troubleshooting for the Lambda application.

## Quick Deployment

### First Time Setup
```bash
# 1. Clone repository
git clone <your-repo-url>
cd serverlessapplication

# 2. Install dependencies
npm install

# 3. Setup AWS OIDC provider (one-time)
./setup-oidc.sh

# 4. Deploy to staging
./deploy.sh staging
```

### Regular Deployments
```bash
# Deploy via GitHub Actions (recommended)
git push origin main

# Or deploy locally
./deploy.sh staging
```

## Deployment Methods

### 1. GitHub Actions (Recommended)

#### Automatic Staging Deployment
```bash
# Any push to main branch triggers staging deployment
git add .
git commit -m "feat: new feature"
git push origin main
```

#### Manual Production Deployment
1. Go to GitHub repository
2. Click **Actions** tab
3. Select **Lambda CloudFormation CI/CD Pipeline**
4. Click **Run workflow**
5. Select **production** environment
6. Click **Run workflow**

#### Monitoring GitHub Actions
```bash
# Using GitHub CLI
gh run list --workflow="lambda-cloudformation-cicd.yml"
gh run watch  # Watch latest run
gh run view --log  # View logs
```

### 2. Local Deployment

#### Prerequisites
- AWS CLI configured with admin permissions
- OIDC provider setup completed (`./setup-oidc.sh`)

#### Deploy to Staging
```bash
./deploy.sh staging
```

#### Deploy to Production
```bash
./deploy.sh production
```

#### What the Script Does
1. Validates CloudFormation template
2. Checks if stack exists (create vs update)
3. Deploys infrastructure via CloudFormation
4. Waits for completion
5. Reports success/failure

### 3. Manual CloudFormation

#### For Advanced Users
```bash
# Validate template
aws cloudformation validate-template \
  --template-body file://cloudformation/lambda-infrastructure.yml

# Deploy stack
aws cloudformation create-stack \
  --stack-name lambda-infrastructure-staging \
  --template-body file://cloudformation/lambda-infrastructure.yml \
  --parameters file://cloudformation/parameters/staging.json \
  --capabilities CAPABILITY_NAMED_IAM

# Monitor deployment
aws cloudformation wait stack-create-complete \
  --stack-name lambda-infrastructure-staging
```

## Environment Configuration

### Staging Environment
- **Purpose**: Development and testing
- **Memory**: 256MB
- **Timeout**: 30 seconds
- **Error Threshold**: 5 errors before alarm
- **Deployment**: Automatic on main branch push

### Production Environment
- **Purpose**: Live production workloads
- **Memory**: 512MB (higher performance)
- **Timeout**: 30 seconds
- **Error Threshold**: 3 errors (stricter monitoring)
- **Deployment**: Manual approval required

### Parameter Customization
Edit `cloudformation/parameters/{environment}.json`:

```json
[
  {
    "ParameterKey": "LambdaMemorySize",
    "ParameterValue": "512"
  },
  {
    "ParameterKey": "LambdaTimeout", 
    "ParameterValue": "30"
  },
  {
    "ParameterKey": "ErrorThreshold",
    "ParameterValue": "3"
  }
]
```

## Deployment Pipeline Details

### GitHub Actions Workflow Steps

1. **Setup** - Determine environment and configuration
2. **Lint & Test** - Code quality and unit tests
3. **Validate Template** - CloudFormation template validation
4. **Build & Package** - TypeScript compilation and ZIP creation
5. **Deploy Infrastructure** - CloudFormation stack deployment
6. **Update Function** - Lambda code update
7. **Test Function** - Basic smoke test
8. **Rollback** - Automatic rollback on production failures

### Pipeline Triggers
- **Push to main**: Staging deployment
- **Pull request**: Validation only (no deployment)
- **Workflow dispatch**: Manual deployment with environment choice

### Artifacts Created
- **Lambda package**: `lambda-function.zip`
- **Deployment summary**: JSON with deployment details
- **Test coverage**: Coverage reports

## Troubleshooting

### Common Deployment Issues

#### 1. OIDC Provider Missing
**Error**: `User is not authorized to perform: sts:AssumeRoleWithWebIdentity`

**Solution**:
```bash
./setup-oidc.sh
```

#### 2. CloudFormation Stack Exists
**Error**: `Stack already exists`

**Solution**: The script handles this automatically (update vs create)

#### 3. IAM Permission Denied
**Error**: `User is not authorized to perform: iam:CreateRole`

**Solution**: Ensure AWS credentials have admin permissions:
```bash
aws sts get-caller-identity
# Verify you're using correct AWS account and have admin access
```

#### 4. Parameter File Missing
**Error**: `Unable to load parameterfile`

**Solution**: Ensure parameter files exist:
```bash
ls cloudformation/parameters/
# Should show staging.json and production.json
```

### GitHub Actions Troubleshooting

#### 1. Workflow Not Triggering
- Check if files changed are in trigger paths
- Verify branch name is `main`
- Check workflow file syntax

#### 2. AWS Authentication Failed
- Verify `AWS_ACCOUNT_ID` secret is set
- Check OIDC provider exists
- Verify IAM role trust policy

#### 3. Build Failures
```bash
# Run locally to debug
npm install
npm run validate
npm test
npm run build
```

### CloudFormation Troubleshooting

#### View Stack Events
```bash
aws cloudformation describe-stack-events \
  --stack-name lambda-infrastructure-staging \
  --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`]'
```

#### Check Stack Status
```bash
aws cloudformation describe-stacks \
  --stack-name lambda-infrastructure-staging \
  --query 'Stacks[0].StackStatus'
```

#### Delete Failed Stack
```bash
aws cloudformation delete-stack \
  --stack-name lambda-infrastructure-staging
```

## Rollback Procedures

### Automatic Rollback
- **Production deployments** use canary strategy
- **CloudWatch alarms** trigger automatic rollback
- **Failed deployments** rollback automatically

### Manual Rollback

#### Via GitHub Actions
1. Go to Actions → Failed workflow
2. Click **Re-run jobs** → **Rollback**
3. Confirm rollback in production environment

#### Via AWS CLI
```bash
# List function versions
aws lambda list-versions-by-function \
  --function-name lambda-function-production

# Update alias to previous version
aws lambda update-alias \
  --function-name lambda-function-production \
  --name live \
  --function-version <previous-version-number>
```

#### Via CloudFormation
```bash
# Rollback to previous template
aws cloudformation cancel-update-stack \
  --stack-name lambda-infrastructure-production

# Or update with previous parameters
aws cloudformation update-stack \
  --stack-name lambda-infrastructure-production \
  --use-previous-template \
  --parameters file://cloudformation/parameters/production-previous.json
```

## Monitoring Deployments

### Real-time Monitoring
```bash
# Watch CloudFormation events
aws cloudformation describe-stack-events \
  --stack-name lambda-infrastructure-staging \
  --query 'StackEvents[0:5].[Timestamp,ResourceStatus,ResourceType,LogicalResourceId]' \
  --output table

# Monitor Lambda function
aws logs tail /aws/lambda/lambda-function-staging --follow
```

### Post-Deployment Validation
```bash
# Test Lambda function
aws lambda invoke \
  --function-name lambda-function-staging \
  --payload '{"action":"create","data":{"name":"test"}}' \
  response.json

# Check response
cat response.json
```

### Health Checks
```bash
# Check CloudWatch alarms
aws cloudwatch describe-alarms \
  --alarm-names lambda-error-rate-staging

# Check function configuration
aws lambda get-function-configuration \
  --function-name lambda-function-staging
```

## Performance Optimization

### Memory Optimization
1. Monitor CloudWatch metrics
2. Adjust memory in parameter files
3. Redeploy and measure performance
4. Find optimal memory/cost balance

### Cold Start Optimization
- Use provisioned concurrency for production
- Optimize import statements
- Minimize package size

### Cost Optimization
- Set appropriate log retention
- Use S3 lifecycle policies
- Monitor and adjust reserved concurrency

## Security Considerations

### Deployment Security
- **No long-lived credentials** in GitHub
- **OIDC authentication** for AWS access
- **Least-privilege IAM** roles
- **Environment isolation**

### Runtime Security
- **Input validation** in Lambda function
- **Error handling** without data leakage
- **Secrets management** via AWS Secrets Manager
- **VPC configuration** if needed

## Best Practices

### Deployment Best Practices
1. **Always test in staging** before production
2. **Use pull requests** for code review
3. **Monitor deployments** actively
4. **Have rollback plan** ready
5. **Document changes** in commit messages

### Infrastructure Best Practices
1. **Version control** all infrastructure code
2. **Use parameters** for environment differences
3. **Tag resources** consistently
4. **Monitor costs** regularly
5. **Review IAM permissions** periodically

---

**Need help?** Check the main [README.md](README.md) or create an issue in the repository.