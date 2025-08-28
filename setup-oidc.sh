#!/bin/bash

# Setup GitHub OIDC Provider for GitHub Actions
set -e

echo "🔧 Setting up GitHub OIDC Provider"

# Check AWS CLI configuration
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS CLI is not configured. Please run 'aws configure' first."
    exit 1
fi

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: ${ACCOUNT_ID}"

# Check if OIDC provider exists, create if not
echo "🔍 Checking GitHub OIDC provider..."
OIDC_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"

if ! aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN" &> /dev/null; then
    echo "🔧 Creating GitHub OIDC provider..."
    aws iam create-open-id-connect-provider \
        --url https://token.actions.githubusercontent.com \
        --client-id-list sts.amazonaws.com \
        --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 1c58a3a8518e8759bf075b76b750d4f2df264fcd
    
    echo "✅ OIDC provider created successfully!"
    echo "ARN: ${OIDC_ARN}"
else
    echo "✅ OIDC provider already exists"
    echo "ARN: ${OIDC_ARN}"
fi

echo ""
echo "🎉 Setup complete! You can now deploy your Lambda infrastructure."
echo ""
echo "Next steps:"
echo "1. Run: ./deploy.sh staging"
echo "2. Or push to GitHub to trigger automatic deployment"