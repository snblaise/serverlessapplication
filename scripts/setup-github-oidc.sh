#!/bin/bash

# Setup GitHub OIDC integration for AWS
# Usage: ./scripts/setup-github-oidc.sh [github-repo] [environment]

set -euo pipefail

# Configuration
GITHUB_REPO="${1:-}"
ENVIRONMENT="${2:-staging}"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo "[INFO] 🔐 Setting up GitHub OIDC integration..."
echo "[INFO] Environment: $ENVIRONMENT"
echo "[INFO] Region: $AWS_REGION"

# Validate inputs
if [[ -z "$GITHUB_REPO" ]]; then
    echo "[ERROR] GitHub repository is required"
    echo "Usage: $0 <github-repo> [environment]"
    echo "Example: $0 myorg/myrepo staging"
    exit 1
fi

if [[ ! "$GITHUB_REPO" =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]]; then
    echo "[ERROR] Invalid GitHub repository format. Use 'owner/repo'"
    exit 1
fi

echo "[INFO] GitHub Repository: $GITHUB_REPO"

# Check prerequisites
if ! command -v terraform &> /dev/null; then
    echo "[ERROR] Terraform is not installed"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo "[ERROR] AWS CLI is not installed"
    exit 1
fi

if ! command -v gh &> /dev/null; then
    echo "[WARNING] GitHub CLI is not installed. You'll need to set secrets manually."
    GITHUB_CLI_AVAILABLE=false
else
    GITHUB_CLI_AVAILABLE=true
fi

# Check AWS credentials
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "[ERROR] AWS credentials not configured"
    exit 1
fi

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "[INFO] AWS Account ID: $AWS_ACCOUNT_ID"

# Navigate to infrastructure directory
cd infrastructure

# Initialize Terraform if needed
if [[ ! -d ".terraform" ]]; then
    echo "[INFO] 🔧 Initializing Terraform..."
    terraform init
fi

# Select or create workspace
if ! terraform workspace list | grep -q "$ENVIRONMENT"; then
    echo "[INFO] 📁 Creating Terraform workspace: $ENVIRONMENT"
    terraform workspace new "$ENVIRONMENT"
else
    echo "[INFO] 📁 Selecting Terraform workspace: $ENVIRONMENT"
    terraform workspace select "$ENVIRONMENT"
fi

# Deploy OIDC infrastructure
echo "[INFO] 🚀 Deploying GitHub OIDC infrastructure..."
terraform apply \
    -var="environment=$ENVIRONMENT" \
    -var="lambda_function_name=lambda-function-$ENVIRONMENT" \
    -var="aws_region=$AWS_REGION" \
    -var="github_repository=$GITHUB_REPO" \
    -target="aws_iam_openid_connect_provider.github" \
    -target="aws_iam_role.github_actions_staging" \
    -target="aws_iam_role.github_actions_production" \
    -target="aws_iam_role_policy.github_actions_policy" \
    -auto-approve

# Get outputs
GITHUB_ROLE_ARN=$(terraform output -raw github_actions_role_arn 2>/dev/null || echo "")
OIDC_PROVIDER_ARN=$(terraform output -raw github_oidc_provider_arn 2>/dev/null || echo "")

if [[ -z "$GITHUB_ROLE_ARN" ]]; then
    echo "[ERROR] Failed to get GitHub Actions role ARN from Terraform output"
    exit 1
fi

echo ""
echo "✅ GitHub OIDC infrastructure deployed successfully!"
echo ""
echo "📋 OIDC Configuration:"
echo "  Provider ARN:      $OIDC_PROVIDER_ARN"
echo "  Role ARN:          $GITHUB_ROLE_ARN"
echo "  AWS Account ID:    $AWS_ACCOUNT_ID"
echo "  Environment:       $ENVIRONMENT"
echo "  Repository:        $GITHUB_REPO"
echo ""

# Set up GitHub secrets
echo "[INFO] 🔑 Setting up GitHub repository secrets..."

if [[ "$GITHUB_CLI_AVAILABLE" == "true" ]]; then
    # Check if we're authenticated with GitHub
    if gh auth status >/dev/null 2>&1; then
        echo "[INFO] Setting GitHub secrets using GitHub CLI..."
        
        # Set the AWS account ID secret based on environment
        if [[ "$ENVIRONMENT" == "production" ]]; then
            SECRET_NAME="AWS_ACCOUNT_ID_PROD"
        else
            SECRET_NAME="AWS_ACCOUNT_ID_STAGING"
        fi
        
        # Set the secret
        echo "$AWS_ACCOUNT_ID" | gh secret set "$SECRET_NAME" --repo "$GITHUB_REPO"
        echo "[INFO] ✅ Set secret: $SECRET_NAME"
        
        # Verify the secret was set
        if gh secret list --repo "$GITHUB_REPO" | grep -q "$SECRET_NAME"; then
            echo "[INFO] ✅ Secret $SECRET_NAME verified"
        else
            echo "[WARNING] ⚠️  Could not verify secret $SECRET_NAME"
        fi
        
    else
        echo "[WARNING] Not authenticated with GitHub CLI. Please run 'gh auth login' first."
        GITHUB_CLI_AVAILABLE=false
    fi
fi

if [[ "$GITHUB_CLI_AVAILABLE" == "false" ]]; then
    echo ""
    echo "🔧 Manual GitHub Secrets Setup Required:"
    echo ""
    echo "Please add the following secrets to your GitHub repository:"
    echo "Repository: https://github.com/$GITHUB_REPO/settings/secrets/actions"
    echo ""
    if [[ "$ENVIRONMENT" == "production" ]]; then
        echo "Secret Name: AWS_ACCOUNT_ID_PROD"
    else
        echo "Secret Name: AWS_ACCOUNT_ID_STAGING"
    fi
    echo "Secret Value: $AWS_ACCOUNT_ID"
    echo ""
fi

# Test the OIDC setup
echo "[INFO] 🧪 Testing OIDC configuration..."

# Create a test assume role policy document
cat > test-assume-role-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "$OIDC_PROVIDER_ARN"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:$GITHUB_REPO:ref:refs/heads/main"
        }
      }
    }
  ]
}
EOF

# Validate the policy
if aws iam validate-policy-document --policy-document file://test-assume-role-policy.json >/dev/null 2>&1; then
    echo "[INFO] ✅ OIDC trust policy is valid"
else
    echo "[WARNING] ⚠️  OIDC trust policy validation failed"
fi

# Clean up test file
rm -f test-assume-role-policy.json

cd - >/dev/null

echo ""
echo "🎉 GitHub OIDC setup completed!"
echo ""
echo "📋 Next Steps:"
echo "  1. Verify GitHub secrets are set correctly"
echo "  2. Test the workflow: git push to trigger GitHub Actions"
echo "  3. Monitor the workflow execution in GitHub Actions tab"
echo ""
echo "🔗 Useful Links:"
echo "  GitHub Repository: https://github.com/$GITHUB_REPO"
echo "  GitHub Secrets:    https://github.com/$GITHUB_REPO/settings/secrets/actions"
echo "  GitHub Actions:    https://github.com/$GITHUB_REPO/actions"
echo "  AWS IAM Role:      https://console.aws.amazon.com/iam/home#/roles/GitHubActions-Lambda-${ENVIRONMENT^}"
echo ""
echo "💡 Troubleshooting:"
echo "  If OIDC fails, check:"
echo "  - GitHub repository name is correct: $GITHUB_REPO"
echo "  - AWS Account ID secret is set: $AWS_ACCOUNT_ID"
echo "  - IAM role trust policy allows the repository"
echo "  - OIDC provider thumbprints are current"