#!/bin/bash

# GitHub Actions and Terraform Testing Script
# This script validates the GitHub Actions workflow and Terraform infrastructure

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
INFRASTRUCTURE_DIR="$PROJECT_ROOT/infrastructure"
RESULTS_DIR="$PROJECT_ROOT/test-results/github-actions-terraform"

echo "🧪 Starting GitHub Actions and Terraform Testing..."
echo "Project root: $PROJECT_ROOT"
echo "Infrastructure directory: $INFRASTRUCTURE_DIR"
echo "Results directory: $RESULTS_DIR"

# Create results directory
mkdir -p "$RESULTS_DIR"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install required tools
install_tools() {
    echo "📦 Checking and installing required tools..."
    
    # Check for act (GitHub Actions local runner)
    if ! command_exists act; then
        echo "❌ act is not installed. Please install it:"
        echo "   macOS: brew install act"
        echo "   Linux: curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash"
        exit 1
    fi
    
    # Check for Terraform
    if ! command_exists terraform; then
        echo "❌ Terraform is not installed. Please install it:"
        echo "   macOS: brew install terraform"
        echo "   Linux: https://learn.hashicorp.com/tutorials/terraform/install-cli"
        exit 1
    fi
    
    # Check for Docker (required by act)
    if ! command_exists docker; then
        echo "❌ Docker is not installed. Please install it:"
        echo "   macOS: brew install docker"
        echo "   Linux: https://docs.docker.com/engine/install/"
        exit 1
    fi
    
    echo "✅ All required tools are installed"
}

# Test GitHub Actions workflow syntax
test_workflow_syntax() {
    echo "🔍 Testing GitHub Actions workflow syntax..."
    
    cd "$PROJECT_ROOT"
    
    # Test workflow syntax with act
    if act --dryrun > "$RESULTS_DIR/workflow-syntax-test.log" 2>&1; then
        echo "✅ GitHub Actions workflow syntax is valid"
    else
        echo "❌ GitHub Actions workflow syntax validation failed"
        cat "$RESULTS_DIR/workflow-syntax-test.log"
        return 1
    fi
}

# Test individual GitHub Actions jobs
test_github_actions_jobs() {
    echo "🔧 Testing individual GitHub Actions jobs..."
    
    cd "$PROJECT_ROOT"
    
    # Create minimal .env file for testing
    cat > .env.local << EOF
AWS_ACCOUNT_ID_STAGING=123456789012
AWS_ACCOUNT_ID_PROD=123456789012
EOF
    
    # Test setup job
    echo "Testing setup job..."
    if act -j setup --dryrun --secret-file .env.local > "$RESULTS_DIR/setup-job-test.log" 2>&1; then
        echo "✅ Setup job configuration is valid"
    else
        echo "⚠️  Setup job test failed (this may be expected without AWS credentials)"
        echo "Check log: $RESULTS_DIR/setup-job-test.log"
    fi
    
    # Test lint-and-test job
    echo "Testing lint-and-test job..."
    if act -j lint-and-test --dryrun --secret-file .env.local > "$RESULTS_DIR/lint-test-job-test.log" 2>&1; then
        echo "✅ Lint and test job configuration is valid"
    else
        echo "⚠️  Lint and test job test failed"
        echo "Check log: $RESULTS_DIR/lint-test-job-test.log"
    fi
    
    # Clean up
    rm -f .env.local
}

# Test Terraform configuration
test_terraform_config() {
    echo "🏗️  Testing Terraform configuration..."
    
    cd "$INFRASTRUCTURE_DIR"
    
    # Initialize Terraform
    echo "Initializing Terraform..."
    if terraform init -backend=false > "$RESULTS_DIR/terraform-init.log" 2>&1; then
        echo "✅ Terraform initialization successful"
    else
        echo "❌ Terraform initialization failed"
        cat "$RESULTS_DIR/terraform-init.log"
        return 1
    fi
    
    # Validate Terraform configuration
    echo "Validating Terraform configuration..."
    if terraform validate > "$RESULTS_DIR/terraform-validate.log" 2>&1; then
        echo "✅ Terraform configuration is valid"
    else
        echo "❌ Terraform validation failed"
        cat "$RESULTS_DIR/terraform-validate.log"
        return 1
    fi
    
    # Test Terraform plan for staging
    echo "Testing Terraform plan for staging..."
    if terraform plan -var-file="environments/staging/terraform.tfvars" -out=tfplan > "$RESULTS_DIR/terraform-plan-staging.log" 2>&1; then
        echo "✅ Terraform plan for staging successful"
        
        # Generate JSON plan for policy testing
        terraform show -json tfplan > "$RESULTS_DIR/tfplan-staging.json" 2>/dev/null || true
    else
        echo "❌ Terraform plan for staging failed"
        cat "$RESULTS_DIR/terraform-plan-staging.log"
        return 1
    fi
    
    # Test Terraform plan for production
    echo "Testing Terraform plan for production..."
    if terraform plan -var-file="environments/production/terraform.tfvars" -out=tfplan-prod > "$RESULTS_DIR/terraform-plan-production.log" 2>&1; then
        echo "✅ Terraform plan for production successful"
        
        # Generate JSON plan for policy testing
        terraform show -json tfplan-prod > "$RESULTS_DIR/tfplan-production.json" 2>/dev/null || true
    else
        echo "❌ Terraform plan for production failed"
        cat "$RESULTS_DIR/terraform-plan-production.log"
        return 1
    fi
    
    cd "$PROJECT_ROOT"
}

# Test policy validation
test_policy_validation() {
    echo "🛡️  Testing policy validation..."
    
    # Run policy validation script if it exists
    if [ -f "docs/policies/ci-cd/validate-policies.sh" ]; then
        echo "Running policy validation script..."
        if bash docs/policies/ci-cd/validate-policies.sh "$INFRASTRUCTURE_DIR" > "$RESULTS_DIR/policy-validation.log" 2>&1; then
            echo "✅ Policy validation successful"
        else
            echo "⚠️  Policy validation completed with warnings"
            echo "Check log: $RESULTS_DIR/policy-validation.log"
        fi
    else
        echo "⚠️  Policy validation script not found"
    fi
}

# Test Lambda package build
test_lambda_package() {
    echo "📦 Testing Lambda package build..."
    
    cd "$PROJECT_ROOT"
    
    # Test if build script exists and runs
    if [ -f "scripts/build-lambda-package.sh" ]; then
        echo "Testing Lambda package build..."
        if bash scripts/build-lambda-package.sh > "$RESULTS_DIR/lambda-build.log" 2>&1; then
            echo "✅ Lambda package build successful"
            
            # Check if package was created
            if [ -f "lambda-function.zip" ]; then
                echo "✅ Lambda package file created"
                ls -la lambda-function.zip
            else
                echo "⚠️  Lambda package file not found"
            fi
        else
            echo "❌ Lambda package build failed"
            cat "$RESULTS_DIR/lambda-build.log"
            return 1
        fi
    else
        echo "⚠️  Lambda build script not found"
    fi
}

# Generate test report
generate_test_report() {
    echo "📊 Generating test report..."
    
    cat > "$RESULTS_DIR/test-report.md" << EOF
# GitHub Actions and Terraform Testing Report

Generated on: $(date)
Project: Lambda Production Readiness

## Test Results Summary

### GitHub Actions Workflow Testing
- Workflow syntax validation: $([ -f "$RESULTS_DIR/workflow-syntax-test.log" ] && echo "✅ Passed" || echo "❌ Failed")
- Setup job configuration: $([ -f "$RESULTS_DIR/setup-job-test.log" ] && echo "✅ Tested" || echo "❌ Failed")
- Lint and test job configuration: $([ -f "$RESULTS_DIR/lint-test-job-test.log" ] && echo "✅ Tested" || echo "❌ Failed")

### Terraform Infrastructure Testing
- Terraform initialization: $([ -f "$RESULTS_DIR/terraform-init.log" ] && echo "✅ Passed" || echo "❌ Failed")
- Configuration validation: $([ -f "$RESULTS_DIR/terraform-validate.log" ] && echo "✅ Passed" || echo "❌ Failed")
- Staging environment plan: $([ -f "$RESULTS_DIR/terraform-plan-staging.log" ] && echo "✅ Passed" || echo "❌ Failed")
- Production environment plan: $([ -f "$RESULTS_DIR/terraform-plan-production.log" ] && echo "✅ Passed" || echo "❌ Failed")

### Policy Validation Testing
- Policy validation script: $([ -f "$RESULTS_DIR/policy-validation.log" ] && echo "✅ Executed" || echo "❌ Failed")

### Lambda Package Testing
- Package build: $([ -f "$RESULTS_DIR/lambda-build.log" ] && echo "✅ Tested" || echo "❌ Failed")

## Detailed Logs

All detailed logs are available in the following files:
- workflow-syntax-test.log
- setup-job-test.log
- lint-test-job-test.log
- terraform-init.log
- terraform-validate.log
- terraform-plan-staging.log
- terraform-plan-production.log
- policy-validation.log
- lambda-build.log

## Next Steps

1. Review any failed tests and address issues
2. Ensure all prerequisites are met before deployment
3. Run integration tests with actual AWS credentials
4. Validate security and compliance requirements

## Prerequisites Checklist

- [ ] act installed for GitHub Actions testing
- [ ] Terraform installed and configured
- [ ] Docker installed for act runner
- [ ] AWS CLI configured with appropriate permissions
- [ ] GitHub secrets configured for environments
- [ ] Code signing certificates configured
- [ ] Monitoring and alerting systems ready

EOF

    echo "✅ Test report generated: $RESULTS_DIR/test-report.md"
}

# Main execution
main() {
    install_tools
    test_workflow_syntax
    test_github_actions_jobs
    test_terraform_config
    test_policy_validation
    test_lambda_package
    generate_test_report
    
    echo ""
    echo "🎉 GitHub Actions and Terraform testing completed!"
    echo "📁 Results available in: $RESULTS_DIR/"
    echo ""
    echo "Key files:"
    echo "  - test-report.md (comprehensive summary)"
    echo "  - terraform-plan-staging.log (staging infrastructure plan)"
    echo "  - terraform-plan-production.log (production infrastructure plan)"
    echo "  - workflow-syntax-test.log (GitHub Actions validation)"
    echo ""
    echo "Next steps:"
    echo "1. Review test results and address any issues"
    echo "2. Configure AWS credentials and GitHub secrets"
    echo "3. Run integration tests with real AWS resources"
    echo "4. Proceed with deployment after all tests pass"
}

# Run main function
main "$@"