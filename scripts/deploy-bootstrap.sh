#!/bin/bash

# Deploy Bootstrap Infrastructure for GitHub Actions
# This script sets up the foundational AWS resources needed for the CI/CD pipeline

set -e

echo "🚀 Deploying Bootstrap Infrastructure for GitHub Actions"
echo "======================================================"

# Change to bootstrap directory
cd infrastructure/bootstrap

# Initialize Terraform
echo "1. Initializing Terraform..."
terraform init

# Validate configuration
echo "2. Validating Terraform configuration..."
terraform validate

# Plan the deployment
echo "3. Planning bootstrap infrastructure deployment..."
terraform plan -out=bootstrap.tfplan

# Apply the configuration
echo "4. Deploying bootstrap infrastructure..."
terraform apply bootstrap.tfplan

# Clean up plan file
rm -f bootstrap.tfplan

echo ""
echo "✅ Bootstrap Infrastructure Deployment Complete!"
echo ""
echo "📋 Summary of Created Resources:"
echo "   - GitHub OIDC Provider (if not exists)"
echo "   - IAM Role: GitHubActions-Lambda-Staging"
echo "   - IAM Role: GitHubActions-Lambda-Production"
echo "   - IAM Role: GitHubActions-SecurityScan"
echo "   - Comprehensive IAM policies for each role"
echo ""
echo "🔑 Role ARNs for GitHub Secrets:"
terraform output -json | jq -r '
  "AWS_STAGING_ROLE_ARN: " + .github_actions_staging_role_arn.value,
  "AWS_PRODUCTION_ROLE_ARN: " + .github_actions_production_role_arn.value,
  "AWS_SECURITY_SCAN_ROLE_ARN: " + .github_actions_security_scan_role_arn.value
'

echo ""
echo "ℹ️  Next Steps:"
echo "   1. Update GitHub repository secrets with the role ARNs above"
echo "   2. Run the GitHub Actions workflow to deploy the full infrastructure"
echo "   3. The pipeline should now be able to authenticate with AWS"
echo ""
echo "🎯 Ready to run: gh workflow run \"Lambda CI/CD Pipeline\" --field environment=staging"