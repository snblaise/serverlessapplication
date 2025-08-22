#!/bin/bash

# Check GitHub OIDC setup status
# Usage: ./scripts/check-github-oidc.sh [environment]

set -euo pipefail

# Configuration
ENVIRONMENT="${1:-staging}"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo "[INFO] 🔍 Checking GitHub OIDC setup..."
echo "[INFO] Environment: $ENVIRONMENT"
echo "[INFO] Region: $AWS_REGION"

# Check AWS credentials
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "[ERROR] ❌ AWS credentials not configured"
    exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "[INFO] AWS Account ID: $AWS_ACCOUNT_ID"

echo ""
echo "🔐 OIDC Provider Check:"

# Check if OIDC provider exists
if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com" >/dev/null 2>&1; then
    echo "  ✅ GitHub OIDC provider exists"
    
    # Get provider details
    PROVIDER_INFO=$(aws iam get-open-id-connect-provider \
        --open-id-connect-provider-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com" \
        --query '{ClientIDList: ClientIDList, ThumbprintList: ThumbprintList}' \
        --output json)
    
    echo "  📋 Provider details:"
    echo "$PROVIDER_INFO" | jq .
else
    echo "  ❌ GitHub OIDC provider not found"
    echo "  💡 Run: ./scripts/setup-github-oidc.sh <your-repo> $ENVIRONMENT"
fi

echo ""
echo "👤 IAM Role Check:"

# Check if IAM role exists
ROLE_NAME="GitHubActions-Lambda-${ENVIRONMENT^}"
if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
    echo "  ✅ IAM role exists: $ROLE_NAME"
    
    # Get role ARN
    ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)
    echo "  📋 Role ARN: $ROLE_ARN"
    
    # Check trust policy
    echo "  🔒 Trust policy:"
    aws iam get-role --role-name "$ROLE_NAME" --query 'Role.AssumeRolePolicyDocument' --output json | jq .
    
    # Check attached policies
    echo "  📜 Attached policies:"
    aws iam list-role-policies --role-name "$ROLE_NAME" --query 'PolicyNames' --output table
    
else
    echo "  ❌ IAM role not found: $ROLE_NAME"
    echo "  💡 Run: ./scripts/setup-github-oidc.sh <your-repo> $ENVIRONMENT"
fi

echo ""
echo "🔧 GitHub Actions Workflow Check:"

# Check if workflow file exists
if [[ -f ".github/workflows/lambda-cicd.yml" ]]; then
    echo "  ✅ GitHub Actions workflow file exists"
    
    # Check for OIDC configuration in workflow
    if grep -q "id-token: write" .github/workflows/lambda-cicd.yml; then
        echo "  ✅ OIDC permissions configured in workflow"
    else
        echo "  ⚠️  OIDC permissions not found in workflow"
    fi
    
    if grep -q "aws-actions/configure-aws-credentials@v4" .github/workflows/lambda-cicd.yml; then
        echo "  ✅ AWS credentials action configured"
    else
        echo "  ⚠️  AWS credentials action not found"
    fi
    
else
    echo "  ❌ GitHub Actions workflow file not found"
    echo "  💡 Expected: .github/workflows/lambda-cicd.yml"
fi

echo ""
echo "📊 Summary:"

# Count issues
ISSUES=0

# Check OIDC provider
if ! aws iam get-open-id-connect-provider --open-id-connect-provider-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com" >/dev/null 2>&1; then
    echo "  ❌ OIDC provider missing"
    ISSUES=$((ISSUES + 1))
fi

# Check IAM role
if ! aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
    echo "  ❌ IAM role missing"
    ISSUES=$((ISSUES + 1))
fi

# Check workflow file
if [[ ! -f ".github/workflows/lambda-cicd.yml" ]]; then
    echo "  ❌ Workflow file missing"
    ISSUES=$((ISSUES + 1))
fi

if [[ $ISSUES -eq 0 ]]; then
    echo "  ✅ All components are configured correctly!"
    echo ""
    echo "🚀 Next Steps:"
    echo "  1. Set GitHub repository secrets:"
    echo "     - AWS_ACCOUNT_ID_STAGING: $AWS_ACCOUNT_ID (for staging)"
    echo "     - AWS_ACCOUNT_ID_PROD: $AWS_ACCOUNT_ID (for production)"
    echo "  2. Push code to trigger GitHub Actions"
    echo "  3. Monitor workflow execution"
else
    echo "  ⚠️  Found $ISSUES issue(s) that need to be resolved"
    echo ""
    echo "🔧 Recommended Actions:"
    echo "  1. Run setup script: ./scripts/setup-github-oidc.sh <your-repo> $ENVIRONMENT"
    echo "  2. Check the troubleshooting guide: docs/GITHUB_OIDC_SETUP.md"
fi

echo ""
echo "🔗 Useful Commands:"
echo "  Check role:        aws iam get-role --role-name $ROLE_NAME"
echo "  List providers:    aws iam list-open-id-connect-providers"
echo "  Test assumption:   aws sts get-caller-identity (from GitHub Actions)"
echo ""
echo "📚 Documentation:"
echo "  Setup Guide:       docs/GITHUB_OIDC_SETUP.md"
echo "  Troubleshooting:   docs/GITHUB_OIDC_SETUP.md#troubleshooting"