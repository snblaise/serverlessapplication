#!/bin/bash

# GitHub Credentials Setup Script
# This script configures GitHub OIDC provider and IAM roles for GitHub Actions

set -euo pipefail

# Default values
GITHUB_REPOSITORY=""
AWS_REGION="us-east-1"
ENVIRONMENT="staging"
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

Configure GitHub OIDC provider and IAM roles for GitHub Actions.

OPTIONS:
    -r, --repository REPO           GitHub repository in format 'owner/repo' [required]
    -e, --environment ENV           Environment (staging|production) [default: staging]
    -g, --region REGION             AWS region [default: us-east-1]
    -d, --dry-run                   Plan only, don't apply changes
    -v, --verbose                   Enable verbose output
    -h, --help                      Show this help message

EXAMPLES:
    $0 -r "myorg/myrepo" -e staging
    $0 --repository "myorg/myrepo" --environment production
    $0 -r "myorg/myrepo" --dry-run

NOTES:
    - This script will create/update the GitHub OIDC provider
    - IAM roles will be created for GitHub Actions
    - The repository format must be 'owner/repository-name'

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--repository)
            GITHUB_REPOSITORY="$2"
            shift 2
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -g|--region)
            AWS_REGION="$2"
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
if [[ -z "$GITHUB_REPOSITORY" ]]; then
    log_error "GitHub repository is required. Use -r or --repository"
    usage
    exit 1
fi

# Validate repository format
if [[ ! "$GITHUB_REPOSITORY" =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]]; then
    log_error "Invalid repository format. Use 'owner/repo' format"
    exit 1
fi

# Validate environment
if [[ "$ENVIRONMENT" != "staging" && "$ENVIRONMENT" != "production" ]]; then
    log_error "Environment must be 'staging' or 'production'"
    exit 1
fi

# Enable verbose output if requested
if [[ "$VERBOSE" == "true" ]]; then
    set -x
fi

log_info "🔐 Setting up GitHub credentials for AWS..."
log_info "Repository: $GITHUB_REPOSITORY"
log_info "Environment: $ENVIRONMENT"
log_info "AWS Region: $AWS_REGION"
log_info "Dry Run: $DRY_RUN"

# Check if we're in the right directory
if [[ ! -d "infrastructure" ]]; then
    log_error "Infrastructure directory not found. Please run from project root."
    exit 1
fi

# Check AWS credentials
log_info "🔍 Checking AWS credentials..."
if ! aws sts get-caller-identity &>/dev/null; then
    log_error "AWS credentials not configured. Please run 'aws configure' or set environment variables."
    exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
log_success "AWS credentials configured for account: $AWS_ACCOUNT_ID"

# Change to infrastructure directory
cd infrastructure

# Check if Terraform is initialized
if [[ ! -d ".terraform" ]]; then
    log_info "🔧 Initializing Terraform..."
    terraform init
fi

# Select or create workspace
log_info "📁 Managing Terraform workspace: $ENVIRONMENT"
terraform workspace select "$ENVIRONMENT" 2>/dev/null || {
    log_info "Creating new workspace: $ENVIRONMENT"
    terraform workspace new "$ENVIRONMENT"
}

# Plan the OIDC setup
log_info "📋 Planning GitHub OIDC setup..."
terraform plan \
    -var="environment=$ENVIRONMENT" \
    -var="lambda_function_name=lambda-function-$ENVIRONMENT" \
    -var="github_repository=$GITHUB_REPOSITORY" \
    -var="aws_region=$AWS_REGION" \
    -target="aws_iam_openid_connect_provider.github" \
    -target="aws_iam_role.github_actions_staging" \
    -target="aws_iam_role.github_actions_production" \
    -target="aws_iam_role_policy.github_actions_policy" \
    -out=oidc-plan

if [[ $? -ne 0 ]]; then
    log_error "Terraform planning failed"
    exit 1
fi

# Apply the OIDC setup (unless dry run)
if [[ "$DRY_RUN" == "true" ]]; then
    log_warning "Dry run mode - skipping OIDC setup deployment"
    log_info "Plan file saved as: oidc-plan"
    log_info "To apply changes, run: terraform apply oidc-plan"
else
    log_info "🚀 Applying GitHub OIDC setup..."
    terraform apply -auto-approve oidc-plan

    if [[ $? -ne 0 ]]; then
        log_error "Terraform apply failed"
        exit 1
    fi

    log_success "GitHub OIDC setup completed successfully"
fi

# Get outputs
log_info "📊 Getting configuration outputs..."
terraform output -json > github-oidc-outputs.json

if [[ $? -ne 0 ]]; then
    log_warning "Failed to get Terraform outputs"
else
    # Extract key values
    GITHUB_ROLE_ARN=$(jq -r '.github_actions_role_arn.value // empty' github-oidc-outputs.json)
    OIDC_PROVIDER_ARN=$(jq -r '.github_oidc_provider_arn.value // empty' github-oidc-outputs.json)
    
    log_success "Configuration outputs retrieved successfully"
    
    if [[ -n "$GITHUB_ROLE_ARN" ]]; then
        log_info "GitHub Actions Role ARN: $GITHUB_ROLE_ARN"
    fi
    
    if [[ -n "$OIDC_PROVIDER_ARN" ]]; then
        log_info "OIDC Provider ARN: $OIDC_PROVIDER_ARN"
    fi
fi

# Create GitHub secrets configuration
log_info "📝 Creating GitHub secrets configuration..."
cat > ../github-secrets-config.json << EOF
{
    "repository": "$GITHUB_REPOSITORY",
    "environment": "$ENVIRONMENT",
    "secrets": {
        "AWS_ACCOUNT_ID_$(echo $ENVIRONMENT | tr '[:lower:]' '[:upper:]')": "$AWS_ACCOUNT_ID",
        "AWS_ROLE_NAME_$(echo $ENVIRONMENT | tr '[:lower:]' '[:upper:]')": "GitHubActions-Lambda-$(echo $ENVIRONMENT | sed 's/^./\U&/')",
        "AWS_REGION": "$AWS_REGION"
    },
    "roleArn": "$GITHUB_ROLE_ARN",
    "oidcProviderArn": "$OIDC_PROVIDER_ARN"
}
EOF

log_success "GitHub secrets configuration created: github-secrets-config.json"

# Display setup instructions
log_info "📋 GitHub Repository Setup Instructions:"
echo ""
echo "1. Go to your GitHub repository: https://github.com/$GITHUB_REPOSITORY"
echo "2. Navigate to Settings > Secrets and variables > Actions"
echo "3. Add the following repository secrets:"
echo ""
echo "   AWS_ACCOUNT_ID_$(echo $ENVIRONMENT | tr '[:lower:]' '[:upper:]'): $AWS_ACCOUNT_ID"
echo "   AWS_ROLE_NAME_$(echo $ENVIRONMENT | tr '[:lower:]' '[:upper:]'): GitHubActions-Lambda-$(echo $ENVIRONMENT | sed 's/^./\U&/')"
echo "   AWS_REGION: $AWS_REGION"
echo ""

if [[ "$ENVIRONMENT" == "production" ]]; then
    echo "4. For production, also add staging secrets if not already present:"
    echo "   AWS_ACCOUNT_ID_STAGING: $AWS_ACCOUNT_ID"
    echo "   AWS_ROLE_NAME_STAGING: GitHubActions-Lambda-Staging"
    echo ""
fi

echo "5. Create GitHub environments (if not already created):"
echo "   - Go to Settings > Environments"
echo "   - Create environment: $ENVIRONMENT"
if [[ "$ENVIRONMENT" == "staging" ]]; then
    echo "   - Create environment: staging-infrastructure"
fi
if [[ "$ENVIRONMENT" == "production" ]]; then
    echo "   - Create environment: production-infrastructure"
    echo "   - Create environment: production-approval"
    echo "   - Create environment: production-rollback"
fi
echo ""

# Create deployment report
cat > ../github-credentials-setup-report.json << EOF
{
    "setupId": "$(date +%s)-$ENVIRONMENT-github-credentials",
    "repository": "$GITHUB_REPOSITORY",
    "environment": "$ENVIRONMENT",
    "awsRegion": "$AWS_REGION",
    "awsAccountId": "$AWS_ACCOUNT_ID",
    "githubRoleArn": "$GITHUB_ROLE_ARN",
    "oidcProviderArn": "$OIDC_PROVIDER_ARN",
    "dryRun": $DRY_RUN,
    "setupStatus": "$(if [[ "$DRY_RUN" == "true" ]]; then echo "planned"; else echo "completed"; fi)",
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

log_success "Setup report created: github-credentials-setup-report.json"

# Summary
log_info "📋 Setup Summary:"
log_info "  Repository: $GITHUB_REPOSITORY"
log_info "  Environment: $ENVIRONMENT"
log_info "  AWS Account: $AWS_ACCOUNT_ID"
log_info "  AWS Region: $AWS_REGION"
log_info "  Status: $(if [[ "$DRY_RUN" == "true" ]]; then echo "Planned (dry run)"; else echo "Completed"; fi)"

if [[ "$DRY_RUN" == "false" ]]; then
    log_success "🎉 GitHub credentials setup completed successfully!"
    log_info "Please configure the GitHub repository secrets as shown above."
else
    log_info "🔍 GitHub credentials setup planned successfully!"
    log_info "Review the plan and run without --dry-run to apply changes."
fi

# Return to original directory
cd - > /dev/null

exit 0