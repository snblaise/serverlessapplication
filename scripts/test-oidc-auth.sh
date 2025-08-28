#!/bin/bash

# Test OIDC Authentication Script
# This script helps debug OIDC authentication issues

set -e

echo "🔍 Testing OIDC Authentication Setup"
echo "======================================"

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed"
    exit 1
fi

echo "✅ AWS CLI is available"

# Check OIDC Provider
echo ""
echo "🔍 Checking OIDC Provider..."
OIDC_PROVIDER=$(aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[?contains(Arn, `token.actions.githubusercontent.com`)].Arn' --output text)

if [[ -n "$OIDC_PROVIDER" ]]; then
    echo "✅ OIDC Provider found: $OIDC_PROVIDER"
else
    echo "❌ OIDC Provider not found"
    exit 1
fi

# Check Security Scan Role
echo ""
echo "🔍 Checking Security Scan Role..."
ROLE_NAME="GitHubActions-SecurityScan"

if aws iam get-role --role-name "$ROLE_NAME" &> /dev/null; then
    echo "✅ Role exists: $ROLE_NAME"
    
    # Get role ARN
    ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)
    echo "   ARN: $ROLE_ARN"
    
    # Check trust policy
    echo ""
    echo "🔍 Checking Trust Policy..."
    aws iam get-role --role-name "$ROLE_NAME" --query 'Role.AssumeRolePolicyDocument' --output json | jq .
    
    # Check attached policies
    echo ""
    echo "🔍 Checking Attached Policies..."
    aws iam list-role-policies --role-name "$ROLE_NAME" --query 'PolicyNames' --output table
    
    # Check policy permissions
    echo ""
    echo "🔍 Checking Policy Permissions..."
    POLICY_NAME=$(aws iam list-role-policies --role-name "$ROLE_NAME" --query 'PolicyNames[0]' --output text)
    if [[ "$POLICY_NAME" != "None" ]]; then
        aws iam get-role-policy --role-name "$ROLE_NAME" --policy-name "$POLICY_NAME" --query 'PolicyDocument.Statement' --output json | jq .
    fi
    
else
    echo "❌ Role not found: $ROLE_NAME"
    exit 1
fi

# Check CloudFormation stack
echo ""
echo "🔍 Checking CloudFormation Stack..."
STACK_NAME="lambda-infrastructure-staging"

if aws cloudformation describe-stacks --stack-name "$STACK_NAME" &> /dev/null; then
    echo "✅ Stack exists: $STACK_NAME"
    
    # Get stack outputs
    echo ""
    echo "🔍 Stack Outputs:"
    aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query 'Stacks[0].Outputs[?OutputKey==`GitHubActionsSecurityScanRoleArn`]' --output table
    
else
    echo "❌ Stack not found: $STACK_NAME"
    exit 1
fi

echo ""
echo "🎉 OIDC Authentication setup appears to be correct!"
echo ""
echo "If GitHub Actions is still failing, the issue might be:"
echo "1. GitHub repository settings (Actions permissions)"
echo "2. Workflow file syntax or configuration"
echo "3. Timing issues with role assumption"
echo "4. GitHub's OIDC token format changes"
echo ""
echo "Check the GitHub Actions logs for more specific error messages."