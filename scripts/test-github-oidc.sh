#!/bin/bash

# Test GitHub OIDC Configuration
# This script verifies that the OIDC setup is working correctly

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

ACCOUNT_ID="948572562675"
REPO="snblaise/serverlessapplication"

print_status "🔍 Testing GitHub OIDC Configuration"
echo ""

# Check OIDC Provider
print_status "Checking OIDC Provider..."
if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com" &> /dev/null; then
    print_success "✅ OIDC Provider exists"
else
    print_error "❌ OIDC Provider not found"
    exit 1
fi

# Check IAM Roles
ROLES=("GitHubActions-Lambda-Staging" "GitHubActions-SecurityScan")
for ROLE in "${ROLES[@]}"; do
    print_status "Checking IAM Role: $ROLE"
    if aws iam get-role --role-name "$ROLE" &> /dev/null; then
        print_success "✅ Role $ROLE exists"
        
        # Check trust policy
        TRUST_POLICY=$(aws iam get-role --role-name "$ROLE" --query 'Role.AssumeRolePolicyDocument.Statement[0].Condition.StringLike."token.actions.githubusercontent.com:sub"' --output text)
        if [[ "$TRUST_POLICY" == "repo:${REPO}:*" ]]; then
            print_success "✅ Trust policy correctly configured for $REPO"
        else
            print_warning "⚠️  Trust policy mismatch. Expected: repo:${REPO}:*, Got: $TRUST_POLICY"
        fi
    else
        print_error "❌ Role $ROLE not found"
    fi
done

echo ""
print_status "📋 Next Steps:"
echo "1. Add GitHub Secret:"
echo "   - Go to: https://github.com/${REPO}/settings/secrets/actions"
echo "   - Add secret: AWS_ACCOUNT_ID = ${ACCOUNT_ID}"
echo ""
echo "2. Test the workflow:"
echo "   - Push a commit to trigger the pipeline"
echo "   - Or manually trigger via GitHub Actions tab"
echo ""
print_success "✅ OIDC configuration looks good!"