#!/bin/bash

# AWS Resources Teardown Script
# This script safely removes all AWS resources created for the GitHub Actions deployment

set -e

# Configuration
ENVIRONMENT=${1:-staging}
REGION=${2:-us-east-1}
FUNCTION_NAME="lambda-function-${ENVIRONMENT}"
APP_NAME="lambda-app-${ENVIRONMENT}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check AWS CLI
check_aws_cli() {
    if ! command -v aws >/dev/null 2>&1; then
        log_error "AWS CLI not found. Please install it first."
        exit 1
    fi
    
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log_error "AWS credentials not configured. Please run 'aws configure'"
        exit 1
    fi
    
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    log_info "Using AWS account: $account_id"
}

# Delete CloudWatch alarms
delete_cloudwatch_alarms() {
    log_step "Deleting CloudWatch alarms..."
    
    local alarms=(
        "lambda-error-rate-${ENVIRONMENT}"
        "lambda-duration-${ENVIRONMENT}"
        "lambda-throttle-${ENVIRONMENT}"
    )
    
    for alarm in "${alarms[@]}"; do
        if aws cloudwatch describe-alarms --alarm-names "$alarm" --query 'MetricAlarms[0].AlarmName' --output text 2>/dev/null | grep -q "$alarm"; then
            aws cloudwatch delete-alarms --alarm-names "$alarm" >/dev/null 2>&1
            log_info "Deleted CloudWatch alarm: $alarm"
        else
            log_warn "CloudWatch alarm not found: $alarm"
        fi
    done
}

# Delete CodeDeploy resources
delete_codedeploy_resources() {
    log_step "Deleting CodeDeploy resources..."
    
    # Delete deployment group
    if aws deploy get-deployment-group \
        --application-name "$APP_NAME" \
        --deployment-group-name "lambda-deployment-group" >/dev/null 2>&1; then
        
        aws deploy delete-deployment-group \
            --application-name "$APP_NAME" \
            --deployment-group-name "lambda-deployment-group" >/dev/null 2>&1
        log_info "Deleted CodeDeploy deployment group"
    else
        log_warn "CodeDeploy deployment group not found"
    fi
    
    # Delete application
    if aws deploy get-application --application-name "$APP_NAME" >/dev/null 2>&1; then
        aws deploy delete-application --application-name "$APP_NAME" >/dev/null 2>&1
        log_info "Deleted CodeDeploy application: $APP_NAME"
    else
        log_warn "CodeDeploy application not found: $APP_NAME"
    fi
}

# Delete Lambda function
delete_lambda_function() {
    log_step "Deleting Lambda function..."
    
    if aws lambda get-function --function-name "$FUNCTION_NAME" >/dev/null 2>&1; then
        # Delete alias first
        if aws lambda get-alias --function-name "$FUNCTION_NAME" --name "live" >/dev/null 2>&1; then
            aws lambda delete-alias --function-name "$FUNCTION_NAME" --name "live" >/dev/null 2>&1
            log_info "Deleted Lambda alias: live"
        fi
        
        # Delete function
        aws lambda delete-function --function-name "$FUNCTION_NAME" >/dev/null 2>&1
        log_info "Deleted Lambda function: $FUNCTION_NAME"
    else
        log_warn "Lambda function not found: $FUNCTION_NAME"
    fi
}

# Delete S3 bucket
delete_s3_bucket() {
    log_step "Deleting S3 buckets..."
    
    # Find buckets with the pattern
    local buckets=$(aws s3api list-buckets --query "Buckets[?starts_with(Name, 'lambda-artifacts-${ENVIRONMENT}')].Name" --output text)
    
    if [ -n "$buckets" ]; then
        for bucket in $buckets; do
            log_info "Deleting S3 bucket: $bucket"
            
            # Delete all objects and versions
            aws s3api list-object-versions --bucket "$bucket" --query 'Versions[].{Key:Key,VersionId:VersionId}' --output text | while read key version; do
                if [ -n "$key" ] && [ -n "$version" ]; then
                    aws s3api delete-object --bucket "$bucket" --key "$key" --version-id "$version" >/dev/null 2>&1
                fi
            done
            
            # Delete delete markers
            aws s3api list-object-versions --bucket "$bucket" --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' --output text | while read key version; do
                if [ -n "$key" ] && [ -n "$version" ]; then
                    aws s3api delete-object --bucket "$bucket" --key "$key" --version-id "$version" >/dev/null 2>&1
                fi
            done
            
            # Delete bucket
            aws s3api delete-bucket --bucket "$bucket" >/dev/null 2>&1
            log_info "Deleted S3 bucket: $bucket"
        done
    else
        log_warn "No S3 buckets found matching pattern: lambda-artifacts-${ENVIRONMENT}"
    fi
}

# Delete IAM roles
delete_iam_roles() {
    log_step "Deleting IAM roles..."
    
    local roles=(
        "${FUNCTION_NAME}-execution-role"
        "CodeDeployServiceRole-${ENVIRONMENT}"
    )
    
    for role in "${roles[@]}"; do
        if aws iam get-role --role-name "$role" >/dev/null 2>&1; then
            # Detach managed policies
            local policies=$(aws iam list-attached-role-policies --role-name "$role" --query 'AttachedPolicies[].PolicyArn' --output text)
            for policy in $policies; do
                if [ -n "$policy" ]; then
                    aws iam detach-role-policy --role-name "$role" --policy-arn "$policy" >/dev/null 2>&1
                    log_info "Detached policy $policy from role $role"
                fi
            done
            
            # Delete inline policies
            local inline_policies=$(aws iam list-role-policies --role-name "$role" --query 'PolicyNames' --output text)
            for policy in $inline_policies; do
                if [ -n "$policy" ]; then
                    aws iam delete-role-policy --role-name "$role" --policy-name "$policy" >/dev/null 2>&1
                    log_info "Deleted inline policy $policy from role $role"
                fi
            done
            
            # Delete role
            aws iam delete-role --role-name "$role" >/dev/null 2>&1
            log_info "Deleted IAM role: $role"
        else
            log_warn "IAM role not found: $role"
        fi
    done
}

# Delete SQS queues (from Lambda module)
delete_sqs_queues() {
    log_step "Deleting SQS queues..."
    
    local queue_name="${FUNCTION_NAME}-dlq"
    local queue_url=$(aws sqs get-queue-url --queue-name "$queue_name" --query 'QueueUrl' --output text 2>/dev/null || echo "")
    
    if [ -n "$queue_url" ] && [ "$queue_url" != "None" ]; then
        aws sqs delete-queue --queue-url "$queue_url" >/dev/null 2>&1
        log_info "Deleted SQS queue: $queue_name"
    else
        log_warn "SQS queue not found: $queue_name"
    fi
}

# Clean up local files
cleanup_local_files() {
    log_step "Cleaning up local files..."
    
    local files_to_remove=(
        "lambda-function.zip"
        "lambda-function-signed.zip"
        "package-manifest.json"
        "lambda-function.zip.sha256"
        "signing-report.json"
        "deployment-report.json"
        "validation-report.json"
        "rollback-report.json"
    )
    
    for file in "${files_to_remove[@]}"; do
        if [ -f "$file" ]; then
            rm -f "$file"
            log_info "Removed local file: $file"
        fi
    done
    
    # Clean up test results
    if [ -d "test-results/github-actions-terraform" ]; then
        rm -rf "test-results/github-actions-terraform"
        log_info "Removed test results directory"
    fi
}

# Main execution
main() {
    echo ""
    log_info "🗑️  Tearing down AWS resources for GitHub Actions deployment"
    log_info "Environment: $ENVIRONMENT"
    log_info "Region: $REGION"
    echo ""
    
    # Confirmation prompt
    read -p "Are you sure you want to delete all AWS resources for environment '$ENVIRONMENT'? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Teardown cancelled."
        exit 0
    fi
    
    check_aws_cli
    
    echo ""
    log_info "🗑️  Starting resource deletion..."
    echo ""
    
    # Delete resources in reverse order of creation
    delete_cloudwatch_alarms
    delete_codedeploy_resources
    delete_lambda_function
    delete_sqs_queues
    delete_s3_bucket
    
    # Wait a bit for resources to be fully deleted
    log_info "Waiting for resources to be fully deleted..."
    sleep 5
    
    delete_iam_roles
    cleanup_local_files
    
    echo ""
    log_info "✅ AWS resources teardown completed!"
    echo ""
    log_info "📋 Summary of deleted resources:"
    echo "   - Lambda function: $FUNCTION_NAME"
    echo "   - CodeDeploy application: $APP_NAME"
    echo "   - S3 buckets: lambda-artifacts-${ENVIRONMENT}-*"
    echo "   - IAM roles: Lambda execution and CodeDeploy service roles"
    echo "   - CloudWatch alarms: Error rate, duration, and throttle alarms"
    echo "   - SQS queue: ${FUNCTION_NAME}-dlq"
    echo "   - Local build artifacts"
    echo ""
    log_info "🧹 Environment '$ENVIRONMENT' has been cleaned up!"
    echo ""
}

# Show usage
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo "Usage: $0 [environment] [region]"
    echo ""
    echo "Arguments:"
    echo "  environment  Environment name (default: staging)"
    echo "  region       AWS region (default: us-east-1)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Delete staging resources in us-east-1"
    echo "  $0 production         # Delete production resources in us-east-1"
    echo "  $0 staging us-west-2  # Delete staging resources in us-west-2"
    echo ""
    echo "This script will delete:"
    echo "  - Lambda function and alias"
    echo "  - CodeDeploy application and deployment group"
    echo "  - S3 buckets for deployment artifacts"
    echo "  - IAM roles (Lambda execution and CodeDeploy service)"
    echo "  - CloudWatch alarms"
    echo "  - SQS dead letter queue"
    echo "  - Local build artifacts"
    exit 0
fi

# Run main function
main "$@"