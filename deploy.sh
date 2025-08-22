#!/bin/bash

# Quick GitHub Actions Deployment Script
# This script helps you deploy the GitHub Actions workflow quickly

set -e

echo "🚀 GitHub Actions Lambda CI/CD Deployment"
echo "=========================================="
echo ""

# Check if we're in the right directory
if [[ ! -f "package.json" ]] || [[ ! -f ".github/workflows/lambda-cicd.yml" ]]; then
    echo "❌ Error: This script must be run from the project root directory"
    echo "   Make sure you have package.json and .github/workflows/lambda-cicd.yml"
    exit 1
fi

# Run the deployment helper script
if [[ -f "scripts/deploy-github-actions.sh" ]]; then
    echo "📋 Running deployment preparation..."
    ./scripts/deploy-github-actions.sh
else
    echo "⚠️  Deployment helper script not found, running basic checks..."
    
    # Basic checks
    echo "🔍 Checking Node.js project..."
    npm ci
    npm run lint
    npm test
    
    echo ""
    echo "✅ Basic checks completed!"
    echo ""
    echo "📝 Next steps:"
    echo "1. Configure GitHub secrets (AWS_ACCOUNT_ID_STAGING, AWS_ACCOUNT_ID_PROD)"
    echo "2. Set up GitHub environments (staging, production)"
    echo "3. Go to Actions tab and run the 'Lambda CI/CD Pipeline' workflow"
    echo ""
    echo "📖 For detailed instructions, see: DEPLOY_GITHUB_ACTIONS.md"
fi