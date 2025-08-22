# Infrastructure-First Deployment Strategy

## Overview
The GitHub Actions workflow has been updated to deploy infrastructure first before Lambda function deployment. This ensures all necessary AWS resources are in place before attempting to deploy the Lambda function.

## Updated Workflow Structure

### Staging Environment
1. **Setup** - Environment configuration and OIDC setup
2. **Lint and Test** - Code quality and testing
3. **Security Scan** - SAST, SCA, and IaC scanning
4. **Build and Package** - Lambda function packaging
5. **🆕 Deploy Infrastructure (Staging)** - Terraform infrastructure deployment
6. **Deploy Lambda (Staging)** - Lambda function deployment using CodeDeploy
7. **Health Checks** - Post-deployment verification

### Production Environment
1. **Manual Approval** - Production deployment approval gate
2. **🆕 Deploy Infrastructure (Production)** - Terraform infrastructure deployment
3. **Deploy Lambda (Production)** - Lambda function deployment using CodeDeploy
4. **Health Checks** - Post-deployment verification

## New Infrastructure Deployment Jobs

### `deploy-infrastructure-staging`
- **Purpose**: Deploy Terraform infrastructure for staging environment
- **Dependencies**: `setup`, `build-and-package`
- **Environment**: `staging-infrastructure`
- **Key Steps**:
  - Setup Terraform
  - Prepare Lambda package for infrastructure
  - Deploy infrastructure with Terraform
  - Verify infrastructure deployment
  - Upload infrastructure artifacts

### `deploy-infrastructure-production`
- **Purpose**: Deploy Terraform infrastructure for production environment
- **Dependencies**: `setup`, `deploy-staging`, `request-production-approval`
- **Environment**: `production-infrastructure`
- **Key Steps**:
  - Setup Terraform
  - Prepare Lambda package for infrastructure
  - Deploy infrastructure with Terraform
  - Verify infrastructure deployment
  - Upload infrastructure artifacts

## Infrastructure Deployment Script

### `scripts/deploy-infrastructure.sh`
A comprehensive script for deploying Terraform infrastructure with the following features:

#### Features
- **Environment Support**: Staging and production environments
- **Terraform Management**: Workspace creation and management
- **Package Preparation**: Automatic Lambda package preparation
- **Verification**: Infrastructure deployment verification
- **Reporting**: Detailed deployment reports
- **Dry Run Support**: Plan-only mode for testing

#### Usage
```bash
# Deploy staging infrastructure
./scripts/deploy-infrastructure.sh -e staging -p lambda-function.zip

# Deploy production infrastructure
./scripts/deploy-infrastructure.sh -e production -p lambda-function.zip

# Dry run (plan only)
./scripts/deploy-infrastructure.sh -e staging -p lambda-function.zip --dry-run

# Verbose output
./scripts/deploy-infrastructure.sh -e staging -p lambda-function.zip --verbose
```

#### Options
- `-e, --environment`: Target environment (staging|production) [required]
- `-r, --region`: AWS region (default: us-east-1)
- `-p, --package`: Path to Lambda deployment package [required]
- `-w, --workspace-dir`: Terraform workspace directory (default: infrastructure)
- `-d, --dry-run`: Plan only, don't apply changes
- `-v, --verbose`: Enable verbose output
- `-h, --help`: Show help message

## Infrastructure Resources Deployed

### Core Infrastructure
- **Lambda Function**: Base function with execution role
- **Lambda Alias**: For blue-green deployments
- **Dead Letter Queue**: Error handling
- **S3 Artifacts Bucket**: Build artifacts storage

### CI/CD Pipeline
- **CodePipeline**: Complete deployment pipeline
- **CodeBuild Projects**: Build and integration testing
- **CodeDeploy Application**: Blue-green deployment management
- **CodeDeploy Deployment Group**: Deployment configuration

### Monitoring & Security
- **CloudWatch Alarms**: Performance monitoring
- **SNS Topic**: Pipeline notifications
- **CloudWatch Event Rules**: Pipeline state monitoring
- **KMS Key**: Encryption for artifacts
- **IAM Roles**: Proper permissions for all services

## Benefits of Infrastructure-First Approach

### 1. **Dependency Resolution**
- Ensures all required AWS resources exist before Lambda deployment
- Prevents deployment failures due to missing infrastructure

### 2. **Consistent Environments**
- Infrastructure is deployed using the same Terraform code for both environments
- Reduces configuration drift between staging and production

### 3. **Better Error Handling**
- Infrastructure failures are caught early in the pipeline
- Separate rollback strategies for infrastructure vs. application

### 4. **Improved Observability**
- Separate artifacts for infrastructure and application deployments
- Clear separation of concerns in deployment logs

### 5. **Enhanced Security**
- Infrastructure changes are tracked and versioned
- Proper IAM roles and permissions are established before deployment

## Environment Protection

### New GitHub Environments
- `staging-infrastructure`: For staging infrastructure deployment
- `production-infrastructure`: For production infrastructure deployment

These environments can have additional protection rules:
- Required reviewers for infrastructure changes
- Deployment windows for production infrastructure
- Environment-specific secrets and variables

## Rollback Strategy

### Updated Rollback Jobs
- **Infrastructure Failures**: Rollback jobs now account for infrastructure deployment failures
- **Dependency Tracking**: Rollback jobs depend on both infrastructure and Lambda deployment jobs
- **Comprehensive Recovery**: Can handle failures at any stage of the deployment process

## Terraform State Management

### Workspace Strategy
- **Staging**: Uses `staging` Terraform workspace
- **Production**: Uses `production` Terraform workspace
- **State Isolation**: Each environment has isolated state
- **Backend Configuration**: Shared backend with workspace separation

## Monitoring and Verification

### Infrastructure Verification
- Validates key resource creation (Lambda, Pipeline, S3 bucket)
- Generates infrastructure outputs for downstream jobs
- Creates deployment reports for audit trails

### Health Checks
- Infrastructure deployment verification
- Resource availability checks
- Output validation and artifact generation

## Next Steps

1. **Configure GitHub Environments**: Set up the new infrastructure environments with appropriate protection rules
2. **Test the Workflow**: Run the updated workflow to verify infrastructure-first deployment
3. **Monitor Deployments**: Use the new artifacts and reports to monitor deployment health
4. **Optimize Performance**: Fine-tune Terraform deployment times and resource provisioning

The infrastructure-first approach provides a more robust and reliable deployment strategy, ensuring that all necessary resources are in place before attempting Lambda function deployments.