#!/bin/bash

# Quick Start Script for Lambda Production Readiness Package
# This script sets up everything needed to deploy the complete solution

set -e

echo "🚀 Lambda Production Readiness - Quick Start"
echo "==========================================="
echo ""
echo "This script will set up and deploy the complete Lambda production readiness solution."
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check prerequisites
echo -e "${BLUE}🔍 Checking prerequisites...${NC}"

# Check if we're in the right directory
if [[ ! -f "package.json" || ! -d "infrastructure" ]]; then
    echo -e "${RED}❌ Please run this script from the root of the serverlessapplication repository${NC}"
    exit 1
fi

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI (gh) is not installed.${NC}"
    echo "Please install it from: https://cli.github.com/"
    exit 1
fi

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI is not installed.${NC}"
    echo "Please install it from: https://aws.amazon.com/cli/"
    exit 1
fi

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Node.js is not installed.${NC}"
    echo "Please install it from: https://nodejs.org/"
    exit 1
fi

echo -e "${GREEN}✅ All prerequisites are installed${NC}"
echo ""

# Install dependencies
echo -e "${BLUE}📦 Installing Node.js dependencies...${NC}"
npm install
echo -e "${GREEN}✅ Dependencies installed${NC}"
echo ""

# Set up GitHub secrets
echo -e "${BLUE}🔑 Setting up GitHub repository secrets...${NC}"
if [[ -x "./scripts/setup-github-secrets.sh" ]]; then
    ./scripts/setup-github-secrets.sh
else
    echo -e "${RED}❌ setup-github-secrets.sh not found or not executable${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}🚀 Triggering GitHub Actions deployment...${NC}"

# Ask user which environment to deploy to
echo "Which environment would you like to deploy to?"
echo "1) staging (recommended for first deployment)"
echo "2) production"
read -p "Enter your choice (1 or 2): " env_choice

case $env_choice in
    1)
        ENVIRONMENT="staging"
        ;;
    2)
        ENVIRONMENT="production"
        ;;
    *)
        echo -e "${YELLOW}Invalid choice. Defaulting to staging.${NC}"
        ENVIRONMENT="staging"
        ;;
esac

echo ""
echo -e "${BLUE}Deploying to ${ENVIRONMENT} environment...${NC}"

# Trigger the workflow
if gh workflow run "Lambda CI/CD Pipeline" --field environment="$ENVIRONMENT"; then
    echo -e "${GREEN}✅ Workflow triggered successfully!${NC}"
else
    echo -e "${RED}❌ Failed to trigger workflow${NC}"
    exit 1
fi

# Get the run ID and provide monitoring commands
echo ""
echo -e "${BLUE}📊 Monitoring deployment...${NC}"
echo ""
echo "You can monitor the deployment progress with these commands:"
echo ""
echo -e "${YELLOW}# View workflow runs${NC}"
echo "gh run list --workflow=\"lambda-cicd.yml\""
echo ""
echo -e "${YELLOW}# Watch the latest run${NC}"
echo "gh run watch"
echo ""
echo -e "${YELLOW}# View logs for the latest run${NC}"
echo "gh run view --log"
echo ""

# Wait a moment and show the latest run
sleep 3
echo -e "${BLUE}📋 Latest workflow run:${NC}"
gh run list --workflow="lambda-cicd.yml" --limit=1

echo ""
echo -e "${GREEN}🎉 Quick Start Complete!${NC}"
echo ""
echo -e "${BLUE}📖 What's happening now:${NC}"
echo "  1. ✅ GitHub secrets configured"
echo "  2. 🔄 Bootstrap infrastructure deploying (OIDC roles)"
echo "  3. 🔄 Main infrastructure deploying (Lambda, monitoring, etc.)"
echo "  4. 🔄 Application building and deploying"
echo "  5. 🔄 Security scans and compliance checks running"
echo ""
echo -e "${BLUE}📚 Next Steps:${NC}"
echo "  - Monitor the deployment in GitHub Actions"
echo "  - Review the deployed resources in AWS Console"
echo "  - Check the Lambda function logs in CloudWatch"
echo "  - Review security findings in AWS Security Hub"
echo ""
echo -e "${BLUE}📖 Documentation:${NC}"
echo "  - GitHub Actions Setup: docs/GITHUB_ACTIONS_SETUP.md"
echo "  - CI/CD Pipeline: docs/CICD_PIPELINE.md"
echo "  - Implementation Guide: docs/IMPLEMENTATION_GUIDE.md"
echo ""
echo -e "${GREEN}🚀 Your Lambda production readiness solution is deploying!${NC}"