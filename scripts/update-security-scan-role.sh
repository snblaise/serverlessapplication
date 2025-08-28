#!/bin/bash

# Update Security Scan Role Script
# This script updates the GitHubActions-SecurityScan role with CloudFormation permissions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

ROLE_NAME="GitHubActions-SecurityScan"
POLICY_NAME="GitHubActions-SecurityScan-Policy"

print_status "🔧 Updating Security Scan Role permissions"
print_status "Role: ${ROLE_NAME}"
print_status "Policy: ${POLICY_NAME}"
echo ""

# Check if role exists
if ! aws iam get-role --role-name "$ROLE_NAME" &> /dev/null; then
    print_error "Role $ROLE_NAME does not exist"
    exit 1
fi

# Create updated policy document
cat > /tmp/security-scan-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "securityhub:BatchImportFindings",
                "securityhub:DescribeHub",
                "securityhub:GetFindings",
                "securityhub:EnableSecurityHub",
                "securityhub:GetEnabledStandards",
                "securityhub:BatchUpdateFindings"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "cloudformation:ValidateTemplate",
                "cloudformation:DescribeStacks",
                "cloudformation:ListStacks"
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
            "Resource": "arn:aws:logs:us-east-1:948572562675:log-group:/aws/github-actions/security-scan*"
        }
    ]
}
EOF

# Update the role policy
print_status "Updating role policy..."
aws iam put-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-name "$POLICY_NAME" \
    --policy-document file:///tmp/security-scan-policy.json

print_success "✅ Security scan role updated successfully!"
print_status "Added permissions:"
echo "  • cloudformation:ValidateTemplate"
echo "  • cloudformation:DescribeStacks"
echo "  • cloudformation:ListStacks"

# Clean up
rm -f /tmp/security-scan-policy.json

print_success "🎉 Role update complete! Security scanning should now work."