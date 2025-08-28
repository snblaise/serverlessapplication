#!/bin/bash

# Bootstrap Infrastructure Script
# This script deploys the initial CloudFormation stack to create OIDC provider and IAM roles
# After this runs once, all future deployments will happen via GitHub Actions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
ENVIRONMENT="staging"
STACK_NAME="lambda-infrastructure-${ENVIRONMENT}"
AWS_REGION="us-east-1"

print_status "🚀 Bootstrapping Lambda Infrastructure"
print_status "Environment: ${ENVIRONMENT}"
print_status "Stack Name: ${STACK_NAME}"
print_status "AWS Region: ${AWS_REGION}"
echo ""

# Check AWS CLI configuration
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS CLI is not configured. Please run 'aws configure' first."
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
print_status "AWS Account ID: ${ACCOUNT_ID}"

# Validate template
print_status "Validating CloudFormation template..."
if ! aws cloudformation validate-template --template-body file://cloudformation/lambda-infrastructure.yml > /dev/null; then
    print_error "CloudFormation template validation failed"
    exit 1
fi
print_success "Template validation passed"

# Check if stack exists
print_status "Checking if stack exists..."
if aws cloudformation describe-stacks --stack-name "$STACK_NAME" &> /dev/null; then
    print_warning "Stack already exists. This will update the existing stack."
    ACTION="update-stack"
    WAIT_CONDITION="stack-update-complete"
else
    print_status "Stack does not exist. Creating new stack."
    ACTION="create-stack"
    WAIT_CONDITION="stack-create-complete"
fi

# Deploy stack
print_status "Deploying CloudFormation stack..."
aws cloudformation $ACTION \
    --stack-name "$STACK_NAME" \
    --template-body file://cloudformation/lambda-infrastructure.yml \
    --parameters file://cloudformation/parameters/${ENVIRONMENT}.json \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "$AWS_REGION" \
    --tags Key=Environment,Value=${ENVIRONMENT} \
           Key=Project,Value=lambda-production-readiness \
           Key=ManagedBy,Value=bootstrap \
           Key=CreatedBy,Value=manual-bootstrap

print_status "Waiting for stack deployment to complete..."
aws cloudformation wait $WAIT_CONDITION --stack-name "$STACK_NAME" --region "$AWS_REGION"

# Get outputs
print_status "Retrieving stack outputs..."
aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$AWS_REGION" \
    --query 'Stacks[0].Outputs' > bootstrap-outputs.json

# Display key outputs
print_success "🎉 Bootstrap deployment completed successfully!"
echo ""
print_status "📋 Key Resources Created:"

LAMBDA_FUNCTION_NAME=$(jq -r '.[] | select(.OutputKey=="LambdaFunctionName") | .OutputValue' bootstrap-outputs.json 2>/dev/null || echo "N/A")
S3_BUCKET=$(jq -r '.[] | select(.OutputKey=="S3ArtifactsBucket") | .OutputValue' bootstrap-outputs.json 2>/dev/null || echo "N/A")
STAGING_ROLE_ARN=$(jq -r '.[] | select(.OutputKey=="GitHubActionsStagingRoleArn") | .OutputValue' bootstrap-outputs.json 2>/dev/null || echo "N/A")
SECURITY_ROLE_ARN=$(jq -r '.[] | select(.OutputKey=="GitHubActionsSecurityScanRoleArn") | .OutputValue' bootstrap-outputs.json 2>/dev/null || echo "N/A")

echo "  • Lambda Function: ${LAMBDA_FUNCTION_NAME}"
echo "  • S3 Artifacts Bucket: ${S3_BUCKET}"
echo "  • GitHub Actions Staging Role: ${STAGING_ROLE_ARN}"
echo "  • GitHub Actions Security Scan Role: ${SECURITY_ROLE_ARN}"

echo ""
print_status "🔧 Next Steps:"
echo "1. Add these GitHub Secrets to your repository:"
echo "   • AWS_ACCOUNT_ID: ${ACCOUNT_ID}"
echo "   • SNYK_TOKEN: [Optional - get from snyk.io]"
echo ""
echo "2. Push code changes to trigger the GitHub Actions pipeline"
echo ""
echo "3. All future deployments will happen automatically via GitHub Actions!"

print_success "✅ Bootstrap complete! Your pipeline is ready to deploy."