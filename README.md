# Serverless Lambda Application

A production-ready TypeScript Lambda function with automated CI/CD deployment.

## Quick Start

### Prerequisites
- AWS CLI configured with appropriate permissions
- Node.js 22+ installed
- GitHub repository with admin access

### Deploy

1. **Install dependencies**:
   ```bash
   npm install
   ```

2. **Build and test locally**:
   ```bash
   npm run build
   npm test
   ```

3. **One-time setup** (create GitHub OIDC provider):
   ```bash
   ./setup-oidc.sh
   ```

4. **Deploy to AWS**:
   ```bash
   # Deploy to staging
   ./deploy.sh staging
   
   # Or deploy to production
   ./deploy.sh production
   
   # Or push to GitHub for automatic deployment
   git push origin main
   ```

### GitHub Actions Setup

The repository includes a complete CI/CD pipeline that:
- Runs tests and linting
- Builds the TypeScript code
- Deploys infrastructure via CloudFormation
- Updates Lambda function code
- Monitors deployment health

### Architecture

- **Runtime**: Node.js 22.x
- **Language**: TypeScript
- **Observability**: AWS Lambda Powertools
- **Infrastructure**: CloudFormation
- **CI/CD**: GitHub Actions with OIDC

### Local Development

```bash
# Install dependencies
npm install

# Run tests
npm test

# Build TypeScript
npm run build

# Lint code
npm run lint
```

## Project Structure

```
├── src/
│   ├── index.ts          # Lambda handler with TypeScript
│   └── index.test.ts     # Jest unit tests
├── cloudformation/
│   ├── lambda-infrastructure.yml  # Complete AWS infrastructure
│   └── parameters/
│       ├── staging.json  # Staging environment config
│       └── production.json # Production environment config
├── .github/workflows/
│   └── lambda-cloudformation-cicd.yml # CI/CD pipeline
├── setup-oidc.sh        # One-time OIDC provider setup
├── deploy.sh            # Local deployment script
├── package.json         # Dependencies and npm scripts
├── tsconfig.json        # TypeScript configuration
└── .eslintrc.js         # ESLint configuration
```

## Features

### 🚀 **Production-Ready Lambda Function**
- **TypeScript** with strict type checking
- **AWS Lambda Powertools** for structured logging, metrics, and tracing
- **Error handling** with proper HTTP responses
- **Dead Letter Queue** for failed invocations
- **Environment-specific configuration**

### 🛡️ **Security & Compliance**
- **IAM least-privilege** roles and policies
- **GitHub OIDC authentication** (no long-lived credentials)
- **Environment isolation** (staging/production)
- **Secure artifact storage** in S3

### 📊 **Observability & Monitoring**
- **CloudWatch Logs** with structured logging
- **X-Ray tracing** for performance insights
- **CloudWatch Alarms** for error rates, duration, and throttling
- **Custom metrics** via Lambda Powertools

### 🔄 **CI/CD Pipeline**
- **Automated testing** with Jest
- **TypeScript compilation** and validation
- **ESLint** code quality checks
- **CloudFormation** infrastructure deployment
- **Canary deployments** with automatic rollback
- **Multi-environment** support (staging/production)

## Detailed Setup Guide

### 1. Prerequisites Setup

#### AWS CLI Configuration
```bash
# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS credentials
aws configure
# Enter your AWS Access Key ID, Secret Access Key, and region (us-east-1)
```

#### Node.js Setup
```bash
# Install Node.js 22+ (using nvm)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install 22
nvm use 22
```

### 2. Repository Setup

#### Clone and Install
```bash
git clone <your-repo-url>
cd serverlessapplication
npm install
```

#### Environment Configuration
The application uses environment-specific parameters in `cloudformation/parameters/`:

**Staging Configuration** (`staging.json`):
- Memory: 256MB
- Timeout: 30 seconds
- Error threshold: 5 errors

**Production Configuration** (`production.json`):
- Memory: 512MB  
- Timeout: 30 seconds
- Error threshold: 3 errors (stricter)

### 3. Local Development

#### Development Workflow
```bash
# Install dependencies
npm install

# Run tests in watch mode
npm run test:watch

# Build TypeScript
npm run build

# Run linting
npm run lint

# Fix linting issues
npm run lint:fix

# Type checking only
npm run validate
```

#### Testing the Lambda Function
```bash
# Run all tests
npm test

# Run tests with coverage
npm run test:coverage

# The tests cover:
# - Create, update, delete operations
# - Error handling scenarios
# - Response format validation
# - Input validation
```

### 4. Deployment Options

#### Option A: Local Deployment (Fastest for Development)
```bash
# One-time setup (creates GitHub OIDC provider)
./setup-oidc.sh

# Deploy to staging
./deploy.sh staging

# Deploy to production
./deploy.sh production
```

#### Option B: GitHub Actions (Recommended for Production)
```bash
# Push to main branch → automatic staging deployment
git add .
git commit -m "feat: add new functionality"
git push origin main

# Manual production deployment via GitHub UI:
# 1. Go to Actions tab in GitHub
# 2. Select "Lambda CloudFormation CI/CD Pipeline"
# 3. Click "Run workflow"
# 4. Select "production" environment
# 5. Click "Run workflow"
```

### 5. GitHub Actions Configuration

#### Required Secrets
Add these secrets in your GitHub repository settings:

```bash
# Repository Settings → Secrets and variables → Actions

AWS_ACCOUNT_ID: 948572562675  # Your AWS account ID
```

#### Optional Secrets
```bash
SNYK_TOKEN: <your-snyk-token>  # For security scanning (optional)
```

#### Workflow Triggers
- **Push to main**: Deploys to staging automatically
- **Pull Request**: Runs tests and validation only
- **Manual dispatch**: Choose staging or production deployment

## Infrastructure Details

### AWS Resources Created

#### Core Lambda Infrastructure
- **Lambda Function** with Node.js 22.x runtime
- **IAM Execution Role** with least-privilege permissions
- **Dead Letter Queue** (SQS) for failed invocations
- **Lambda Alias** for traffic management

#### Storage & Artifacts
- **S3 Bucket** for deployment artifacts with versioning
- **Lifecycle policies** for automatic cleanup

#### Monitoring & Observability
- **CloudWatch Log Group** for function logs
- **CloudWatch Alarms** for:
  - Error rate monitoring
  - Duration threshold alerts
  - Throttling detection
- **X-Ray tracing** enabled

#### CI/CD Infrastructure
- **CodeDeploy Application** for canary deployments
- **GitHub Actions IAM Roles** for secure deployment
- **OIDC Provider** for GitHub authentication

### Environment Differences

| Resource | Staging | Production |
|----------|---------|------------|
| Memory | 256MB | 512MB |
| Error Threshold | 5 errors | 3 errors |
| Deployment Strategy | Direct | Canary (10% traffic) |
| Monitoring | Basic | Enhanced |

## Monitoring & Troubleshooting

### CloudWatch Dashboards
After deployment, monitor your Lambda function:

1. **AWS Console** → CloudWatch → Dashboards
2. **Lambda Console** → Your function → Monitoring tab
3. **X-Ray Console** → Service map and traces

### Common Issues & Solutions

#### Deployment Failures
```bash
# Check CloudFormation events
aws cloudformation describe-stack-events --stack-name lambda-infrastructure-staging

# Check GitHub Actions logs
# Go to Actions tab → Select failed workflow → View logs
```

#### Lambda Function Errors
```bash
# View recent logs
aws logs tail /aws/lambda/lambda-function-staging --follow

# Check specific error
aws logs filter-log-events \
  --log-group-name /aws/lambda/lambda-function-staging \
  --filter-pattern "ERROR"
```

#### Performance Issues
```bash
# Check X-Ray traces
aws xray get-trace-summaries \
  --time-range-type TimeRangeByStartTime \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T23:59:59Z
```

### Rollback Procedures

#### Automatic Rollback
- Production deployments use canary strategy
- Automatic rollback on CloudWatch alarm triggers
- Manual rollback available via GitHub Actions

#### Manual Rollback
```bash
# List function versions
aws lambda list-versions-by-function --function-name lambda-function-production

# Update alias to previous version
aws lambda update-alias \
  --function-name lambda-function-production \
  --name live \
  --function-version <previous-version>
```

## Development Guidelines

### Code Style
- **TypeScript strict mode** enabled
- **ESLint** with TypeScript rules
- **Consistent error handling** patterns
- **Structured logging** with correlation IDs

### Testing Strategy
- **Unit tests** for all handler functions
- **Integration tests** for AWS service interactions
- **Error scenario testing**
- **Minimum 80% code coverage**

### Security Best Practices
- **No hardcoded secrets** in code
- **Environment variables** for configuration
- **IAM least-privilege** principle
- **Input validation** for all requests
- **Structured error responses** (no sensitive data leakage)

## Contributing

### Pull Request Process
1. Create feature branch from `main`
2. Make changes with tests
3. Run `npm run validate` locally
4. Create pull request
5. GitHub Actions will run validation
6. Merge after approval

### Release Process
1. Merge to `main` → automatic staging deployment
2. Test in staging environment
3. Manual production deployment via GitHub Actions
4. Monitor deployment and rollback if needed

## Documentation

### 📚 **Complete Documentation Suite**
- **[📋 Table of Contents](docs/TABLE_OF_CONTENTS.md)** - Complete navigation guide
- **[🚀 DEPLOYMENT.md](DEPLOYMENT.md)** - Comprehensive deployment guide and troubleshooting
- **[💻 DEVELOPMENT.md](DEVELOPMENT.md)** - Local development, testing, and contribution guidelines  
- **[🏗️ ARCHITECTURE.md](ARCHITECTURE.md)** - Technical architecture and design decisions
- **[📝 CHANGELOG.md](CHANGELOG.md)** - Version history and release notes

### 🔗 **External Resources**
- [AWS Lambda Developer Guide](https://docs.aws.amazon.com/lambda/)
- [AWS Lambda Powertools TypeScript](https://docs.powertools.aws.dev/lambda/typescript/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

### Monitoring URLs
- **AWS Console**: https://console.aws.amazon.com/lambda/
- **CloudWatch**: https://console.aws.amazon.com/cloudwatch/
- **X-Ray**: https://console.aws.amazon.com/xray/

### Cost Optimization
- **Reserved Concurrency**: Set based on expected load
- **Memory Optimization**: Monitor and adjust based on usage
- **Log Retention**: Configure appropriate retention periods
- **Artifact Cleanup**: S3 lifecycle policies handle old deployments

---

**🚀 Ready to deploy serverless applications at scale!**