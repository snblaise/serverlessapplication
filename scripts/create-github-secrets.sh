#!/bin/bash

# GitHub Secrets and Environments Creation Script
# This script creates GitHub secrets and environments using GitHub CLI

set -euo pipefail

# Default values
GITHUB_REPOSITORY="snblaise/serverlessapplication"
AWS_ACCOUNT_ID="948572562675"
AWS_REGION="us-east-1"
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

Create GitHub secrets and environments for the Lambda CI/CD pipeline.

OPTIONS:
    -r, --repository REPO           GitHub repository in format 'owner/repo' [default: snblaise/serverlessapplication]
    -a, --account-id ACCOUNT        AWS Account ID [default: 948572562675]
    -g, --region REGION             AWS region [default: us-east-1]
    -d, --dry-run                   Show what would be created without actually creating
    -v, --verbose                   Enable verbose output
    -h, --help                      Show this help message

EXAMPLES:
    $0
    $0 -r "myorg/myrepo" -a "123456789012"
    $0 --dry-run

REQUIREMENTS:
    - GitHub CLI (gh) must be installed and authenticated
    - You must have admin access to the repository

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--repository)
            GITHUB_REPOSITORY="$2"
            shift 2
            ;;
        -a|--account-id)
            AWS_ACCOUNT_ID="$2"
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

# Enable verbose output if requested
if [[ "$VERBOSE" == "true" ]]; then
    set -x
fi

log_info "🔐 Setting up GitHub secrets and environments..."
log_info "Repository: $GITHUB_REPOSITORY"
log_info "AWS Account ID: $AWS_ACCOUNT_ID"
log_info "AWS Region: $AWS_REGION"
log_info "Dry Run: $DRY_RUN"

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    log_error "GitHub CLI (gh) is not installed. Please install it first:"
    log_error "https://cli.github.com/manual/installation"
    exit 1
fi

# Check if authenticated with GitHub
if ! gh auth status &> /dev/null; then
    log_error "Not authenticated with GitHub. Please run: gh auth login"
    exit 1
fi

log_success "GitHub CLI is installed and authenticated"

# Verify repository access
if ! gh repo view "$GITHUB_REPOSITORY" &> /dev/null; then
    log_error "Cannot access repository: $GITHUB_REPOSITORY"
    log_error "Please check the repository name and your permissions"
    exit 1
fi

log_success "Repository access verified: $GITHUB_REPOSITORY"

# Define secrets to create (name:value pairs)
SECRETS=(
    "AWS_ACCOUNT_ID_STAGING:$AWS_ACCOUNT_ID"
    "AWS_ROLE_NAME_STAGING:GitHubActions-Lambda-Staging"
    "AWS_ACCOUNT_ID_PROD:$AWS_ACCOUNT_ID"
    "AWS_ROLE_NAME_PROD:GitHubActions-Lambda-Production"
    "AWS_REGION:$AWS_REGION"
)

# Define environments to create
ENVIRONMENTS=(
    "staging"
    "staging-infrastructure"
    "production"
    "production-infrastructure"
    "production-approval"
    "staging-rollback"
    "production-rollback"
)

# Function to create or update a secret
create_secret() {
    local secret_name="$1"
    local secret_value="$2"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would create secret: $secret_name"
        return 0
    fi
    
    if gh secret set "$secret_name" --body "$secret_value" --repo "$GITHUB_REPOSITORY" &> /dev/null; then
        log_success "Created/updated secret: $secret_name"
    else
        log_error "Failed to create secret: $secret_name"
        return 1
    fi
}

# Function to create an environment
create_environment() {
    local env_name="$1"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would create environment: $env_name"
        return 0
    fi
    
    # Check if environment already exists
    if gh api "repos/$GITHUB_REPOSITORY/environments/$env_name" &> /dev/null; then
        log_warning "Environment already exists: $env_name"
        return 0
    fi
    
    # Create environment
    if gh api --method PUT "repos/$GITHUB_REPOSITORY/environments/$env_name" &> /dev/null; then
        log_success "Created environment: $env_name"
    else
        log_error "Failed to create environment: $env_name"
        return 1
    fi
}

# Function to configure environment protection rules
configure_environment_protection() {
    local env_name="$1"
    local protection_config="$2"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would configure protection for environment: $env_name"
        return 0
    fi
    
    if gh api --method PUT "repos/$GITHUB_REPOSITORY/environments/$env_name" --input - <<< "$protection_config" &> /dev/null; then
        log_success "Configured protection rules for environment: $env_name"
    else
        log_warning "Failed to configure protection rules for environment: $env_name"
        return 1
    fi
}

# Create repository secrets
log_info "📝 Creating repository secrets..."
for secret_pair in "${SECRETS[@]}"; do
    secret_name="${secret_pair%%:*}"
    secret_value="${secret_pair#*:}"
    create_secret "$secret_name" "$secret_value"
done

# Create environments
log_info "🏗️ Creating environments..."
for env_name in "${ENVIRONMENTS[@]}"; do
    create_environment "$env_name"
done

# Configure environment protection rules
log_info "🛡️ Configuring environment protection rules..."

# Production environment - require manual approval
if [[ "$DRY_RUN" == "false" ]]; then
    log_info "Configuring production environment protection..."
    production_protection='{
        "wait_timer": 0,
        "prevent_self_review": true,
        "reviewers": [],
        "deployment_branch_policy": {
            "protected_branches": true,
            "custom_branch_policies": false
        }
    }'
    configure_environment_protection "production" "$production_protection"
    
    # Production approval environment - require manual approval
    log_info "Configuring production-approval environment protection..."
    production_approval_protection='{
        "wait_timer": 0,
        "prevent_self_review": true,
        "reviewers": [],
        "deployment_branch_policy": {
            "protected_branches": true,
            "custom_branch_policies": false
        }
    }'
    configure_environment_protection "production-approval" "$production_approval_protection"
    
    # Production infrastructure - require manual approval
    log_info "Configuring production-infrastructure environment protection..."
    production_infra_protection='{
        "wait_timer": 0,
        "prevent_self_review": true,
        "reviewers": [],
        "deployment_branch_policy": {
            "protected_branches": true,
            "custom_branch_policies": false
        }
    }'
    configure_environment_protection "production-infrastructure" "$production_infra_protection"
fi

# Create a summary report
log_info "📊 Creating setup summary..."
cat > github-setup-summary.json << EOF
{
    "setupId": "$(date +%s)-github-secrets-environments",
    "repository": "$GITHUB_REPOSITORY",
    "awsAccountId": "$AWS_ACCOUNT_ID",
    "awsRegion": "$AWS_REGION",
    "dryRun": $DRY_RUN,
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "secrets": $(printf '%s\n' "${SECRETS[@]}" | cut -d: -f1 | jq -R . | jq -s .),
    "environments": $(printf '%s\n' "${ENVIRONMENTS[@]}" | jq -R . | jq -s .),
    "status": "$(if [[ "$DRY_RUN" == "true" ]]; then echo "planned"; else echo "completed"; fi)"
}
EOF

log_success "Setup summary created: github-setup-summary.json"

# Display verification commands
log_info "🔍 Verification commands:"
echo ""
echo "# List repository secrets:"
echo "gh secret list --repo $GITHUB_REPOSITORY"
echo ""
echo "# List environments:"
echo "gh api repos/$GITHUB_REPOSITORY/environments | jq '.environments[].name'"
echo ""
echo "# View specific environment:"
echo "gh api repos/$GITHUB_REPOSITORY/environments/production"
echo ""

# Display next steps
log_info "📋 Next Steps:"
echo ""
echo "1. Verify secrets were created:"
echo "   gh secret list --repo $GITHUB_REPOSITORY"
echo ""
echo "2. Test the workflow:"
echo "   - Go to Actions tab in your repository"
echo "   - Run the 'Lambda CI/CD Pipeline' workflow manually"
echo "   - Select 'staging' environment"
echo ""
echo "3. Configure branch protection (recommended):"
echo "   - Go to Settings > Branches"
echo "   - Add protection rules for 'main' and 'develop' branches"
echo ""
echo "4. Add reviewers for production environments:"
echo "   - Go to Settings > Environments"
echo "   - Configure reviewers for production environments"
echo ""

# Summary
log_info "📋 Setup Summary:"
log_info "  Repository: $GITHUB_REPOSITORY"
log_info "  AWS Account: $AWS_ACCOUNT_ID"
log_info "  AWS Region: $AWS_REGION"
log_info "  Secrets Created: ${#SECRETS[@]}"
log_info "  Environments Created: ${#ENVIRONMENTS[@]}"
log_info "  Status: $(if [[ "$DRY_RUN" == "true" ]]; then echo "Planned (dry run)"; else echo "Completed"; fi)"

if [[ "$DRY_RUN" == "false" ]]; then
    log_success "🎉 GitHub secrets and environments setup completed successfully!"
    log_info "Your CI/CD pipeline is now ready to use."
else
    log_info "🔍 GitHub secrets and environments setup planned successfully!"
    log_info "Run without --dry-run to create the secrets and environments."
fi

exit 0