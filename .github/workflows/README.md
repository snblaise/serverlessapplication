# GitHub Actions CI/CD Workflow for Lambda

This directory contains the GitHub Actions workflow for deploying AWS Lambda functions with production-grade security and compliance controls.

## Overview

The `lambda-cicd.yml` workflow implements a comprehensive CI/CD pipeline with:

- **OIDC Authentication**: No long-lived AWS access keys
- **Environment-specific deployments**: Staging and production with approval gates
- **Security scanning**: SAST, SCA, and policy validation with Security Hub integration
- **Code signing**: Mandatory AWS Signer integration
- **Canary deployments**: CodeDeploy with automated rollback
- **Health monitoring**: CloudWatch alarms and automated rollback triggers

## Prerequisites

### 1. AWS OIDC Provider Setup

Create an OIDC identity provider in each AWS account:

```bash
# Create OIDC provider
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
  --client-id-list sts.amazonaws.com
```

### 2. IAM Roles Configuration

Create IAM roles for each environment using the trust policies in the environment configuration files:

**Staging Role**: `GitHubActions-Lambda-Staging`
**Production Role**: `GitHubActions-Lambda-Production`

Apply the permission boundary policy from `docs/policies/iam-permission-boundary-cicd.json`.

### 3. GitHub Environment Setup

Configure GitHub environments with the following settings:

#### Staging Environment
- **Name**: `staging`
- **Protection rules**: 1 required reviewer
- **Deployment branches**: `develop`, `feature/*`
- **Secrets**:
  - `AWS_ACCOUNT_ID_STAGING`: Your staging AWS account ID

#### Production Environment
- **Name**: `production`
- **Protection rules**: 2 required reviewers, 5-minute wait timer
- **Deployment branches**: `main` only
- **Secrets**:
  - `AWS_ACCOUNT_ID_PROD`: Your production AWS account ID

#### Production Rollback Environment
- **Name**: `production-rollback`
- **Protection rules**: 1 required reviewer (for emergency rollbacks)
- **Manual trigger only**

### 4. AWS Resources Setup

Ensure the following AWS resources exist in each environment:

#### Lambda Function
```bash
# Create Lambda function
aws lambda create-function \
  --function-name lambda-function-staging \
  --runtime nodejs18.x \
  --role arn:aws:iam::ACCOUNT:role/lambda-execution-role \
  --handler index.handler \
  --zip-file fileb://initial-function.zip
```

#### Lambda Alias
```bash
# Create live alias
aws lambda create-alias \
  --function-name lambda-function-staging \
  --name live \
  --function-version 1
```

#### CodeDeploy Application
```bash
# Create CodeDeploy application
aws deploy create-application \
  --application-name lambda-app-staging \
  --compute-platform Lambda

# Create deployment group
aws deploy create-deployment-group \
  --application-name lambda-app-staging \
  --deployment-group-name lambda-deployment-group \
  --service-role-arn arn:aws:iam::ACCOUNT:role/CodeDeployServiceRole \
  --deployment-config-name CodeDeployDefault.Lambda10PercentEvery5Minutes
```

#### S3 Bucket for Artifacts
```bash
# Create deployment bucket
aws s3 mb s3://lambda-artifacts-staging

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket lambda-artifacts-staging \
  --versioning-configuration Status=Enabled
```

#### Code Signing Configuration
```bash
# Create signing profile
aws signer put-signing-profile \
  --profile-name lambda-staging \
  --signing-material certificateArn=arn:aws:acm::ACCOUNT:certificate/CERT-ID \
  --platform AWSLambda-SHA384-ECDSA

# Create code signing config
aws lambda create-code-signing-config \
  --allowed-publishers SigningProfileVersionArns=arn:aws:signer:REGION:ACCOUNT:signing-profiles/lambda-staging \
  --code-signing-policies UntrustedArtifactOnDeployment=Enforce

# Associate with Lambda function
aws lambda update-function-configuration \
  --function-name lambda-function-staging \
  --code-signing-config-arn arn:aws:lambda:REGION:ACCOUNT:code-signing-configs/CONFIG-ID
```

#### CloudWatch Alarms
```bash
# Error rate alarm
aws cloudwatch put-metric-alarm \
  --alarm-name lambda-error-rate-staging \
  --alarm-description "Lambda error rate too high" \
  --metric-name Errors \
  --namespace AWS/Lambda \
  --statistic Sum \
  --period 300 \
  --threshold 5 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=FunctionName,Value=lambda-function-staging \
  --evaluation-periods 2

# Duration alarm  
aws cloudwatch put-metric-alarm \
  --alarm-name lambda-duration-staging \
  --alarm-description "Lambda duration too high" \
  --metric-name Duration \
  --namespace AWS/Lambda \
  --statistic Average \
  --period 300 \
  --threshold 10000 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=FunctionName,Value=lambda-function-staging \
  --evaluation-periods 2

# Throttle alarm
aws cloudwatch put-metric-alarm \
  --alarm-name lambda-throttle-staging \
  --alarm-description "Lambda throttles detected" \
  --metric-name Throttles \
  --namespace AWS/Lambda \
  --statistic Sum \
  --period 300 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --dimensions Name=FunctionName,Value=lambda-function-staging \
  --evaluation-periods 1
```

## Workflow Triggers

### Automatic Triggers
- **Push to `main`**: Deploys to production (with approval)
- **Push to `develop`**: Deploys to staging
- **Pull Request**: Runs tests and security scans only

### Manual Triggers
- **Workflow Dispatch**: Deploy to specific environment
- **Rollback**: Emergency rollback to previous version

## Security Features

### Code Signing
All Lambda deployments must be signed with AWS Signer. Unsigned code is automatically rejected.

### Security Scanning
- **SAST**: CodeQL static analysis
- **SCA**: npm audit for dependency vulnerabilities  
- **Policy Validation**: Checkov for infrastructure compliance
- **Results Integration**: All findings sent to AWS Security Hub

### OIDC Authentication
No long-lived AWS access keys. All AWS API calls use temporary credentials via OIDC.

### Permission Boundaries
CI/CD roles are restricted by permission boundaries to prevent privilege escalation.

## Deployment Strategy

### Canary Deployments
Production deployments use CodeDeploy with:
- 10% traffic shift every 5 minutes
- Automated rollback on CloudWatch alarm triggers
- Manual approval gates for production

### Health Monitoring
- CloudWatch alarms for error rate, duration, and throttles
- 10-minute health monitoring period
- Automatic rollback on alarm triggers

## Rollback Procedures

### Automatic Rollback
Triggered by:
- CloudWatch alarm state changes to ALARM
- Deployment health check failures
- CodeDeploy deployment failures

### Manual Rollback
1. Navigate to Actions tab in GitHub
2. Select "Lambda CI/CD Pipeline" workflow
3. Click "Run workflow"
4. Select environment and confirm rollback

## Troubleshooting

### Common Issues

#### OIDC Authentication Failures
- Verify OIDC provider exists in AWS account
- Check IAM role trust policy allows GitHub repository
- Ensure role has required permissions

#### Code Signing Failures
- Verify signing profile exists and is active
- Check Lambda function has code signing config associated
- Ensure signer permissions in IAM role

#### Deployment Failures
- Check CodeDeploy application and deployment group exist
- Verify Lambda function and alias configuration
- Review CloudWatch logs for detailed error messages

#### Security Scan Failures
- Review Security Hub findings for details
- Check npm audit results for vulnerability details
- Verify Checkov policy compliance

### Monitoring and Logs

- **GitHub Actions Logs**: Detailed execution logs for each workflow run
- **CloudWatch Logs**: Lambda function execution logs
- **AWS Security Hub**: Centralized security findings
- **CodeDeploy Console**: Deployment status and history

## Maintenance

### Regular Tasks
- Review and update dependency versions
- Rotate code signing certificates before expiration
- Update security scanning rules and policies
- Review and update CloudWatch alarm thresholds

### Security Updates
- Monitor Security Hub findings regularly
- Update base images and runtime versions
- Review and update IAM permissions
- Audit OIDC provider configuration