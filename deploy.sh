#!/bin/bash

# Simple deployment script for Lambda infrastructure
set -e

ENVIRONMENT=${1:-staging}
STACK_NAME="lambda-infrastructure-${ENVIRONMENT}"
AWS_REGION="us-east-1"

echo "🚀 Deploying Lambda Infrastructure"
echo "Environment: ${ENVIRONMENT}"
echo "Stack Name: ${STACK_NAME}"
echo "AWS Region: ${AWS_REGION}"

# Check AWS CLI configuration
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS CLI is not configured. Please run 'aws configure' first."
    exit 1
fi

# Validate template
echo "🔍 Validating CloudFormation template..."
aws cloudformation validate-template --template-body file://cloudformation/lambda-infrastructure.yml > /dev/null
echo "✅ Template validation passed"

# Check if stack exists
if aws cloudformation describe-stacks --stack-name "$STACK_NAME" &> /dev/null; then
    echo "📝 Updating existing stack..."
    ACTION="update-stack"
    WAIT_CONDITION="stack-update-complete"
else
    echo "🆕 Creating new stack (includes OIDC provider setup)..."
    ACTION="create-stack"
    WAIT_CONDITION="stack-create-complete"
fi

# Deploy stack
aws cloudformation $ACTION \
    --stack-name "$STACK_NAME" \
    --template-body file://cloudformation/lambda-infrastructure.yml \
    --parameters file://cloudformation/parameters/${ENVIRONMENT}.json \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "$AWS_REGION"

echo "⏳ Waiting for deployment to complete..."
aws cloudformation wait $WAIT_CONDITION --stack-name "$STACK_NAME" --region "$AWS_REGION"

echo "✅ Deployment completed successfully!"
echo "🔗 Check your Lambda function in the AWS Console"