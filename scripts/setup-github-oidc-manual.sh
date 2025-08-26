#!/bin/bash

# Manual Bootstrap Setup for GitHub Actions OIDC
# Run this script if you need to set up OIDC roles manually before running the workflow

set -e

echo "🚀 Manual Bootstrap Setup for GitHub Actions OIDC"
echo "=================================================="
echo ""
echo "This script will create the foundational AWS infrastructure needed"
echo "for GitHub Actions to authenticate with AWS using OIDC."
echo ""

# Check if AWS credentials are configured
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "❌ AWS credentials not configured. Please run:"
    echo "   aws configure"
    echo "   or set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables"
    exit 1
fi

echo "✅ AWS credentials configured"
echo "Account: $(aws sts get-caller-identity --query Account --output text)"
echo "Region: $(aws configure get region || echo "us-east-1")"
echo ""

# Confirm before proceeding
read -p "Do you want to proceed with bootstrap infrastructure deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Bootstrap deployment cancelled"
    exit 1
fi

echo "🏗️ Deploying bootstrap infrastructure..."
echo ""

# Run the bootstrap deployment script
cd "$(dirname "$0")"
chmod +x deploy-bootstrap.sh
./deploy-bootstrap.sh

echo ""
echo "✅ Bootstrap deployment completed!"
echo ""
echo "📋 Next Steps:"
echo "1. Copy the role ARNs from the output above"
echo "2. Add them to your GitHub repository secrets:"
echo "   - Go to: https://github.com/snblaise/serverlessapplication/settings/secrets/actions"
echo "   - Add the following secrets:"
echo "     * AWS_STAGING_ROLE_ARN"
echo "     * AWS_PRODUCTION_ROLE_ARN" 
echo "     * AWS_SECURITY_SCAN_ROLE_ARN"
echo "3. Run the GitHub Actions workflow"
echo ""
echo "🎯 Ready to run: gh workflow run \"Lambda CI/CD Pipeline\" --field environment=staging"