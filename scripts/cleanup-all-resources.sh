#!/bin/bash

# Cleanup All Resources Script
# This script removes all existing resources to allow for a clean deployment

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

print_status "🧹 Cleaning up all existing resources"
echo ""

# Delete existing IAM roles
ROLES=("GitHubActions-Lambda-Staging" "GitHubActions-Lambda-Production" "GitHubActions-SecurityScan")

for ROLE in "${ROLES[@]}"; do
    if aws iam get-role --role-name "$ROLE" &> /dev/null; then
        print_status "Deleting IAM role: $ROLE"
        
        # Detach managed policies
        ATTACHED_POLICIES=$(aws iam list-attached-role-policies --role-name "$ROLE" --query 'AttachedPolicies[].PolicyArn' --output text)
        for POLICY_ARN in $ATTACHED_POLICIES; do
            if [[ -n "$POLICY_ARN" ]]; then
                print_status "  Detaching managed policy: $POLICY_ARN"
                aws iam detach-role-policy --role-name "$ROLE" --policy-arn "$POLICY_ARN"
            fi
        done
        
        # Delete inline policies
        INLINE_POLICIES=$(aws iam list-role-policies --role-name "$ROLE" --query 'PolicyNames' --output text)
        for POLICY_NAME in $INLINE_POLICIES; do
            if [[ -n "$POLICY_NAME" ]]; then
                print_status "  Deleting inline policy: $POLICY_NAME"
                aws iam delete-role-policy --role-name "$ROLE" --policy-name "$POLICY_NAME"
            fi
        done
        
        # Delete the role
        aws iam delete-role --role-name "$ROLE"
        print_success "  Role $ROLE deleted"
    else
        print_status "Role $ROLE does not exist"
    fi
done

# Clean up SQS queues
SQS_QUEUES=("lambda-function-staging-dlq" "lambda-function-production-dlq")
for QUEUE in "${SQS_QUEUES[@]}"; do
    QUEUE_URL=$(aws sqs get-queue-url --queue-name "$QUEUE" --query 'QueueUrl' --output text 2>/dev/null || echo "")
    if [[ -n "$QUEUE_URL" ]]; then
        print_status "Deleting SQS queue: $QUEUE"
        aws sqs delete-queue --queue-url "$QUEUE_URL"
        print_success "  SQS queue $QUEUE deleted"
    else
        print_status "SQS queue $QUEUE does not exist"
    fi
done

# Clean up Lambda functions
LAMBDA_FUNCTIONS=("lambda-function-staging" "lambda-function-production")
for FUNCTION in "${LAMBDA_FUNCTIONS[@]}"; do
    if aws lambda get-function --function-name "$FUNCTION" &> /dev/null; then
        print_status "Deleting Lambda function: $FUNCTION"
        aws lambda delete-function --function-name "$FUNCTION"
        print_success "  Lambda function $FUNCTION deleted"
    else
        print_status "Lambda function $FUNCTION does not exist"
    fi
done

# Clean up S3 buckets (empty them first)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
S3_BUCKETS=("lambda-artifacts-staging-${ACCOUNT_ID}" "lambda-artifacts-production-${ACCOUNT_ID}")
for BUCKET in "${S3_BUCKETS[@]}"; do
    if aws s3api head-bucket --bucket "$BUCKET" &> /dev/null; then
        print_status "Emptying and deleting S3 bucket: $BUCKET"
        aws s3 rm s3://"$BUCKET" --recursive
        aws s3api delete-bucket --bucket "$BUCKET"
        print_success "  S3 bucket $BUCKET deleted"
    else
        print_status "S3 bucket $BUCKET does not exist"
    fi
done

# Clean up CodeDeploy applications
CODEDEPLOY_APPS=("lambda-app-staging" "lambda-app-production")
for APP in "${CODEDEPLOY_APPS[@]}"; do
    if aws deploy get-application --application-name "$APP" &> /dev/null; then
        print_status "Deleting CodeDeploy application: $APP"
        aws deploy delete-application --application-name "$APP"
        print_success "  CodeDeploy application $APP deleted"
    else
        print_status "CodeDeploy application $APP does not exist"
    fi
done

# Clean up CloudWatch alarms
ALARMS=("lambda-error-rate-staging" "lambda-duration-staging" "lambda-throttle-staging" 
        "lambda-error-rate-production" "lambda-duration-production" "lambda-throttle-production")
for ALARM in "${ALARMS[@]}"; do
    if aws cloudwatch describe-alarms --alarm-names "$ALARM" --query 'MetricAlarms[0].AlarmName' --output text 2>/dev/null | grep -q "$ALARM"; then
        print_status "Deleting CloudWatch alarm: $ALARM"
        aws cloudwatch delete-alarms --alarm-names "$ALARM"
        print_success "  CloudWatch alarm $ALARM deleted"
    else
        print_status "CloudWatch alarm $ALARM does not exist"
    fi
done

# Clean up any failed stacks
ENVIRONMENTS=("staging" "production")
for ENV in "${ENVIRONMENTS[@]}"; do
    STACK_NAME="lambda-infrastructure-${ENV}"
    if aws cloudformation describe-stacks --stack-name "$STACK_NAME" &> /dev/null; then
        STACK_STATUS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query 'Stacks[0].StackStatus' --output text)
        print_status "Found stack $STACK_NAME with status: $STACK_STATUS"
        
        if [[ "$STACK_STATUS" != "DELETE_COMPLETE" ]]; then
            print_status "Deleting stack: $STACK_NAME"
            aws cloudformation delete-stack --stack-name "$STACK_NAME"
            print_status "Waiting for stack deletion..."
            aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME"
            print_success "Stack $STACK_NAME deleted"
        fi
    fi
done

print_success "✅ All resources cleaned up! Ready for fresh deployment."
echo ""
print_status "Next steps:"
echo "1. Run: ./scripts/bootstrap-infrastructure.sh"
echo "2. Add GitHub secrets:"
echo "   - AWS_ACCOUNT_ID: 948572562675"
echo "   - SNYK_TOKEN: [optional]"