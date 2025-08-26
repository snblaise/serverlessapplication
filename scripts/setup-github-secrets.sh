#!/bin/bash

# GitHub Secrets Setup Script
# This script helps you set up the required GitHub repository secrets for the CI/CD pipeline

set -e

echo "🔑 GitHub Secrets Setup for Lambda CI/CD Pipeline"
echo "================================================="
echo ""
echo "This script will help you configure the required GitHub repository secrets"
echo "for the AWS Lambda CI/CD pipeline to work properly."
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI (gh) is not installed.${NC}"
    echo "Please install it from: https://cli.github.com/"
    echo ""
    echo "On macOS: brew install gh"
    echo "On Ubuntu: sudo apt install gh"
    exit 1
fi

# Check if user is authenticated with GitHub CLI
if ! gh auth status &> /dev/null; then
    echo -e "${YELLOW}⚠️  You are not authenticated with GitHub CLI.${NC}"
    echo "Please run: gh auth login"
    exit 1
fi

echo -e "${GREEN}✅ GitHub CLI is installed and authenticated${NC}"

# Check if AWS CLI is installed and configured
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI is not installed.${NC}"
    echo "Please install it from: https://aws.amazon.com/cli/"
    exit 1
fi

# Check if AWS credentials are configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ AWS credentials are not configured.${NC}"
    echo "Please run: aws configure"
    echo "Or set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables"
    exit 1
fi

echo -e "${GREEN}✅ AWS CLI is installed and configured${NC}"

# Get AWS account information
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
AWS_REGION=$(aws configure get region || echo "us-east-1")

echo ""
echo -e "${BLUE}📋 Current AWS Configuration:${NC}"
echo "  Account ID: ${AWS_ACCOUNT_ID}"
echo "  User/Role: ${AWS_USER_ARN}"
echo "  Region: ${AWS_REGION}"
echo ""

# Get repository information
REPO_INFO=$(gh repo view --json owner,name)
REPO_OWNER=$(echo "$REPO_INFO" | jq -r '.owner.login')
REPO_NAME=$(echo "$REPO_INFO" | jq -r '.name')
REPO_FULL_NAME="${REPO_OWNER}/${REPO_NAME}"

echo -e "${BLUE}📋 Current Repository:${NC}"
echo "  Repository: ${REPO_FULL_NAME}"
echo ""

# Get AWS credentials
AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)
AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)

if [[ -z "$AWS_ACCESS_KEY_ID" || -z "$AWS_SECRET_ACCESS_KEY" ]]; then
    echo -e "${RED}❌ Could not retrieve AWS credentials from AWS CLI configuration.${NC}"
    echo "Please ensure your AWS credentials are properly configured with 'aws configure'"
    exit 1
fi

echo -e "${YELLOW}🔍 Found AWS Credentials:${NC}"
echo "  Access Key ID: ${AWS_ACCESS_KEY_ID:0:10}...${AWS_ACCESS_KEY_ID: -4}"
echo "  Secret Key: ${AWS_SECRET_ACCESS_KEY:0:6}...${AWS_SECRET_ACCESS_KEY: -4}"
echo ""

# Confirm before proceeding
echo -e "${YELLOW}⚠️  This script will add the following secrets to your GitHub repository:${NC}"
echo "  - AWS_ACCESS_KEY_ID"
echo "  - AWS_SECRET_ACCESS_KEY"
echo ""
read -p "Do you want to proceed? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}❌ Setup cancelled by user${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}🚀 Setting up GitHub repository secrets...${NC}"

# Set GitHub secrets
echo "Setting AWS_ACCESS_KEY_ID..."
if gh secret set AWS_ACCESS_KEY_ID --body "$AWS_ACCESS_KEY_ID" --repo "$REPO_FULL_NAME"; then
    echo -e "${GREEN}✅ AWS_ACCESS_KEY_ID secret set successfully${NC}"
else
    echo -e "${RED}❌ Failed to set AWS_ACCESS_KEY_ID secret${NC}"
    exit 1
fi

echo "Setting AWS_SECRET_ACCESS_KEY..."
if gh secret set AWS_SECRET_ACCESS_KEY --body "$AWS_SECRET_ACCESS_KEY" --repo "$REPO_FULL_NAME"; then
    echo -e "${GREEN}✅ AWS_SECRET_ACCESS_KEY secret set successfully${NC}"
else
    echo -e "${RED}❌ Failed to set AWS_SECRET_ACCESS_KEY secret${NC}"
    exit 1
fi

# Set AWS account ID secret (required for OIDC role ARN construction)
echo "Setting AWS_ACCOUNT_ID..."
if gh secret set AWS_ACCOUNT_ID --body "$AWS_ACCOUNT_ID" --repo "$REPO_FULL_NAME"; then
    echo -e "${GREEN}✅ AWS_ACCOUNT_ID secret set successfully${NC}"
else
    echo -e "${RED}❌ Failed to set AWS_ACCOUNT_ID secret${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 GitHub Secrets Setup Complete!${NC}"
echo ""
echo -e "${BLUE}📋 Summary of configured secrets:${NC}"

# List the secrets we just set
gh secret list --repo "$REPO_FULL_NAME" | grep -E "(AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY|AWS_ACCOUNT_ID)" || echo "  (Unable to list secrets - but they should be set)"

echo ""
echo -e "${BLUE}🚀 Next Steps:${NC}"
echo "1. The GitHub Actions workflow is now ready to run"
echo "2. Trigger the workflow manually:"
echo "   ${YELLOW}gh workflow run \"Lambda CI/CD Pipeline\" --field environment=staging${NC}"
echo ""
echo "3. Or push a commit to trigger it automatically:"
echo "   ${YELLOW}git commit --allow-empty -m \"trigger workflow\"${NC}"
echo "   ${YELLOW}git push origin main${NC}"
echo ""
echo -e "${BLUE}📖 What happens next:${NC}"
echo "  ⚠️  You need to deploy bootstrap infrastructure first: ./scripts/deploy-bootstrap.sh"
echo "  ✅ GitHub Actions will use OIDC authentication with the created roles"
echo "  ✅ Complete infrastructure will be deployed automatically"
echo "  ✅ Lambda function will be built and deployed"
echo ""
echo -e "${GREEN}🔒 Security Note:${NC}"
echo "AWS access keys are only used for bootstrap infrastructure deployment."
echo "The GitHub Actions workflow uses secure OIDC authentication with temporary credentials."
echo ""
echo -e "${BLUE}📚 For more information, see:${NC}"
echo "  - docs/GITHUB_ACTIONS_SETUP.md"
echo "  - docs/CICD_PIPELINE.md"
echo ""
echo -e "${GREEN}✨ Setup complete! Your CI/CD pipeline is ready to go!${NC}"