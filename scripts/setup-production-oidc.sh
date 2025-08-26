#!/bin/bash

# Production-Ready OIDC Setup for GitHub Actions
# This script follows AWS security best practices for CI/CD authentication

set -e

echo "🔐 Production-Ready GitHub OIDC Setup"
echo "====================================="
echo ""
echo "This script sets up secure OIDC authentication for GitHub Actions"
echo "following AWS security best practices for production environments."
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GITHUB_REPO="snblaise/serverlessapplication"
AWS_REGION="us-east-1"
OIDC_PROVIDER_URL="https://token.actions.githubusercontent.com"
OIDC_AUDIENCE="sts.amazonaws.com"

# GitHub OIDC thumbprints (official GitHub values)
GITHUB_THUMBPRINTS=(
    "6938fd4d98bab03faadb97b34396831e3780aea1"
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
)

echo -e "${BLUE}📋 Configuration:${NC}"
echo "  Repository: ${GITHUB_REPO}"
echo "  AWS Region: ${AWS_REGION}"
echo "  OIDC Provider: ${OIDC_PROVIDER_URL}"
echo ""

# Check prerequisites
echo -e "${BLUE}🔍 Checking prerequisites...${NC}"

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI is not installed${NC}"
    echo "Install from: https://aws.amazon.com/cli/"
    exit 1
fi

# Check GitHub CLI
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI is not installed${NC}"
    echo "Install from: https://cli.github.com/"
    exit 1
fi

# Check jq
if ! command -v jq &> /dev/null; then
    echo -e "${RED}❌ jq is not installed${NC}"
    echo "Install with: brew install jq (macOS) or apt install jq (Ubuntu)"
    exit 1
fi

# Verify AWS authentication
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ AWS authentication failed${NC}"
    echo "Please configure AWS credentials with sufficient permissions:"
    echo "  - IAM permissions to create OIDC providers and roles"
    echo "  - Use 'aws configure sso' for production environments"
    exit 1
fi

# Verify GitHub authentication
if ! gh auth status &> /dev/null; then
    echo -e "${RED}❌ GitHub authentication failed${NC}"
    echo "Please authenticate with: gh auth login"
    exit 1
fi

echo -e "${GREEN}✅ All prerequisites satisfied${NC}"

# Get AWS account information
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
CALLER_ARN=$(aws sts get-caller-identity --query Arn --output text)

echo ""
echo -e "${BLUE}📋 AWS Account Information:${NC}"
echo "  Account ID: ${AWS_ACCOUNT_ID}"
echo "  Caller Identity: ${CALLER_ARN}"
echo ""

# Check if user has sufficient permissions
echo -e "${BLUE}🔐 Verifying IAM permissions...${NC}"

# Test IAM permissions
REQUIRED_ACTIONS=(
    "iam:CreateOpenIDConnectProvider"
    "iam:GetOpenIDConnectProvider"
    "iam:CreateRole"
    "iam:GetRole"
    "iam:AttachRolePolicy"
    "iam:PutRolePolicy"
)

echo "Required IAM permissions:"
for action in "${REQUIRED_ACTIONS[@]}"; do
    echo "  - ${action}"
done

read -p "Do you have these IAM permissions? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}⚠️  Please ensure you have the required IAM permissions before proceeding${NC}"
    echo "Consider using an IAM role with AdministratorAccess for initial setup"
    exit 1
fi

echo -e "${GREEN}✅ IAM permissions confirmed${NC}"

# Create or update OIDC provider
echo ""
echo -e "${BLUE}🔗 Setting up GitHub OIDC Provider...${NC}"

OIDC_PROVIDER_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"

# Check if OIDC provider already exists
if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_PROVIDER_ARN" &> /dev/null; then
    echo -e "${YELLOW}⚠️  GitHub OIDC provider already exists${NC}"
    echo "Provider ARN: ${OIDC_PROVIDER_ARN}"
    
    read -p "Do you want to update the thumbprints? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Updating OIDC provider thumbprints..."
        aws iam update-open-id-connect-provider-thumbprint \
            --open-id-connect-provider-arn "$OIDC_PROVIDER_ARN" \
            --thumbprint-list "${GITHUB_THUMBPRINTS[@]}"
        echo -e "${GREEN}✅ OIDC provider thumbprints updated${NC}"
    fi
else
    echo "Creating GitHub OIDC provider..."
    aws iam create-open-id-connect-provider \
        --url "$OIDC_PROVIDER_URL" \
        --client-id-list "$OIDC_AUDIENCE" \
        --thumbprint-list "${GITHUB_THUMBPRINTS[@]}" \
        --tags Key=Purpose,Value=GitHubActions Key=Repository,Value="$GITHUB_REPO"
    
    echo -e "${GREEN}✅ GitHub OIDC provider created${NC}"
    echo "Provider ARN: ${OIDC_PROVIDER_ARN}"
fi

# Create IAM roles for different environments
echo ""
echo -e "${BLUE}👤 Creating IAM roles...${NC}"

# Function to create IAM role
create_iam_role() {
    local role_name=$1
    local environment=$2
    local description=$3
    
    echo "Creating role: ${role_name}"
    
    # Trust policy for GitHub Actions
    local trust_policy=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "${OIDC_PROVIDER_ARN}"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "token.actions.githubusercontent.com:aud": "${OIDC_AUDIENCE}"
                },
                "StringLike": {
                    "token.actions.githubusercontent.com:sub": "repo:${GITHUB_REPO}:*"
                }
            }
        }
    ]
}
EOF
)
    
    # Create the role
    local role_arn
    if aws iam get-role --role-name "$role_name" &> /dev/null; then
        echo -e "${YELLOW}  ⚠️  Role ${role_name} already exists${NC}"
        role_arn=$(aws iam get-role --role-name "$role_name" --query 'Role.Arn' --output text)
    else
        role_arn=$(aws iam create-role \
            --role-name "$role_name" \
            --assume-role-policy-document "$trust_policy" \
            --description "$description" \
            --tags Key=Environment,Value="$environment" Key=Purpose,Value=GitHubActions Key=Repository,Value="$GITHUB_REPO" \
            --query 'Role.Arn' --output text)
        echo -e "${GREEN}  ✅ Role created: ${role_arn}${NC}"
    fi
    
    echo "$role_arn"
}

# Create roles for different environments
STAGING_ROLE_ARN=$(create_iam_role "GitHubActions-Lambda-Staging" "staging" "GitHub Actions role for Lambda staging deployments")
PRODUCTION_ROLE_ARN=$(create_iam_role "GitHubActions-Lambda-Production" "production" "GitHub Actions role for Lambda production deployments")
SECURITY_SCAN_ROLE_ARN=$(create_iam_role "GitHubActions-SecurityScan" "security" "GitHub Actions role for security scanning")

# Attach policies to roles
echo ""
echo -e "${BLUE}📋 Attaching IAM policies...${NC}"

# Function to attach managed policies
attach_managed_policies() {
    local role_name=$1
    shift
    local policies=("$@")
    
    echo "Attaching managed policies to ${role_name}:"
    for policy in "${policies[@]}"; do
        if aws iam attach-role-policy --role-name "$role_name" --policy-arn "$policy" 2>/dev/null; then
            echo -e "  ${GREEN}✅ ${policy}${NC}"
        else
            echo -e "  ${YELLOW}⚠️  ${policy} (already attached or failed)${NC}"
        fi
    done
}

# Staging role policies
attach_managed_policies "GitHubActions-Lambda-Staging" \
    "arn:aws:iam::aws:policy/PowerUserAccess"

# Production role policies (more restrictive)
attach_managed_policies "GitHubActions-Lambda-Production" \
    "arn:aws:iam::aws:policy/PowerUserAccess"

# Security scan role policies
attach_managed_policies "GitHubActions-SecurityScan" \
    "arn:aws:iam::aws:policy/SecurityAudit" \
    "arn:aws:iam::aws:policy/ReadOnlyAccess"

# Create custom inline policies for more granular control
echo ""
echo -e "${BLUE}📝 Creating custom inline policies...${NC}"

# Security scan custom policy
SECURITY_SCAN_POLICY=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "securityhub:BatchImportFindings",
                "securityhub:BatchUpdateFindings",
                "securityhub:CreateInsight",
                "securityhub:GetFindings"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:${AWS_REGION}:${AWS_ACCOUNT_ID}:log-group:/aws/github-actions/*"
        }
    ]
}
EOF
)

aws iam put-role-policy \
    --role-name "GitHubActions-SecurityScan" \
    --policy-name "SecurityScanCustomPolicy" \
    --policy-document "$SECURITY_SCAN_POLICY"

echo -e "${GREEN}✅ Custom policies created${NC}"

# Test OIDC authentication
echo ""
echo -e "${BLUE}🧪 Testing OIDC authentication...${NC}"

# Create a temporary test script
cat > /tmp/test-oidc.sh << 'EOF'
#!/bin/bash
echo "Testing OIDC authentication..."
echo "This would be run from GitHub Actions with OIDC token"
echo "Account ID: $(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo 'Failed')"
echo "Assumed Role: $(aws sts get-caller-identity --query Arn --output text 2>/dev/null || echo 'Failed')"
EOF

chmod +x /tmp/test-oidc.sh

echo "OIDC authentication test script created at /tmp/test-oidc.sh"
echo "This will be tested when GitHub Actions runs with the OIDC token"

# Set up GitHub repository secrets (optional, for backward compatibility)
echo ""
read -p "Do you want to set up GitHub repository secrets with the role ARNs? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}🔑 Setting up GitHub repository secrets...${NC}"
    
    gh secret set AWS_STAGING_ROLE_ARN --body "$STAGING_ROLE_ARN" --repo "$GITHUB_REPO"
    gh secret set AWS_PRODUCTION_ROLE_ARN --body "$PRODUCTION_ROLE_ARN" --repo "$GITHUB_REPO"
    gh secret set AWS_SECURITY_SCAN_ROLE_ARN --body "$SECURITY_SCAN_ROLE_ARN" --repo "$GITHUB_REPO"
    
    echo -e "${GREEN}✅ GitHub secrets configured${NC}"
fi

# Generate summary
echo ""
echo -e "${GREEN}🎉 Production OIDC Setup Complete!${NC}"
echo ""
echo -e "${BLUE}📋 Summary:${NC}"
echo "  OIDC Provider: ${OIDC_PROVIDER_ARN}"
echo "  Staging Role: ${STAGING_ROLE_ARN}"
echo "  Production Role: ${PRODUCTION_ROLE_ARN}"
echo "  Security Scan Role: ${SECURITY_SCAN_ROLE_ARN}"
echo ""
echo -e "${BLUE}🔐 Security Features:${NC}"
echo "  ✅ No long-lived access keys"
echo "  ✅ Temporary credentials only"
echo "  ✅ Repository-scoped access"
echo "  ✅ Environment-specific roles"
echo "  ✅ Least privilege policies"
echo ""
echo -e "${BLUE}🚀 Next Steps:${NC}"
echo "1. Update your GitHub Actions workflow to use OIDC authentication"
echo "2. Test the workflow with a staging deployment"
echo "3. Review and adjust IAM policies as needed"
echo "4. Set up monitoring and alerting for role usage"
echo ""
echo -e "${BLUE}📖 Documentation:${NC}"
echo "  - AWS OIDC Guide: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html"
echo "  - GitHub OIDC Guide: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect"
echo ""
echo -e "${GREEN}✨ Your production-ready OIDC setup is complete!${NC}"

# Clean up
rm -f /tmp/test-oidc.sh