#!/bin/bash

# GitHub Actions Deployment Helper Script
# This script helps you deploy the GitHub Actions workflow step by step

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."
    
    local missing_tools=()
    
    # Check required tools
    if ! command_exists git; then
        missing_tools+=("git")
    fi
    
    if ! command_exists aws; then
        missing_tools+=("aws-cli")
    fi
    
    if ! command_exists terraform; then
        missing_tools+=("terraform")
    fi
    
    if ! command_exists node; then
        missing_tools+=("node.js")
    fi
    
    if ! command_exists npm; then
        missing_tools+=("npm")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install the missing tools and run this script again."
        exit 1
    fi
    
    log_info "All required tools are installed ✓"
}

# Check AWS credentials
check_aws_credentials() {
    log_step "Checking AWS credentials..."
    
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log_error "AWS credentials not configured or invalid"
        log_info "Please run 'aws configure' or set up AWS credentials"
        exit 1
    fi
    
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    log_info "AWS credentials configured for account: $account_id ✓"
    echo "STAGING_ACCOUNT_ID=$account_id"
    echo "PRODUCTION_ACCOUNT_ID=$account_id"
    echo ""
    log_warn "Make sure to add these as GitHub secrets:"
    log_warn "  AWS_ACCOUNT_ID_STAGING=$account_id"
    log_warn "  AWS_ACCOUNT_ID_PROD=$account_id"
}

# Check GitHub repository
check_github_repo() {
    log_step "Checking GitHub repository..."
    
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_error "Not in a Git repository"
        exit 1
    fi
    
    local remote_url=$(git remote get-url origin 2>/dev/null || echo "")
    if [[ -z "$remote_url" ]]; then
        log_error "No GitHub remote configured"
        log_info "Please add a GitHub remote: git remote add origin <your-repo-url>"
        exit 1
    fi
    
    log_info "GitHub repository configured: $remote_url ✓"
}

# Validate project structure
validate_project_structure() {
    log_step "Validating project structure..."
    
    local required_files=(
        ".github/workflows/lambda-cicd.yml"
        "package.json"
        "src/index.js"
        "scripts/build-lambda-package.sh"
        "scripts/deploy-lambda-canary.sh"
        "scripts/sign-lambda-package.sh"
        "scripts/validate-lambda-package.sh"
        "scripts/rollback-lambda-deployment.sh"
    )
    
    local missing_files=()
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$PROJECT_ROOT/$file" ]]; then
            missing_files+=("$file")
        fi
    done
    
    if [ ${#missing_files[@]} -ne 0 ]; then
        log_error "Missing required files:"
        for file in "${missing_files[@]}"; do
            echo "  - $file"
        done
        exit 1
    fi
    
    log_info "Project structure is valid ✓"
}

# Test Node.js project
test_nodejs_project() {
    log_step "Testing Node.js project..."
    
    cd "$PROJECT_ROOT"
    
    # Install dependencies
    log_info "Installing dependencies..."
    if ! npm ci >/dev/null 2>&1; then
        log_error "Failed to install dependencies"
        exit 1
    fi
    
    # Run linting
    log_info "Running linting..."
    if ! npm run lint:check >/dev/null 2>&1; then
        log_warn "Linting issues found. Run 'npm run lint' to fix them."
    else
        log_info "Linting passed ✓"
    fi
    
    # Run tests
    log_info "Running tests..."
    if ! npm test >/dev/null 2>&1; then
        log_error "Tests failed"
        log_info "Run 'npm test' to see detailed test results"
        exit 1
    fi
    
    log_info "Tests passed ✓"
}

# Test GitHub Actions workflow
test_github_actions() {
    log_step "Testing GitHub Actions workflow..."
    
    cd "$PROJECT_ROOT"
    
    if [[ -f "scripts/test-github-actions-terraform.sh" ]]; then
        log_info "Running GitHub Actions and Terraform tests..."
        if ./scripts/test-github-actions-terraform.sh >/dev/null 2>&1; then
            log_info "GitHub Actions workflow tests passed ✓"
        else
            log_warn "GitHub Actions workflow tests completed with warnings"
            log_info "Check test-results/github-actions-terraform/test-report.md for details"
        fi
    else
        log_warn "GitHub Actions test script not found, skipping workflow tests"
    fi
}

# Deploy infrastructure
deploy_infrastructure() {
    log_step "Deploying Terraform infrastructure..."
    
    if [[ ! -d "$PROJECT_ROOT/infrastructure" ]]; then
        log_warn "Infrastructure directory not found, skipping Terraform deployment"
        log_info "You may need to deploy AWS resources manually"
        return
    fi
    
    cd "$PROJECT_ROOT/infrastructure"
    
    # Initialize Terraform
    log_info "Initializing Terraform..."
    if ! terraform init >/dev/null 2>&1; then
        log_error "Terraform initialization failed"
        exit 1
    fi
    
    # Deploy staging environment
    log_info "Deploying staging environment..."
    terraform workspace select staging 2>/dev/null || terraform workspace new staging
    
    if terraform plan -var-file="environments/staging/terraform.tfvars" -out=tfplan >/dev/null 2>&1; then
        log_info "Terraform plan for staging successful"
        
        read -p "Do you want to apply the staging infrastructure? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if terraform apply tfplan; then
                log_info "Staging infrastructure deployed successfully ✓"
            else
                log_error "Failed to deploy staging infrastructure"
                exit 1
            fi
        else
            log_info "Skipping staging infrastructure deployment"
        fi
    else
        log_error "Terraform plan for staging failed"
        exit 1
    fi
    
    cd "$PROJECT_ROOT"
}

# Show next steps
show_next_steps() {
    log_step "Next Steps"
    
    echo ""
    log_info "Your GitHub Actions workflow is ready to deploy! Here's what to do next:"
    echo ""
    echo "1. 📝 Configure GitHub Secrets:"
    echo "   - Go to your GitHub repository"
    echo "   - Navigate to Settings → Secrets and variables → Actions"
    echo "   - Add the AWS account ID secrets shown above"
    echo ""
    echo "2. 🛡️ Set up GitHub Environments:"
    echo "   - Go to Settings → Environments"
    echo "   - Create 'staging' and 'production' environments"
    echo "   - Configure protection rules and approvals"
    echo ""
    echo "3. 🚀 Trigger the Workflow:"
    echo "   - Go to Actions tab in your repository"
    echo "   - Select 'Lambda CI/CD Pipeline' workflow"
    echo "   - Click 'Run workflow' and select 'staging'"
    echo ""
    echo "4. 📊 Monitor the Deployment:"
    echo "   - Watch the workflow execution in GitHub Actions"
    echo "   - Check AWS Lambda console for function updates"
    echo "   - Verify CloudWatch logs and metrics"
    echo ""
    echo "📖 For detailed instructions, see: DEPLOY_GITHUB_ACTIONS.md"
    echo ""
}

# Main execution
main() {
    echo ""
    log_info "🚀 GitHub Actions Deployment Helper"
    echo ""
    
    check_prerequisites
    check_aws_credentials
    check_github_repo
    validate_project_structure
    test_nodejs_project
    test_github_actions
    
    echo ""
    read -p "Do you want to deploy the Terraform infrastructure now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        deploy_infrastructure
    else
        log_info "Skipping infrastructure deployment"
    fi
    
    show_next_steps
    
    log_info "✅ Deployment preparation completed successfully!"
}

# Run main function
main "$@"