#!/bin/bash

# Script to adopt existing AWS resources into Terraform state
# This prevents conflicts when resources already exist

set -e

ENVIRONMENT=${1:-staging}
AWS_REGION=${2:-us-east-1}

echo "🔄 Adopting existing AWS resources for environment: $ENVIRONMENT"

# Resource names
CODEDEPLOY_ROLE_NAME="CodeDeployServiceRole-${ENVIRONMENT}"
CODEDEPLOY_APP_NAME="lambda-app-${ENVIRONMENT}"
S3_BUCKET_NAME="lambda-artifacts-${ENVIRONMENT}-snblaise-serverless-2025"
LAMBDA_FUNCTION_NAME="lambda_function_${ENVIRONMENT}"
LAMBDA_ROLE_NAME="${LAMBDA_FUNCTION_NAME}-execution-role"
DLQ_NAME="${LAMBDA_FUNCTION_NAME}-dlq"

echo "Checking and importing existing resources:"
echo "  - CodeDeploy Role: $CODEDEPLOY_ROLE_NAME"
echo "  - CodeDeploy App: $CODEDEPLOY_APP_NAME"
echo "  - S3 Bucket: $S3_BUCKET_NAME"
echo "  - Lambda Role: $LAMBDA_ROLE_NAME"
echo "  - DLQ: $DLQ_NAME"
echo ""

cd infrastructure

# Function to safely import resources
safe_import() {
    local resource_address="$1"
    local resource_id="$2"
    local resource_name="$3"
    
    echo -n "Importing $resource_name... "
    if terraform import "$resource_address" "$resource_id" >/dev/null 2>&1; then
        echo "✅ IMPORTED"
    else
        echo "⚠️  ALREADY IN STATE OR NOT FOUND"
    fi
}

# Function to check if resource exists in AWS
resource_exists() {
    local check_command="$1"
    eval "$check_command" >/dev/null 2>&1
}

# Initialize Terraform
echo "🔧 Initializing Terraform..."
terraform init >/dev/null

# Select or create workspace
terraform workspace select "$ENVIRONMENT" >/dev/null 2>&1 || terraform workspace new "$ENVIRONMENT" >/dev/null

echo "📋 Checking resource existence and importing..."

# Check and import CodeDeploy service role
if resource_exists "aws iam get-role --role-name '$CODEDEPLOY_ROLE_NAME' --region '$AWS_REGION'"; then
    safe_import "aws_iam_role.codedeploy_service_role[0]" "$CODEDEPLOY_ROLE_NAME" "CodeDeploy Role"
fi

# Check and import S3 bucket
if resource_exists "aws s3api head-bucket --bucket '$S3_BUCKET_NAME' --region '$AWS_REGION'"; then
    safe_import "aws_s3_bucket.lambda_artifacts[0]" "$S3_BUCKET_NAME" "S3 Bucket"
fi

# Check and import CodeDeploy application
if resource_exists "aws deploy get-application --application-name '$CODEDEPLOY_APP_NAME' --region '$AWS_REGION'"; then
    safe_import "aws_codedeploy_app.lambda_app[0]" "$CODEDEPLOY_APP_NAME" "CodeDeploy App"
fi

# Check and import Lambda execution role
if resource_exists "aws iam get-role --role-name '$LAMBDA_ROLE_NAME' --region '$AWS_REGION'"; then
    safe_import "module.lambda_function.aws_iam_role.lambda_execution[0]" "$LAMBDA_ROLE_NAME" "Lambda Role"
fi

# Check and import DLQ
if resource_exists "aws sqs get-queue-url --queue-name '$DLQ_NAME' --region '$AWS_REGION'"; then
    DLQ_URL=$(aws sqs get-queue-url --queue-name "$DLQ_NAME" --region "$AWS_REGION" --query 'QueueUrl' --output text)
    safe_import "module.lambda_function.aws_sqs_queue.dlq[0]" "$DLQ_URL" "Dead Letter Queue"
fi

# Check and import CloudWatch alarms
ERROR_ALARM_NAME="lambda-error-rate-${ENVIRONMENT}"
DURATION_ALARM_NAME="lambda-duration-${ENVIRONMENT}"
THROTTLE_ALARM_NAME="lambda-throttle-${ENVIRONMENT}"

if resource_exists "aws cloudwatch describe-alarms --alarm-names '$ERROR_ALARM_NAME' --region '$AWS_REGION'"; then
    safe_import "aws_cloudwatch_metric_alarm.lambda_error_rate[0]" "$ERROR_ALARM_NAME" "Error Rate Alarm"
fi

if resource_exists "aws cloudwatch describe-alarms --alarm-names '$DURATION_ALARM_NAME' --region '$AWS_REGION'"; then
    safe_import "aws_cloudwatch_metric_alarm.lambda_duration[0]" "$DURATION_ALARM_NAME" "Duration Alarm"
fi

if resource_exists "aws cloudwatch describe-alarms --alarm-names '$THROTTLE_ALARM_NAME' --region '$AWS_REGION'"; then
    safe_import "aws_cloudwatch_metric_alarm.lambda_throttle[0]" "$THROTTLE_ALARM_NAME" "Throttle Alarm"
fi

echo ""
echo "✅ Resource adoption completed for environment: $ENVIRONMENT"
echo ""
echo "📋 Next steps:"
echo "  1. Run 'terraform plan' to verify the configuration"
echo "  2. Run 'terraform apply' to update any resource configurations"
echo ""
echo "💡 Tip: Resources with lifecycle.prevent_destroy are protected from accidental deletion"