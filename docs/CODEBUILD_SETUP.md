# AWS CodeBuild Setup Guide

This guide explains how to set up and use AWS CodeBuild for compiling and deploying your Lambda function.

## 📋 Overview

The project includes comprehensive buildspec files for AWS CodeBuild that handle:
- ✅ Node.js dependency installation
- ✅ Code linting and testing
- ✅ Security scanning
- ✅ Lambda package compilation
- ✅ Package signing (optional)
- ✅ Automated deployment

## 📁 Buildspec Files

### `buildspec.yml` (Full CI/CD Pipeline)
Complete build pipeline that includes:
- Dependency installation
- Testing and linting
- Security audits
- Package compilation
- Code signing
- Deployment to AWS Lambda
- Artifact management

### `buildspec-compile-only.yml` (Build Only)
Simplified buildspec for compilation without deployment:
- Dependency installation
- Testing and linting
- Package compilation
- Artifact generation

## 🚀 Quick Setup

### 1. Deploy Infrastructure
```bash
cd infrastructure
terraform init
terraform apply
```

This creates:
- CodeBuild project
- IAM roles and policies
- S3 bucket for artifacts
- CloudWatch log groups

### 2. Trigger Build Manually
```bash
# Trigger build for staging environment
./scripts/trigger-codebuild.sh staging

# Trigger build for production from main branch
./scripts/trigger-codebuild.sh production main

# Wait for completion
WAIT_FOR_COMPLETION=true ./scripts/trigger-codebuild.sh staging
```

### 3. View Build Results
- **AWS Console**: Navigate to CodeBuild → Projects → `lambda-function-{env}-build`
- **CLI**: Use the build ID from the trigger script
- **Logs**: Available in CloudWatch Logs

## ⚙️ Configuration

### Environment Variables
Set these in your CodeBuild project or buildspec:

| Variable | Description | Default |
|----------|-------------|---------|
| `ENVIRONMENT` | Target environment (staging/production) | `staging` |
| `AWS_DEFAULT_REGION` | AWS region | `us-east-1` |
| `ARTIFACTS_BUCKET` | S3 bucket for artifacts | Auto-configured |
| `LOG_LEVEL` | Lambda function log level | `INFO` |

### Parameter Store Integration
Configure these parameters in AWS Systems Manager:
```bash
# Environment configuration
aws ssm put-parameter \
  --name "/lambda/build/environment" \
  --value "staging" \
  --type "String"

# Log level configuration
aws ssm put-parameter \
  --name "/lambda/build/log-level" \
  --value "INFO" \
  --type "String"
```

## 🔧 Build Phases

### 1. Install Phase
- Sets up Node.js 18 runtime
- Installs global build tools
- Configures AWS CLI
- Determines target environment

### 2. Pre-build Phase
- Installs npm dependencies
- Runs security audit
- Executes linting checks
- Runs test suite with coverage

### 3. Build Phase
- Compiles Lambda deployment package
- Validates package size and structure
- Signs package (if configured)
- Generates deployment metadata

### 4. Post-build Phase
- Uploads artifacts to S3
- Deploys to Lambda (if on main/develop branch)
- Generates build reports
- Updates function code

## 📦 Artifacts

The build produces these artifacts:

| File | Description |
|------|-------------|
| `lambda-function.zip` | Deployment package |
| `package-manifest.json` | Package metadata |
| `deployment-metadata.json` | Build information |
| `build-report.json` | Build status report |
| `lambda-function.zip.sha256` | Package checksum |
| `coverage/` | Test coverage reports |
| `junit.xml` | Test results |

## 🔒 Security Features

### Code Scanning
- **npm audit**: Dependency vulnerability scanning
- **ESLint**: Code quality and security linting
- **Checkov**: Infrastructure as Code security scanning

### Package Security
- **Code Signing**: AWS Signer integration for package integrity
- **Checksums**: SHA256 verification for all packages
- **Audit Trail**: Complete build and deployment tracking

## 🌍 Multi-Environment Support

### Branch-based Deployment
- `main` branch → Production environment
- `develop` branch → Staging environment
- Feature branches → Build only (no deployment)

### Environment Configuration
Each environment has separate:
- CodeBuild projects
- S3 artifact buckets
- Lambda functions
- IAM roles and policies

## 🚨 Troubleshooting

### Common Issues

**Build Fails at npm ci**
```bash
# Solution: Ensure package-lock.json is committed
git add package-lock.json
git commit -m "Add package-lock.json"
```

**Package Size Too Large**
```bash
# Check dependencies
npm ls --depth=0

# Remove dev dependencies from production build
npm ci --only=production
```

**Permission Denied**
```bash
# Check IAM role permissions
aws iam get-role-policy --role-name codebuild-lambda-staging-role --policy-name codebuild-policy
```

**Deployment Fails**
```bash
# Check Lambda function exists
aws lambda get-function --function-name lambda-function-staging

# Verify CodeDeploy application
aws deploy get-application --application-name lambda-app-staging
```

### Debug Commands
```bash
# Check build logs
aws logs describe-log-groups --log-group-name-prefix "/aws/codebuild/lambda-function"

# Get build details
aws codebuild batch-get-builds --ids <BUILD_ID>

# List artifacts
aws s3 ls s3://lambda-artifacts-staging/builds/
```

## 🔗 Integration with Other Services

### CodePipeline Integration
```yaml
# Add to your pipeline
- Name: Build
  ActionTypeId:
    Category: Build
    Owner: AWS
    Provider: CodeBuild
    Version: '1'
  Configuration:
    ProjectName: lambda-function-staging-build
```

### GitHub Actions Integration
The buildspec can be triggered from GitHub Actions:
```yaml
- name: Trigger CodeBuild
  run: |
    aws codebuild start-build \
      --project-name lambda-function-staging-build \
      --source-version ${{ github.sha }}
```

## 📊 Monitoring and Metrics

### CloudWatch Metrics
- Build success/failure rates
- Build duration
- Package size trends
- Test coverage metrics

### Notifications
Configure SNS notifications for:
- Build failures
- Deployment completions
- Security scan alerts

## 🎯 Best Practices

1. **Version Control**: Always commit package-lock.json
2. **Testing**: Maintain >80% test coverage
3. **Security**: Run security scans on every build
4. **Artifacts**: Use S3 for artifact storage and versioning
5. **Monitoring**: Set up CloudWatch alarms for build failures
6. **Caching**: Use CodeBuild caching for faster builds
7. **Secrets**: Use Parameter Store/Secrets Manager for sensitive data

## 📚 Additional Resources

- [AWS CodeBuild User Guide](https://docs.aws.amazon.com/codebuild/)
- [Buildspec Reference](https://docs.aws.amazon.com/codebuild/latest/userguide/build-spec-ref.html)
- [Lambda Deployment Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)