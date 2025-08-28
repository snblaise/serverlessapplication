#!/bin/bash

# Cleanup Failed Stack Script
# This script cleans up a failed CloudFormation stack and prepares for fresh deployment

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

# Configuration
ENVIRONMENT="staging"
STACK_NAME="lambda-infrastructure-${ENVIRONMENT}"
AWS_REGION="us-east-1"

print_status "🧹 Cleaning up failed CloudFormation stack"
print_status "Stack Name: ${STACK_NAME}"
print_status "AWS Region: ${AWS_REGION}"
echo ""

# Check if stack exists
if aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$AWS_REGION" &> /dev/null; then
    STACK_STATUS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$AWS_REGION" --query 'Stacks[0].StackStatus' --output text)
    print_status "Current stack status: ${STACK_STATUS}"
    
    if [[ "$STACK_STATUS" == "ROLLBACK_COMPLETE" || "$STACK_STATUS" == "CREATE_FAILED" || "$STACK_STATUS" == "UPDATE_ROLLBACK_COMPLETE" ]]; then
        print_warning "Stack is in a failed state. Deleting..."
        
        aws cloudformation delete-stack --stack-name "$STACK_NAME" --region "$AWS_REGION"
        print_status "Waiting for stack deletion to complete..."
        aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME" --region "$AWS_REGION"
        
        print_success "Stack deleted successfully"
    else
        print_warning "Stack is in ${STACK_STATUS} state. Manual intervention may be required."
    fi
else
    print_status "No existing stack found"
fi

print_success "✅ Cleanup complete! Ready for fresh deployment."