#!/bin/bash

# CloudFormation Template Validation Script
# Validates CloudFormation templates and parameters

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

# Function to show usage
show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --template FILE    CloudFormation template file to validate"
    echo "  --parameters FILE  Parameters file to validate"
    echo "  --lint            Run cfn-lint validation"
    echo "  --security        Run security analysis"
    echo "  --all             Run all validations"
    echo "  --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --all"
    echo "  $0 --template cloudformation/lambda-infrastructure.yml"
    echo "  $0 --template cloudformation/lambda-infrastructure.yml --parameters cloudformation/parameters/staging.json"
}

# Default values
TEMPLATE_FILE="cloudformation/lambda-infrastructure.yml"
PARAMETERS_FILE=""
RUN_LINT=false
RUN_SECURITY=false
RUN_ALL=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --template)
            TEMPLATE_FILE="$2"
            shift 2
            ;;
        --parameters)
            PARAMETERS_FILE="$2"
            shift 2
            ;;
        --lint)
            RUN_LINT=true
            shift
            ;;
        --security)
            RUN_SECURITY=true
            shift
            ;;
        --all)
            RUN_ALL=true
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# If --all is specified, enable all validations
if [[ "$RUN_ALL" == true ]]; then
    RUN_LINT=true
    RUN_SECURITY=true
fi

print_status "CloudFormation Template Validation"
print_status "Template: $TEMPLATE_FILE"
if [[ -n "$PARAMETERS_FILE" ]]; then
    print_status "Parameters: $PARAMETERS_FILE"
fi
echo ""

# Check if AWS CLI is configured
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed"
    exit 1
fi

if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS CLI is not configured or credentials are invalid"
    exit 1
fi

# Check if template file exists
if [[ ! -f "$TEMPLATE_FILE" ]]; then
    print_error "Template file not found: $TEMPLATE_FILE"
    exit 1
fi

# Check if parameters file exists (if specified)
if [[ -n "$PARAMETERS_FILE" && ! -f "$PARAMETERS_FILE" ]]; then
    print_error "Parameters file not found: $PARAMETERS_FILE"
    exit 1
fi

# Validate CloudFormation template syntax
print_status "Validating CloudFormation template syntax..."
if aws cloudformation validate-template --template-body file://"$TEMPLATE_FILE" > /dev/null; then
    print_success "Template syntax validation passed"
else
    print_error "Template syntax validation failed"
    exit 1
fi

# Validate parameters file format (if specified)
if [[ -n "$PARAMETERS_FILE" ]]; then
    print_status "Validating parameters file format..."
    if jq empty "$PARAMETERS_FILE" 2>/dev/null; then
        print_success "Parameters file format validation passed"
    else
        print_error "Parameters file format validation failed - invalid JSON"
        exit 1
    fi
    
    # Check parameter structure
    if jq -e 'type == "array" and all(type == "object" and has("ParameterKey") and has("ParameterValue"))' "$PARAMETERS_FILE" > /dev/null; then
        print_success "Parameters file structure validation passed"
    else
        print_error "Parameters file structure validation failed - must be array of objects with ParameterKey and ParameterValue"
        exit 1
    fi
fi

# Run cfn-lint validation
if [[ "$RUN_LINT" == true ]]; then
    print_status "Running cfn-lint validation..."
    
    # Check if cfn-lint is installed
    if ! command -v cfn-lint &> /dev/null; then
        print_warning "cfn-lint is not installed. Installing..."
        pip install cfn-lint
    fi
    
    if cfn-lint "$TEMPLATE_FILE"; then
        print_success "cfn-lint validation passed"
    else
        print_error "cfn-lint validation failed"
        exit 1
    fi
fi

# Run security analysis
if [[ "$RUN_SECURITY" == true ]]; then
    print_status "Running security analysis..."
    
    # Check for common security issues
    SECURITY_ISSUES=0
    
    # Check for hardcoded secrets
    if grep -i "password\|secret\|key" "$TEMPLATE_FILE" | grep -v "ParameterKey\|OutputKey\|SecretAccessKey\|AccessKey" > /dev/null; then
        print_warning "Potential hardcoded secrets found in template"
        SECURITY_ISSUES=$((SECURITY_ISSUES + 1))
    fi
    
    # Check for overly permissive IAM policies
    if grep -A 10 -B 5 '"Action".*"\*"' "$TEMPLATE_FILE" > /dev/null; then
        print_warning "Overly permissive IAM policies found (Action: '*')"
        SECURITY_ISSUES=$((SECURITY_ISSUES + 1))
    fi
    
    # Check for public S3 buckets
    if grep -A 5 -B 5 'PublicRead\|PublicReadWrite' "$TEMPLATE_FILE" > /dev/null; then
        print_warning "Potentially public S3 bucket configurations found"
        SECURITY_ISSUES=$((SECURITY_ISSUES + 1))
    fi
    
    # Check for missing encryption
    if ! grep -i 'encryption\|kms' "$TEMPLATE_FILE" > /dev/null; then
        print_warning "No encryption configuration found in template"
        SECURITY_ISSUES=$((SECURITY_ISSUES + 1))
    fi
    
    if [[ $SECURITY_ISSUES -eq 0 ]]; then
        print_success "Security analysis passed - no issues found"
    else
        print_warning "Security analysis completed with $SECURITY_ISSUES warnings"
    fi
fi

# Template analysis
print_status "Analyzing template structure..."

# Count resources
RESOURCE_COUNT=$(yq eval '.Resources | length' "$TEMPLATE_FILE")
print_status "Resources defined: $RESOURCE_COUNT"

# List resource types
print_status "Resource types:"
yq eval '.Resources | to_entries | .[].value.Type' "$TEMPLATE_FILE" | sort | uniq -c | sort -nr

# Check for outputs
OUTPUT_COUNT=$(yq eval '.Outputs | length' "$TEMPLATE_FILE")
print_status "Outputs defined: $OUTPUT_COUNT"

# Check for parameters
PARAMETER_COUNT=$(yq eval '.Parameters | length' "$TEMPLATE_FILE")
print_status "Parameters defined: $PARAMETER_COUNT"

# Validate parameter defaults
print_status "Checking parameter defaults..."
PARAMS_WITH_DEFAULTS=$(yq eval '.Parameters | to_entries | map(select(.value.Default)) | length' "$TEMPLATE_FILE")
print_status "Parameters with defaults: $PARAMS_WITH_DEFAULTS/$PARAMETER_COUNT"

# Check for conditions
CONDITION_COUNT=$(yq eval '.Conditions | length' "$TEMPLATE_FILE")
if [[ $CONDITION_COUNT -gt 0 ]]; then
    print_status "Conditions defined: $CONDITION_COUNT"
fi

# Estimate template size
TEMPLATE_SIZE=$(wc -c < "$TEMPLATE_FILE")
TEMPLATE_SIZE_KB=$((TEMPLATE_SIZE / 1024))
print_status "Template size: ${TEMPLATE_SIZE_KB}KB"

if [[ $TEMPLATE_SIZE_KB -gt 460 ]]; then
    print_warning "Template size is approaching CloudFormation limit (460KB)"
fi

echo ""
print_success "CloudFormation template validation completed successfully! ✅"
echo ""
print_status "Summary:"
echo "  ✅ Template syntax: Valid"
if [[ -n "$PARAMETERS_FILE" ]]; then
    echo "  ✅ Parameters file: Valid"
fi
if [[ "$RUN_LINT" == true ]]; then
    echo "  ✅ cfn-lint: Passed"
fi
if [[ "$RUN_SECURITY" == true ]]; then
    if [[ $SECURITY_ISSUES -eq 0 ]]; then
        echo "  ✅ Security analysis: Passed"
    else
        echo "  ⚠️  Security analysis: $SECURITY_ISSUES warnings"
    fi
fi
echo "  📊 Resources: $RESOURCE_COUNT"
echo "  📊 Parameters: $PARAMETER_COUNT"
echo "  📊 Outputs: $OUTPUT_COUNT"
echo "  📊 Template size: ${TEMPLATE_SIZE_KB}KB"