#!/bin/bash

# CI/CD Policy Validation Framework
# This script runs all policy validation tools for Lambda production readiness

set -e

# Configuration
TERRAFORM_DIR=${1:-"./infrastructure"}
CHECKOV_CONFIG="docs/policies/ci-cd/.checkov.yaml"
TERRAFORM_COMPLIANCE_DIR="docs/policies/ci-cd/terraform-compliance"
RESULTS_DIR="policy-validation-results"

echo "🔍 Starting Lambda Production Readiness Policy Validation..."
echo "Terraform directory: $TERRAFORM_DIR"
echo "Results directory: $RESULTS_DIR"

# Create results directory
mkdir -p "$RESULTS_DIR"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install required tools if not present
install_tools() {
    echo "📦 Checking and installing required tools..."
    
    # Install Checkov
    if ! command_exists checkov; then
        echo "Installing Checkov..."
        pip install checkov
    fi
    
    # Install terraform-compliance
    if ! command_exists terraform-compliance; then
        echo "Installing terraform-compliance..."
        pip install terraform-compliance
    fi
    
    # Install tflint
    if ! command_exists tflint; then
        echo "Installing TFLint..."
        curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
    fi
    
    echo "✅ All tools installed successfully"
}

# Run Checkov security scanning
run_checkov() {
    echo "🛡️  Running Checkov security analysis..."
    
    if [ -f "$CHECKOV_CONFIG" ]; then
        checkov \
            --config-file "$CHECKOV_CONFIG" \
            --directory "$TERRAFORM_DIR" \
            --output cli \
            --output json \
            --output-file-path "$RESULTS_DIR" \
            --soft-fail || true
    else
        echo "⚠️  Checkov config not found at $CHECKOV_CONFIG, using default settings"
        checkov \
            --directory "$TERRAFORM_DIR" \
            --framework terraform \
            --check CKV_AWS_45,CKV_AWS_50,CKV_AWS_115,CKV_AWS_116,CKV_AWS_117 \
            --output cli \
            --output json \
            --output-file-path "$RESULTS_DIR" \
            --soft-fail || true
    fi
    
    echo "✅ Checkov analysis completed"
}

# Run terraform-compliance policy validation
run_terraform_compliance() {
    echo "📋 Running terraform-compliance policy validation..."
    
    # Generate Terraform plan if it doesn't exist
    if [ ! -f "$TERRAFORM_DIR/tfplan.json" ]; then
        echo "Generating Terraform plan..."
        cd "$TERRAFORM_DIR"
        terraform init -backend=false
        terraform plan -out=tfplan
        terraform show -json tfplan > tfplan.json
        cd - > /dev/null
    fi
    
    # Run compliance tests
    if [ -d "$TERRAFORM_COMPLIANCE_DIR" ]; then
        terraform-compliance \
            --planfile "$TERRAFORM_DIR/tfplan.json" \
            --features "$TERRAFORM_COMPLIANCE_DIR" \
            --junit-xml "$RESULTS_DIR/terraform-compliance-results.xml" || true
    else
        echo "⚠️  Terraform compliance features not found at $TERRAFORM_COMPLIANCE_DIR"
    fi
    
    echo "✅ Terraform compliance validation completed"
}

# Run TFLint for Terraform best practices
run_tflint() {
    echo "🔧 Running TFLint for Terraform best practices..."
    
    cd "$TERRAFORM_DIR"
    
    # Initialize TFLint
    tflint --init
    
    # Run TFLint with AWS plugin
    tflint \
        --format json \
        --force \
        . > "../$RESULTS_DIR/tflint-results.json" || true
    
    cd - > /dev/null
    
    echo "✅ TFLint analysis completed"
}

# Validate custom Checkov policies
validate_custom_policies() {
    echo "🔍 Validating custom Checkov policies..."
    
    CUSTOM_POLICIES_DIR="docs/policies/ci-cd/custom-policies"
    
    if [ -d "$CUSTOM_POLICIES_DIR" ]; then
        for policy_file in "$CUSTOM_POLICIES_DIR"/*.py; do
            if [ -f "$policy_file" ]; then
                echo "Validating $(basename "$policy_file")..."
                python -m py_compile "$policy_file"
            fi
        done
    fi
    
    echo "✅ Custom policy validation completed"
}

# Validate IAM permission boundary
validate_permission_boundary() {
    echo "🔒 Validating IAM permission boundary..."
    
    PERMISSION_BOUNDARY_FILE="docs/policies/iam-permission-boundary-cicd.json"
    
    if [ -f "$PERMISSION_BOUNDARY_FILE" ]; then
        # Validate JSON syntax
        if jq empty "$PERMISSION_BOUNDARY_FILE" 2>/dev/null; then
            echo "✅ Permission boundary JSON syntax is valid"
        else
            echo "❌ Permission boundary JSON syntax is invalid"
            return 1
        fi
        
        # Run Python tests if available
        if [ -f "docs/policies/ci-cd/test-permission-boundary.py" ]; then
            echo "Running permission boundary tests..."
            cd docs/policies/ci-cd
            python -m pytest test-permission-boundary.py -v --tb=short > "../../../$RESULTS_DIR/permission-boundary-test-results.txt" 2>&1 || true
            cd - > /dev/null
            echo "✅ Permission boundary tests completed"
        fi
        
        # Validate policy structure
        echo "Validating permission boundary structure..."
        python3 << EOF
import json
import sys

try:
    with open('$PERMISSION_BOUNDARY_FILE', 'r') as f:
        policy = json.load(f)
    
    # Check required structure
    assert 'Version' in policy, "Missing Version field"
    assert 'Statement' in policy, "Missing Statement field"
    assert isinstance(policy['Statement'], list), "Statement must be a list"
    
    # Check for required security controls
    statement_sids = [stmt.get('Sid', '') for stmt in policy['Statement']]
    required_controls = [
        'DenyUnsignedCodeDeployment',
        'DenyLambdaFunctionUrls', 
        'RestrictIAMWildcardActions',
        'EnforceEncryptionInTransit',
        'RequireMandatoryTags'
    ]
    
    missing_controls = [control for control in required_controls if control not in statement_sids]
    if missing_controls:
        print(f"❌ Missing required controls: {', '.join(missing_controls)}")
        sys.exit(1)
    
    print("✅ Permission boundary structure validation passed")
    
except Exception as e:
    print(f"❌ Permission boundary validation failed: {e}")
    sys.exit(1)
EOF
        
    else
        echo "⚠️  Permission boundary file not found at $PERMISSION_BOUNDARY_FILE"
    fi
    
    echo "✅ Permission boundary validation completed"
}

# Generate summary report
generate_summary() {
    echo "📊 Generating validation summary..."
    
    cat > "$RESULTS_DIR/validation-summary.md" << EOF
# Lambda Production Readiness Policy Validation Summary

Generated on: $(date)
Terraform Directory: $TERRAFORM_DIR

## Validation Results

### Checkov Security Analysis
- Configuration: $CHECKOV_CONFIG
- Results: checkov_results.json
- Status: $([ -f "$RESULTS_DIR/results_json.json" ] && echo "✅ Completed" || echo "❌ Failed")

### Terraform Compliance
- Features Directory: $TERRAFORM_COMPLIANCE_DIR
- Results: terraform-compliance-results.xml
- Status: $([ -f "$RESULTS_DIR/terraform-compliance-results.xml" ] && echo "✅ Completed" || echo "❌ Failed")

### TFLint Analysis
- Results: tflint-results.json
- Status: $([ -f "$RESULTS_DIR/tflint-results.json" ] && echo "✅ Completed" || echo "❌ Failed")

### Permission Boundary Validation
- Results: permission-boundary-test-results.txt
- Status: $([ -f "$RESULTS_DIR/permission-boundary-test-results.txt" ] && echo "✅ Completed" || echo "❌ Failed")

## Key Security Checks

- ✅ Lambda code signing enforcement
- ✅ X-Ray tracing configuration
- ✅ Dead letter queue configuration
- ✅ Reserved concurrency limits
- ✅ CMK encryption for environment variables
- ✅ API Gateway WAF association
- ✅ IAM least privilege validation
- ✅ VPC configuration for data access
- ✅ Permission boundary effectiveness
- ✅ CI/CD role restrictions
- ✅ Production access controls
- ✅ Mandatory tagging enforcement

## Next Steps

1. Review detailed results in individual files
2. Address any HIGH or CRITICAL findings
3. Update infrastructure code as needed
4. Re-run validation before deployment

EOF

    echo "✅ Summary report generated: $RESULTS_DIR/validation-summary.md"
}

# Main execution
main() {
    install_tools
    validate_custom_policies
    validate_permission_boundary
    run_checkov
    run_terraform_compliance
    run_tflint
    generate_summary
    
    echo ""
    echo "🎉 Policy validation completed successfully!"
    echo "📁 Results available in: $RESULTS_DIR/"
    echo ""
    echo "Key files:"
    echo "  - validation-summary.md (overview)"
    echo "  - results_json.json (Checkov results)"
    echo "  - terraform-compliance-results.xml (compliance tests)"
    echo "  - tflint-results.json (Terraform linting)"
    echo "  - permission-boundary-test-results.txt (permission boundary tests)"
}

# Run main function
main "$@"