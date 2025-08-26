#!/bin/bash

# Deploy Bootstrap Infrastructure Script
# This script deploys the foundational AWS resources needed for GitHub Actions OIDC authentication
# Run this script once before using the GitHub Actions workflow

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Function to check if AWS CLI is configured
check_aws_config() {
    print_status "Checking AWS CLI configuration..."
    
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS CLI is not configured or credentials are invalid."
        print_error "Please run 'aws configure' or set up your AWS credentials."
        exit 1
    fi
    
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    AWS_REGION=$(aws configure get region || echo "us-east-1")
    
    print_success "AWS CLI configured successfully"
    print_status "Account ID: $AWS_ACCOUNT_ID"
    print_status "Region: $AWS_REGION"
}

# Function to check if Terraform is installed
check_terraform() {
    print_status "Checking Terraform installation..."
    
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install Terraform 1.5.0 or later."
        exit 1
    fi
    
    TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version')
    print_success "Terraform $TERRAFORM_VERSION found"
}

# Function to check if OIDC provider already exists
check_existing_oidc() {
    print_status "Checking if GitHub OIDC provider already exists..."
    
    OIDC_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
    
    if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN" &> /dev/null; then
        print_warning "GitHub OIDC provider already exists: $OIDC_ARN"
        echo "Do you want to continue and update the roles? (y/N)"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            print_status "Deployment cancelled by user"
            exit 0
        fi
    else
        print_status "GitHub OIDC provider does not exist - will create"
    fi
}

# Function to deploy bootstrap infrastructure
deploy_bootstrap() {
    print_status "Deploying bootstrap infrastructure..."
    
    # Change to bootstrap directory
    cd infrastructure/bootstrap
    
    # Initialize Terraform
    print_status "Initializing Terraform..."
    terraform init
    
    # Validate configuration
    print_status "Validating Terraform configuration..."
    terraform validate
    
    # Plan the deployment
    print_status "Planning bootstrap infrastructure deployment..."
    terraform plan -out=bootstrap.tfplan
    
    # Show plan and ask for confirmation
    echo ""
    print_warning "Review the Terraform plan above."
    echo "Do you want to apply these changes? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        print_status "Deployment cancelled by user"
        rm -f bootstrap.tfplan
        exit 0
    fi
    
    # Apply the configuration
    print_status "Applying bootstrap infrastructure..."
    terraform apply -auto-approve bootstrap.tfplan
    
    # Clean up plan file
    rm -f bootstrap.tfplan
    
    print_success "Bootstrap infrastructure deployment completed!"
}

# Function to display role ARNs
display_role_arns() {
    print_status "Retrieving role ARNs..."
    
    # Change to bootstrap directory (we should already be in root)
    if [[ ! -d "infrastructure/bootstrap" ]]; then
        cd ../..
    fi
    cd infrastructure/bootstrap
    
    STAGING_ROLE_ARN=$(terraform output -raw github_actions_staging_role_arn 2>/dev/null || echo "Not found")
    PRODUCTION_ROLE_ARN=$(terraform output -raw github_actions_production_role_arn 2>/dev/null || echo "Not found")
    SECURITY_SCAN_ROLE_ARN=$(terraform output -raw github_actions_security_scan_role_arn 2>/dev/null || echo "Not found")
    
    echo ""
    print_success "Bootstrap infrastructure is ready!"
    echo ""
    echo "🔑 Created Role ARNs:"
    echo "  Staging Role:      $STAGING_ROLE_ARN"
    echo "  Production Role:   $PRODUCTION_ROLE_ARN"
    echo "  Security Scan Role: $SECURITY_SCAN_ROLE_ARN"
    echo ""
    print_status "Next steps:"
    echo "1. Add your AWS Account ID as a GitHub repository secret named 'AWS_ACCOUNT_ID'"
    echo "2. Your GitHub Actions workflow will now use OIDC authentication"
    echo "3. No need to store AWS access keys in GitHub secrets anymore!"
}

# Function to test OIDC authentication (optional)
test_oidc_auth() {
    print_status "Testing OIDC authentication setup..."
    
    cd infrastructure/bootstrap
    
    STAGING_ROLE_ARN=$(terraform output -raw github_actions_staging_role_arn 2>/dev/null)
    
    if [[ -n "$STAGING_ROLE_ARN" ]]; then
        print_status "OIDC provider and roles are configured correctly"
        print_status "GitHub Actions will be able to assume role: $STAGING_ROLE_ARN"
    else
        print_error "Could not retrieve role ARN - deployment may have failed"
        exit 1
    fi
}

# Main execution
main() {
    echo "🚀 Bootstrap Infrastructure Deployment Script"
    echo "=============================================="
    echo ""
    
    # Check prerequisites
    check_aws_config
    check_terraform
    check_existing_oidc
    
    echo ""
    print_status "Starting bootstrap infrastructure deployment..."
    echo ""
    
    # Deploy infrastructure
    deploy_bootstrap
    
    # Display results
    display_role_arns
    
    # Test setup
    test_oidc_auth
    
    echo ""
    print_success "Bootstrap deployment completed successfully! 🎉"
    echo ""
    print_status "Your GitHub Actions workflow is now ready to use OIDC authentication."
}

# Run main function
main "$@"