#!/bin/bash

# GitHub Secrets Setup Script
# This script helps you set up the required GitHub secrets for OIDC authentication

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

echo "🔐 GitHub Secrets Setup for OIDC Authentication"
echo "================================================"

# Get repository info
REPO_OWNER=${1:-"snblaise"}
REPO_NAME=${2:-"serverlessapplication"}
REPO_FULL_NAME="$REPO_OWNER/$REPO_NAME"

print_status "INFO" "Setting up secrets for repository: $REPO_FULL_NAME"
echo ""

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    print_status "ERROR" "GitHub CLI (gh) is not installed"
    echo "   Install it from: https://cli.github.com/"
    exit 1
fi

# Check if user is authenticated
if ! gh auth status &> /dev/null; then
    print_status "ERROR" "Not authenticated with GitHub CLI"
    echo "   Run: gh auth login"
    exit 1
fi

# Get AWS Account ID
print_status "INFO" "Getting AWS Account ID..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null || echo "")

if [[ -z "$AWS_ACCOUNT_ID" ]]; then
    print_status "ERROR" "Could not get AWS Account ID. Make sure AWS CLI is configured."
    exit 1
fi

print_status "OK" "AWS Account ID: $AWS_ACCOUNT_ID"

# Default role names
STAGING_ROLE_NAME="GitHubActions-Lambda-Staging"
PROD_ROLE_NAME="GitHubActions-Lambda-Production"

echo ""
print_status "INFO" "Setting up GitHub secrets..."

# Set AWS Account ID secrets
echo "Setting AWS_ACCOUNT_ID_STAGING..."
if gh secret set AWS_ACCOUNT_ID_STAGING --body "$AWS_ACCOUNT_ID" --repo "$REPO_FULL_NAME"; then
    print_status "OK" "AWS_ACCOUNT_ID_STAGING set successfully"
else
    print_status "ERROR" "Failed to set AWS_ACCOUNT_ID_STAGING"
fi

echo "Setting AWS_ACCOUNT_ID_PROD..."
if gh secret set AWS_ACCOUNT_ID_PROD --body "$AWS_ACCOUNT_ID" --repo "$REPO_FULL_NAME"; then
    print_status "OK" "AWS_ACCOUNT_ID_PROD set successfully"
else
    print_status "ERROR" "Failed to set AWS_ACCOUNT_ID_PROD"
fi

# Set role name secrets
echo "Setting AWS_ROLE_NAME_STAGING..."
if gh secret set AWS_ROLE_NAME_STAGING --body "$STAGING_ROLE_NAME" --repo "$REPO_FULL_NAME"; then
    print_status "OK" "AWS_ROLE_NAME_STAGING set successfully"
else
    print_status "ERROR" "Failed to set AWS_ROLE_NAME_STAGING"
fi

echo "Setting AWS_ROLE_NAME_PROD..."
if gh secret set AWS_ROLE_NAME_PROD --body "$PROD_ROLE_NAME" --repo "$REPO_FULL_NAME"; then
    print_status "OK" "AWS_ROLE_NAME_PROD set successfully"
else
    print_status "ERROR" "Failed to set AWS_ROLE_NAME_PROD"
fi

echo ""
print_status "INFO" "Verifying secrets..."

# List secrets to verify
SECRETS=$(gh secret list --repo "$REPO_FULL_NAME" --json name --jq '.[].name' 2>/dev/null || echo "")

if echo "$SECRETS" | grep -q "AWS_ACCOUNT_ID_STAGING"; then
    print_status "OK" "AWS_ACCOUNT_ID_STAGING verified"
else
    print_status "WARNING" "AWS_ACCOUNT_ID_STAGING not found"
fi

if echo "$SECRETS" | grep -q "AWS_ACCOUNT_ID_PROD"; then
    print_status "OK" "AWS_ACCOUNT_ID_PROD verified"
else
    print_status "WARNING" "AWS_ACCOUNT_ID_PROD not found"
fi

if echo "$SECRETS" | grep -q "AWS_ROLE_NAME_STAGING"; then
    print_status "OK" "AWS_ROLE_NAME_STAGING verified"
else
    print_status "WARNING" "AWS_ROLE_NAME_STAGING not found"
fi

if echo "$SECRETS" | grep -q "AWS_ROLE_NAME_PROD"; then
    print_status "OK" "AWS_ROLE_NAME_PROD verified"
else
    print_status "WARNING" "AWS_ROLE_NAME_PROD not found"
fi

echo ""
print_status "INFO" "GitHub Secrets Summary:"
echo "   Repository: $REPO_FULL_NAME"
echo "   AWS Account ID: $AWS_ACCOUNT_ID"
echo "   Staging Role: $STAGING_ROLE_NAME"
echo "   Production Role: $PROD_ROLE_NAME"

echo ""
print_status "INFO" "Expected Role ARNs in workflows:"
echo "   Staging: arn:aws:iam::$AWS_ACCOUNT_ID:role/$STAGING_ROLE_NAME"
echo "   Production: arn:aws:iam::$AWS_ACCOUNT_ID:role/$PROD_ROLE_NAME"

echo ""
print_status "OK" "GitHub secrets setup complete!"
print_status "INFO" "You can now run your GitHub Actions workflows with OIDC authentication."

# Optional: Show how to manually set secrets
echo ""
echo "📝 Manual Secret Setup (if script fails):"
echo "   Go to: https://github.com/$REPO_FULL_NAME/settings/secrets/actions"
echo "   Add these secrets:"
echo "   - AWS_ACCOUNT_ID_STAGING = $AWS_ACCOUNT_ID"
echo "   - AWS_ACCOUNT_ID_PROD = $AWS_ACCOUNT_ID"
echo "   - AWS_ROLE_NAME_STAGING = $STAGING_ROLE_NAME"
echo "   - AWS_ROLE_NAME_PROD = $PROD_ROLE_NAME"