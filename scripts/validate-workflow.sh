#!/bin/bash

# GitHub Actions Workflow Validation Script
# This script validates the workflow file for common issues

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    local status=$1
    local message=$2
    if [[ "$status" == "OK" ]]; then
        echo -e "${GREEN}✅ $message${NC}"
    elif [[ "$status" == "WARNING" ]]; then
        echo -e "${YELLOW}⚠️  $message${NC}"
    elif [[ "$status" == "ERROR" ]]; then
        echo -e "${RED}❌ $message${NC}"
    else
        echo -e "${BLUE}ℹ️  $message${NC}"
    fi
}

echo "🔍 GitHub Actions Workflow Validation"
echo "====================================="

WORKFLOW_FILE=".github/workflows/lambda-cicd.yml"

# 1. Check if workflow file exists
if [[ ! -f "$WORKFLOW_FILE" ]]; then
    print_status "ERROR" "Workflow file not found: $WORKFLOW_FILE"
    exit 1
fi

print_status "OK" "Workflow file exists: $WORKFLOW_FILE"

# 2. Validate YAML syntax
echo ""
echo "1. Validating YAML syntax..."
if python3 -c "import yaml; yaml.safe_load(open('$WORKFLOW_FILE', 'r'))" 2>/dev/null; then
    print_status "OK" "YAML syntax is valid"
else
    print_status "ERROR" "YAML syntax is invalid"
    echo "   Run: python3 -c \"import yaml; yaml.safe_load(open('$WORKFLOW_FILE', 'r'))\""
    exit 1
fi

# 3. Check for required secrets
echo ""
echo "2. Checking for required secrets..."
REQUIRED_SECRETS=(
    "AWS_ACCOUNT_ID_STAGING"
    "AWS_ACCOUNT_ID_PROD"
    "AWS_ROLE_NAME_STAGING"
    "AWS_ROLE_NAME_PROD"
)

for secret in "${REQUIRED_SECRETS[@]}"; do
    if grep -q "\${{ secrets\.$secret }}" "$WORKFLOW_FILE"; then
        print_status "OK" "Secret referenced: $secret"
    else
        print_status "WARNING" "Secret not referenced: $secret"
    fi
done

# 4. Check for OIDC configuration
echo ""
echo "3. Checking OIDC configuration..."

# Check permissions
if grep -q "id-token: write" "$WORKFLOW_FILE"; then
    print_status "OK" "OIDC permission set: id-token: write"
else
    print_status "ERROR" "Missing OIDC permission: id-token: write"
fi

# Check audience parameter
AUDIENCE_COUNT=$(grep -c "audience: sts.amazonaws.com" "$WORKFLOW_FILE" || echo "0")
if [[ "$AUDIENCE_COUNT" -gt 0 ]]; then
    print_status "OK" "Audience parameter found in $AUDIENCE_COUNT locations"
else
    print_status "ERROR" "Missing audience parameter: audience: sts.amazonaws.com"
fi

# 5. Check for aws-actions/configure-aws-credentials usage
echo ""
echo "4. Checking AWS credentials configuration..."
AWS_CONFIG_COUNT=$(grep -c "aws-actions/configure-aws-credentials@v4" "$WORKFLOW_FILE" || echo "0")
if [[ "$AWS_CONFIG_COUNT" -gt 0 ]]; then
    print_status "OK" "AWS credentials action found in $AWS_CONFIG_COUNT locations"
else
    print_status "WARNING" "AWS credentials action not found"
fi

# 6. Check for role-to-assume parameter
ROLE_ASSUME_COUNT=$(grep -c "role-to-assume:" "$WORKFLOW_FILE" || echo "0")
if [[ "$ROLE_ASSUME_COUNT" -gt 0 ]]; then
    print_status "OK" "Role assumption configured in $ROLE_ASSUME_COUNT locations"
else
    print_status "ERROR" "Missing role-to-assume configuration"
fi

# 7. Check for environment outputs
echo ""
echo "5. Checking environment configuration..."
if grep -q "aws-role-arn:" "$WORKFLOW_FILE"; then
    print_status "OK" "AWS role ARN output configured"
else
    print_status "ERROR" "Missing AWS role ARN output"
fi

if grep -q "aws-region:" "$WORKFLOW_FILE"; then
    print_status "OK" "AWS region output configured"
else
    print_status "ERROR" "Missing AWS region output"
fi

# 8. Check for common issues
echo ""
echo "6. Checking for common issues..."

# Check for hardcoded values
if grep -q "948572562675" "$WORKFLOW_FILE"; then
    print_status "WARNING" "Hardcoded AWS Account ID found - consider using secrets"
fi

if grep -q "GitHubActions-Lambda-" "$WORKFLOW_FILE" | grep -v "secrets\." >/dev/null; then
    print_status "WARNING" "Hardcoded role name found - consider using secrets"
fi

# Check for proper indentation (common YAML issue)
if grep -q "^[[:space:]]*[[:space:]][[:space:]][[:space:]][[:space:]]" "$WORKFLOW_FILE"; then
    print_status "OK" "Proper YAML indentation detected"
else
    print_status "WARNING" "Check YAML indentation - use 2 spaces per level"
fi

echo ""
print_status "INFO" "Workflow validation complete!"

# 9. Show workflow summary
echo ""
echo "📋 Workflow Summary:"
echo "   File: $WORKFLOW_FILE"
echo "   Jobs: $(grep -c "^[[:space:]]*[a-zA-Z-]*:" "$WORKFLOW_FILE" | head -1)"
echo "   AWS Configurations: $AWS_CONFIG_COUNT"
echo "   OIDC Audience Settings: $AUDIENCE_COUNT"
echo "   Role Assumptions: $ROLE_ASSUME_COUNT"

echo ""
print_status "INFO" "To test the workflow:"
echo "   gh workflow run lambda-cicd.yml --repo snblaise/serverlessapplication"