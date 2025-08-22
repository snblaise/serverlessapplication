# Complete CI/CD Pipeline Integration

This document describes the comprehensive CI/CD pipeline that integrates CodeBuild compilation with automated deployment.

## 🏗️ Pipeline Architecture

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Source    │───▶│    Build    │───▶│   Deploy    │───▶│  Approval   │───▶│Integration  │
│             │    │             │    │             │    │ (Prod Only) │    │    Test     │
│ • Git Repo  │    │ • Compile   │    │ • CloudForm │    │ • Manual    │    │ • Function  │
│ • S3 Upload │    │ • Test      │    │ • CodeDeploy│    │ • SNS Alert │    │ • Load Test │
│             │    │ • Security  │    │ • Rollback  │    │             │    │ • Monitoring│
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

## 📋 Pipeline Stages

### 1. Source Stage
- **Trigger**: S3 upload or manual execution
- **Artifacts**: Source code package
- **Configuration**: Automatic polling disabled (event-driven)

### 2. Build Stage (CodeBuild)
- **Project**: `lambda-function-{environment}-build`
- **Buildspec**: `buildspec.yml`
- **Actions**:
  - Install Node.js dependencies
  - Run linting and tests
  - Security scanning (npm audit, Checkov)
  - Compile Lambda package
  - Generate deployment artifacts
  - Optional code signing

### 3. Deploy Stage (CloudFormation)
- **Template**: `lambda-deployment-template.yaml`
- **Actions**:
  - Create/Update CloudFormation stack
  - Deploy Lambda function
  - Configure CodeDeploy for canary deployments
  - Set up monitoring and alarms

### 4. Manual Approval (Production Only)
- **Trigger**: SNS notification
- **Requirement**: Manual approval before production deployment
- **Timeout**: Configurable (default: 7 days)

### 5. Integration Test Stage
- **Project**: `lambda-function-{environment}-integration-test`
- **Buildspec**: `buildspec-integration-test.yml`
- **Tests**:
  - Basic function invocation
  - Error handling validation
  - Performance testing
  - Load testing (concurrent invocations)
  - CloudWatch logs verification

## 🚀 Quick Start

### 1. Deploy Infrastructure
```bash
cd infrastructure
terraform init
terraform apply -var="environment=staging"
```

### 2. Trigger Pipeline
```bash
# Trigger staging pipeline
./scripts/trigger-pipeline.sh staging

# Trigger production pipeline with monitoring
MONITOR_EXECUTION=true ./scripts/trigger-pipeline.sh production

# Trigger from specific directory
./scripts/trigger-pipeline.sh staging ./my-lambda-code
```

### 3. Monitor Execution
```bash
# View pipeline status
aws codepipeline get-pipeline-state --name lambda-function-staging-pipeline

# Monitor specific execution
aws codepipeline get-pipeline-execution \
  --pipeline-name lambda-function-staging-pipeline \
  --pipeline-execution-id <EXECUTION_ID>
```

## ⚙️ Configuration

### Environment Variables
Set these in your CodeBuild projects:

| Variable | Description | Default |
|----------|-------------|---------|
| `ENVIRONMENT` | Target environment | `staging` |
| `AWS_DEFAULT_REGION` | AWS region | `us-east-1` |
| `ARTIFACTS_BUCKET` | S3 bucket for artifacts | Auto-configured |
| `FUNCTION_NAME` | Lambda function name | `lambda-function-{env}` |

### Pipeline Parameters
Configure in `infrastructure/codepipeline.tf`:

```hcl
# Manual approval timeout (production only)
timeout_in_minutes = 10080  # 7 days

# Build compute type
compute_type = "BUILD_GENERAL1_SMALL"

# Deployment configuration
deployment_config = "CodeDeployDefault.Lambda10PercentEvery5Minutes"
```

### CloudFormation Parameters
Customize in `templates/lambda-deployment-template.yaml`:

```yaml
Parameters:
  Runtime: nodejs18.x
  Timeout: 30
  MemorySize: 128
  LogRetentionDays: 14
```

## 🔒 Security Features

### Build Security
- **Dependency Scanning**: npm audit with high severity threshold
- **Code Quality**: ESLint with security rules
- **Infrastructure Scanning**: Checkov for IaC security
- **Package Signing**: AWS Signer integration (optional)

### Deployment Security
- **IAM Roles**: Least privilege access
- **Encryption**: KMS encryption for artifacts
- **Network Security**: VPC deployment support
- **Secrets Management**: Parameter Store/Secrets Manager integration

### Runtime Security
- **Dead Letter Queue**: Error handling and monitoring
- **X-Ray Tracing**: Request tracing and debugging
- **CloudWatch Monitoring**: Comprehensive metrics and alarms
- **Reserved Concurrency**: Resource limits and protection

## 📊 Monitoring and Alerting

### Pipeline Monitoring
- **CloudWatch Events**: Pipeline state changes
- **SNS Notifications**: Build failures and approvals
- **CloudWatch Metrics**: Build success rates and duration

### Function Monitoring
- **Error Rate Alarm**: Triggers on high error rates
- **Duration Alarm**: Monitors execution time
- **Throttle Alarm**: Detects concurrency issues
- **Custom Metrics**: Business-specific monitoring

### Integration Test Monitoring
- **Test Results**: Stored in CodeBuild reports
- **Performance Metrics**: Execution time tracking
- **Load Test Results**: Concurrent execution validation

## 🌍 Multi-Environment Support

### Environment Configuration
Each environment has separate:
- CodePipeline instance
- CodeBuild projects
- S3 artifact buckets
- Lambda functions
- CloudFormation stacks
- IAM roles and policies

### Branch Strategy
- `main` branch → Production environment
- `develop` branch → Staging environment
- Feature branches → Build only (no deployment)

### Deployment Strategies
- **Staging**: All-at-once deployment for faster feedback
- **Production**: Canary deployment with gradual traffic shift
- **Rollback**: Automatic rollback on alarm triggers

## 🔧 Advanced Features

### Code Signing
Enable package signing for enhanced security:
```bash
# Configure signing profile
aws signer put-signing-profile \
  --profile-name lambda-staging \
  --signing-material certificateArn=arn:aws:acm:region:account:certificate/cert-id \
  --platform AWSLambda-SHA384-ECDSA
```

### Custom Deployment Configurations
Create custom CodeDeploy configurations:
```bash
# Create custom deployment config
aws deploy create-deployment-config \
  --deployment-config-name Custom.Lambda5PercentEvery2Minutes \
  --compute-platform Lambda \
  --traffic-routing-config type=TimeBasedCanary,timeBasedCanary='{canaryPercentage=5,canaryInterval=2}'
```

### Integration with External Systems
- **Slack Notifications**: SNS to Slack integration
- **JIRA Integration**: Automatic ticket updates
- **GitHub Status**: Update commit status
- **Datadog Monitoring**: Custom metrics and dashboards

## 🚨 Troubleshooting

### Common Issues

**Pipeline Fails at Source Stage**
```bash
# Check S3 bucket permissions
aws s3api get-bucket-policy --bucket lambda-artifacts-staging

# Verify source package
aws s3 ls s3://lambda-artifacts-staging/source/
```

**Build Stage Failures**
```bash
# Check CodeBuild logs
aws logs describe-log-streams \
  --log-group-name /aws/codebuild/lambda-function-staging-build

# View build details
aws codebuild batch-get-builds --ids <BUILD_ID>
```

**Deployment Failures**
```bash
# Check CloudFormation events
aws cloudformation describe-stack-events \
  --stack-name lambda-function-staging

# View CodeDeploy deployment
aws deploy get-deployment --deployment-id <DEPLOYMENT_ID>
```

**Integration Test Failures**
```bash
# Check function logs
aws logs filter-log-events \
  --log-group-name /aws/lambda/lambda-function-staging \
  --start-time $(date -d '1 hour ago' +%s)000

# Test function manually
aws lambda invoke \
  --function-name lambda-function-staging \
  --payload '{"action":"create","data":{"name":"test"}}' \
  response.json
```

### Debug Commands
```bash
# Pipeline state
aws codepipeline get-pipeline-state --name lambda-function-staging-pipeline

# Action executions
aws codepipeline list-action-executions \
  --pipeline-name lambda-function-staging-pipeline \
  --max-results 10

# Build projects
aws codebuild list-projects --sort-by NAME

# CloudFormation stacks
aws cloudformation list-stacks \
  --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE
```

## 📈 Performance Optimization

### Build Performance
- **Caching**: Node.js dependencies and build tools
- **Parallel Execution**: Multiple build projects
- **Artifact Optimization**: Minimal package size
- **Build Environment**: Appropriate compute resources

### Deployment Performance
- **Canary Deployments**: Gradual traffic shifting
- **Warm-up Strategies**: Pre-warm Lambda functions
- **Monitoring**: Real-time performance metrics
- **Rollback Speed**: Fast automatic rollbacks

## 🎯 Best Practices

### Pipeline Design
1. **Fail Fast**: Early validation and testing
2. **Immutable Artifacts**: Version all build outputs
3. **Environment Parity**: Consistent environments
4. **Monitoring**: Comprehensive observability
5. **Security**: Security scanning at every stage

### Code Organization
1. **Infrastructure as Code**: All resources in Terraform
2. **Configuration Management**: Environment-specific configs
3. **Secret Management**: No secrets in code
4. **Documentation**: Keep docs updated
5. **Testing**: Comprehensive test coverage

### Operational Excellence
1. **Automation**: Minimize manual interventions
2. **Monitoring**: Proactive alerting
3. **Incident Response**: Clear runbooks
4. **Continuous Improvement**: Regular pipeline reviews
5. **Disaster Recovery**: Backup and restore procedures

## 📚 Additional Resources

- [AWS CodePipeline User Guide](https://docs.aws.amazon.com/codepipeline/)
- [AWS CodeBuild User Guide](https://docs.aws.amazon.com/codebuild/)
- [AWS CodeDeploy Lambda Guide](https://docs.aws.amazon.com/codedeploy/latest/userguide/applications-create-lambda.html)
- [CloudFormation Lambda Reference](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-lambda-function.html)
- [Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)