#!/bin/bash

# Infrastructure Deployment Script
# This script deploys the Terraform infrastructure for the Lambda CI/CD pipeline

set -euo pipefail

# Default values
ENVIRONMENT=""
AWS_REGION="us-east-1"
TERRAFORM_VERSION="1.5.0"
WORKSPACE_DIR="infrastructure"
LAMBDA_PACKAGE=""
DRY_RUN=false
VERBOSE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy Terraform infrastructure for Lambda CI/CD pipeline.

OPTIONS:
    -e, --environment ENVIRONMENT    Target environment (staging|production) [required]
    -r, --region REGION             AWS region (default: us-east-1)
    -p, --package PACKAGE           Path to Lambda deployment package [required]
    -w, --workspace-dir DIR         Terraform workspace directory (default: infrastructure)
    -d, --dry-run                   Plan only, don't apply changes
    -v, --verbose                   Enable verbose output
    -h, --help                      Show this help message

EXAMPLES:
    $0 -e staging -p lambda-function.zip
    $0 -e production -p lambda-function.zip --dry-run
    $0 --environment staging --package lambda-function.zip --verbose

ENVIRONMENT VARIABLES:
    AWS_REGION                      AWS region (overridden by --region)
    TERRAFORM_WORKSPACE_DIR         Terraform workspace directory (overridden by --workspace-dir)

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -r|--region)
            AWS_REGION="$2"
            shift 2
            ;;
        -p|--package)
            LAMBDA_PACKAGE="$2"
            shift 2
            ;;
        -w|--workspace-dir)
            WORKSPACE_DIR="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$ENVIRONMENT" ]]; then
    log_error "Environment is required. Use -e or --environment"
    usage
    exit 1
fi

if [[ -z "$LAMBDA_PACKAGE" ]]; then
    log_error "Lambda package is required. Use -p or --package"
    usage
    exit 1
fi

# Validate environment
if [[ "$ENVIRONMENT" != "staging" && "$ENVIRONMENT" != "production" ]]; then
    log_error "Environment must be 'staging' or 'production'"
    exit 1
fi

# Validate Lambda package exists
if [[ ! -f "$LAMBDA_PACKAGE" ]]; then
    log_error "Lambda package not found: $LAMBDA_PACKAGE"
    exit 1
fi

# Validate workspace directory exists
if [[ ! -d "$WORKSPACE_DIR" ]]; then
    log_error "Workspace directory not found: $WORKSPACE_DIR"
    exit 1
fi

# Enable verbose output if requested
if [[ "$VERBOSE" == "true" ]]; then
    set -x
fi

log_info "🏗️  Starting infrastructure deployment..."
log_info "Environment: $ENVIRONMENT"
log_info "AWS Region: $AWS_REGION"
log_info "Lambda Package: $LAMBDA_PACKAGE"
log_info "Workspace Directory: $WORKSPACE_DIR"
log_info "Dry Run: $DRY_RUN"

# Change to workspace directory
cd "$WORKSPACE_DIR"

# Prepare Lambda package
log_info "📦 Preparing Lambda package..."
cp "../$LAMBDA_PACKAGE" "./lambda-function.zip"

if [[ ! -f "./lambda-function.zip" ]]; then
    log_error "Failed to copy Lambda package to workspace directory"
    exit 1
fi

log_success "Lambda package prepared successfully"

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    log_error "Terraform is not installed. Please install Terraform $TERRAFORM_VERSION or later."
    exit 1
fi

# Check Terraform version
TERRAFORM_CURRENT_VERSION=$(terraform version -json | jq -r '.terraform_version')
log_info "Terraform version: $TERRAFORM_CURRENT_VERSION"

# Initialize Terraform
log_info "🔧 Initializing Terraform..."
terraform init

if [[ $? -ne 0 ]]; then
    log_error "Terraform initialization failed"
    exit 1
fi

log_success "Terraform initialized successfully"

# Select or create workspace
log_info "📁 Managing Terraform workspace: $ENVIRONMENT"
terraform workspace select "$ENVIRONMENT" 2>/dev/null || {
    log_info "Creating new workspace: $ENVIRONMENT"
    terraform workspace new "$ENVIRONMENT"
}

CURRENT_WORKSPACE=$(terraform workspace show)
if [[ "$CURRENT_WORKSPACE" != "$ENVIRONMENT" ]]; then
    log_error "Failed to switch to workspace: $ENVIRONMENT (current: $CURRENT_WORKSPACE)"
    exit 1
fi

log_success "Using Terraform workspace: $CURRENT_WORKSPACE"

# Set Terraform variables
LAMBDA_FUNCTION_NAME="lambda-function-$ENVIRONMENT"

# Plan infrastructure deployment
log_info "📋 Planning infrastructure deployment..."
terraform plan \
    -var="environment=$ENVIRONMENT" \
    -var="lambda_function_name=$LAMBDA_FUNCTION_NAME" \
    -var="aws_region=$AWS_REGION" \
    -out=tfplan

if [[ $? -ne 0 ]]; then
    log_error "Terraform planning failed"
    exit 1
fi

log_success "Terraform plan completed successfully"

# Apply infrastructure changes (unless dry run)
if [[ "$DRY_RUN" == "true" ]]; then
    log_warning "Dry run mode - skipping infrastructure deployment"
    log_info "Plan file saved as: tfplan"
    log_info "To apply changes, run: terraform apply tfplan"
else
    log_info "🚀 Applying infrastructure changes..."
    terraform apply -auto-approve tfplan

    if [[ $? -ne 0 ]]; then
        log_error "Terraform apply failed"
        exit 1
    fi

    log_success "Infrastructure deployment completed successfully"
fi

# Generate infrastructure outputs
log_info "📊 Generating infrastructure outputs..."
terraform output -json > infrastructure-outputs.json

if [[ $? -ne 0 ]]; then
    log_warning "Failed to generate infrastructure outputs"
else
    log_success "Infrastructure outputs saved to: infrastructure-outputs.json"
    
    if [[ "$VERBOSE" == "true" ]]; then
        echo "Infrastructure outputs:"
        cat infrastructure-outputs.json | jq '.'
    fi
fi

# Verify key resources (if not dry run)
if [[ "$DRY_RUN" == "false" ]]; then
    log_info "🔍 Verifying infrastructure deployment..."
    
    # Check if key outputs exist
    if [[ -f "infrastructure-outputs.json" ]]; then
        LAMBDA_FUNCTION_ARN=$(jq -r '.lambda_function_arn.value // empty' infrastructure-outputs.json)
        PIPELINE_ARN=$(jq -r '.pipeline_arn.value // empty' infrastructure-outputs.json)
        S3_BUCKET=$(jq -r '.s3_artifacts_bucket.value // empty' infrastructure-outputs.json)
        
        if [[ -n "$LAMBDA_FUNCTION_ARN" && -n "$PIPELINE_ARN" && -n "$S3_BUCKET" ]]; then
            log_success "Infrastructure verification completed successfully"
            log_info "Lambda Function ARN: $LAMBDA_FUNCTION_ARN"
            log_info "Pipeline ARN: $PIPELINE_ARN"
            log_info "S3 Bucket: $S3_BUCKET"
        else
            log_warning "Some infrastructure resources may not be properly configured"
            log_info "Lambda Function ARN: ${LAMBDA_FUNCTION_ARN:-'Not found'}"
            log_info "Pipeline ARN: ${PIPELINE_ARN:-'Not found'}"
            log_info "S3 Bucket: ${S3_BUCKET:-'Not found'}"
        fi
    else
        log_warning "Infrastructure outputs file not found - skipping verification"
    fi
fi

# Create deployment report
log_info "📝 Creating deployment report..."
cat > infrastructure-deployment-report.json << EOF
{
    "deploymentId": "$(date +%s)-$ENVIRONMENT-infrastructure",
    "environment": "$ENVIRONMENT",
    "awsRegion": "$AWS_REGION",
    "lambdaPackage": "$LAMBDA_PACKAGE",
    "terraformWorkspace": "$CURRENT_WORKSPACE",
    "dryRun": $DRY_RUN,
    "deploymentStatus": "$(if [[ "$DRY_RUN" == "true" ]]; then echo "planned"; else echo "deployed"; fi)",
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "terraformVersion": "$TERRAFORM_CURRENT_VERSION"
}
EOF

log_success "Deployment report created: infrastructure-deployment-report.json"

# Summary
log_info "📋 Deployment Summary:"
log_info "  Environment: $ENVIRONMENT"
log_info "  AWS Region: $AWS_REGION"
log_info "  Lambda Function: $LAMBDA_FUNCTION_NAME"
log_info "  Terraform Workspace: $CURRENT_WORKSPACE"
log_info "  Status: $(if [[ "$DRY_RUN" == "true" ]]; then echo "Planned (dry run)"; else echo "Deployed"; fi)"

if [[ "$DRY_RUN" == "false" ]]; then
    log_success "🎉 Infrastructure deployment completed successfully!"
    log_info "You can now proceed with Lambda function deployment."
else
    log_info "🔍 Infrastructure plan completed successfully!"
    log_info "Review the plan and run without --dry-run to apply changes."
fi

# Return to original directory
cd - > /dev/null

exit 0