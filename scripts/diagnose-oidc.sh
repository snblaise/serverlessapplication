#!/bin/bash

# GitHub OIDC Diagnostic Script
# This script helps diagnose common OIDC authentication issues

set -e

echo "🔍 GitHub OIDC Diagnostic Tool"
echo "================================"

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

# Get repository info
REPO_OWNER=${1:-"snblaise"}
REPO_NAME=${2:-"serverlessapplication"}
ENVIRONMENT=${3:-"staging"}

print_status "INFO" "Checking OIDC setup for repository: $REPO_OWNER/$REPO_NAME"
print_status "INFO" "Environment: $ENVIRONMENT"
echo ""

# 1. Check if OIDC provider exists
echo "1. Checking GitHub OIDC Provider..."
if aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[?contains(Arn, `token.actions.githubusercontent.com`)]' --output text | grep -q "token.actions.githubusercontent.com"; then
    OIDC_ARN=$(aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[?contains(Arn, `token.actions.githubusercontent.com`)].Arn' --output text)
    print_status "OK" "GitHub OIDC provider exists: $OIDC_ARN"
else
    print_status "ERROR" "GitHub OIDC provider not found"
    echo "   Run: aws iam create-open-id-connect-provider --url https://token.actions.githubusercontent.com --client-id-list sts.amazonaws.com --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 1c58a3a8518e8759bf075b76b750d4f2df264fcd"
    exit 1
fi

# 2. Check if IAM role exists
echo ""
echo "2. Checking IAM Role..."
if [[ "${ENVIRONMENT}" == "production" ]]; then
    ROLE_NAME="GitHubActions-Lambda-Production"
else
    ROLE_NAME="GitHubActions-Lambda-Staging"
fi
if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
    ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)
    print_status "OK" "IAM role exists: $ROLE_ARN"
else
    print_status "ERROR" "IAM role not found: $ROLE_NAME"
    echo "   Create the role using the setup script or Terraform"
    exit 1
fi

# 3. Check trust policy
echo ""
echo "3. Checking Trust Policy..."
TRUST_POLICY=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.AssumeRolePolicyDocument' --output json)

# Check if trust policy contains correct conditions
if echo "$TRUST_POLICY" | jq -e '.Statement[0].Condition.StringEquals."token.actions.githubusercontent.com:aud" == "sts.amazonaws.com"' >/dev/null; then
    print_status "OK" "Trust policy has correct audience condition"
else
    print_status "ERROR" "Trust policy missing or incorrect audience condition"
    echo "   Expected: token.actions.githubusercontent.com:aud = sts.amazonaws.com"
fi

if echo "$TRUST_POLICY" | jq -e --arg repo "repo:$REPO_OWNER/$REPO_NAME" '.Statement[0].Condition.StringLike."token.actions.githubusercontent.com:sub" | if type == "array" then any(test($repo)) else test($repo) end' >/dev/null; then
    print_status "OK" "Trust policy allows repository: $REPO_OWNER/$REPO_NAME"
else
    print_status "ERROR" "Trust policy does not allow repository: $REPO_OWNER/$REPO_NAME"
    echo "   Current subject conditions:"
    echo "$TRUST_POLICY" | jq -r '.Statement[0].Condition.StringLike."token.actions.githubusercontent.com:sub"'
fi

# 4. Check role permissions
echo ""
echo "4. Checking Role Permissions..."
POLICY_NAMES=$(aws iam list-role-policies --role-name "$ROLE_NAME" --query 'PolicyNames' --output text)
if [[ -n "$POLICY_NAMES" ]]; then
    print_status "OK" "Role has inline policies: $POLICY_NAMES"
else
    print_status "WARNING" "Role has no inline policies"
fi

ATTACHED_POLICIES=$(aws iam list-attached-role-policies --role-name "$ROLE_NAME" --query 'AttachedPolicies[].PolicyName' --output text)
if [[ -n "$ATTACHED_POLICIES" ]]; then
    print_status "OK" "Role has attached policies: $ATTACHED_POLICIES"
else
    print_status "WARNING" "Role has no attached policies"
fi

# 5. Check AWS account ID
echo ""
echo "5. Checking AWS Account..."
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
print_status "OK" "Current AWS Account ID: $ACCOUNT_ID"

# 6. Generate GitHub secrets configuration
echo ""
echo "6. GitHub Secrets Configuration:"
print_status "INFO" "Add these secrets to your GitHub repository:"
echo "   AWS_ACCOUNT_ID_STAGING = $ACCOUNT_ID"
echo "   AWS_ACCOUNT_ID_PROD = $ACCOUNT_ID"

# 7. Show expected role ARN format
echo ""
echo "7. Expected Role ARN in Workflow:"
print_status "INFO" "Your workflow should use this ARN:"
echo "   arn:aws:iam::$ACCOUNT_ID:role/GitHubActions-Lambda-Staging"
echo "   arn:aws:iam::$ACCOUNT_ID:role/GitHubActions-Lambda-Production"

# 8. Show trust policy template
echo ""
echo "8. Correct Trust Policy Template:"
cat << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "$OIDC_ARN"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:$REPO_OWNER/$REPO_NAME:ref:refs/heads/main",
            "repo:$REPO_OWNER/$REPO_NAME:ref:refs/heads/develop",
            "repo:$REPO_OWNER/$REPO_NAME:pull_request"
          ]
        }
      }
    }
  ]
}
EOF

echo ""
print_status "INFO" "Diagnostic complete! Check the items marked with ❌ or ⚠️"