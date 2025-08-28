#!/bin/bash

# Update Staging Role Script
# This script updates the GitHubActions-Lambda-Staging role with permissions to manage the SecurityScan role

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

ROLE_NAME="GitHubActions-Lambda-Staging"
POLICY_NAME="GitHubActions-Lambda-staging-Policy"
ACCOUNT_ID="948572562675"

print_status "🔧 Updating Staging Role permissions"
print_status "Role: ${ROLE_NAME}"
print_status "Policy: ${POLICY_NAME}"
echo ""

# Check if role exists
if ! aws iam get-role --role-name "$ROLE_NAME" &> /dev/null; then
    print_error "Role $ROLE_NAME does not exist"
    exit 1
fi

# Create updated policy document
cat > /tmp/staging-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "lambda:*",
            "Resource": [
                "arn:aws:lambda:us-east-1:${ACCOUNT_ID}:function:*staging*",
                "arn:aws:lambda:us-east-1:${ACCOUNT_ID}:function:lambda-function-staging*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::*staging*",
                "arn:aws:s3:::*staging*/*",
                "arn:aws:s3:::lambda-artifacts-staging*",
                "arn:aws:s3:::lambda-artifacts-staging*/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": "iam:*",
            "Resource": [
                "arn:aws:iam::${ACCOUNT_ID}:role/*staging*",
                "arn:aws:iam::${ACCOUNT_ID}:role/lambda-function*staging*",
                "arn:aws:iam::${ACCOUNT_ID}:role/CodeDeploy*staging*",
                "arn:aws:iam::${ACCOUNT_ID}:role/GitHubActions-SecurityScan"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "iam:GetRole",
                "iam:GetRolePolicy",
                "iam:ListRolePolicies",
                "iam:ListAttachedRolePolicies",
                "iam:GetOpenIDConnectProvider",
                "iam:ListOpenIDConnectProviders"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "codedeploy:*",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "cloudformation:*",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "cloudwatch:*",
                "logs:*"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "sqs:*",
            "Resource": "arn:aws:sqs:us-east-1:${ACCOUNT_ID}:*staging*"
        }
    ]
}
EOF

# Update the role policy
print_status "Updating role policy..."
aws iam put-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-name "$POLICY_NAME" \
    --policy-document file:///tmp/staging-policy.json

print_success "✅ Staging role updated successfully!"
print_status "Added permissions for:"
echo "  • GitHubActions-SecurityScan role management"

# Clean up
rm -f /tmp/staging-policy.json

print_success "🎉 Role update complete! CloudFormation deployments should now work."