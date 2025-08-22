#!/bin/bash

# Deploy complete CI/CD pipeline infrastructure
# Usage: ./scripts/deploy-pipeline-infrastructure.sh [environment] [email]

set -euo pipefail

# Configuration
ENVIRONMENT="${1:-staging}"
NOTIFICATION_EMAIL="${2:-}"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo "[INFO] 🏗️  Deploying CI/CD pipeline infrastructure..."
echo "[INFO] Environment: $ENVIRONMENT"
echo "[INFO] Region: $AWS_REGION"
if [[ -n "$NOTIFICATION_EMAIL" ]]; then
    echo "[INFO] Notifications: $NOTIFICATION_EMAIL"
fi

# Check prerequisites
if ! command -v terraform &> /dev/null; then
    echo "[ERROR] Terraform is not installed"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo "[ERROR] AWS CLI is not installed"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "[ERROR] AWS credentials not configured"
    exit 1
fi

# Navigate to infrastructure directory
cd infrastructure

# Initialize Terraform
echo "[INFO] 🔧 Initializing Terraform..."
terraform init

# Create workspace if it doesn't exist
if ! terraform workspace list | grep -q "$ENVIRONMENT"; then
    echo "[INFO] 📁 Creating Terraform workspace: $ENVIRONMENT"
    terraform workspace new "$ENVIRONMENT"
else
    echo "[INFO] 📁 Selecting Terraform workspace: $ENVIRONMENT"
    terraform workspace select "$ENVIRONMENT"
fi

# Plan the deployment
echo "[INFO] 📋 Planning infrastructure deployment..."
PLAN_FILE="tfplan-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S)"

terraform plan \
    -var="environment=$ENVIRONMENT" \
    -var="lambda_function_name=lambda-function-$ENVIRONMENT" \
    -var="aws_region=$AWS_REGION" \
    -var="enable_pipeline=true" \
    -var="enable_manual_approval=$([ "$ENVIRONMENT" = "production" ] && echo "true" || echo "false")" \
    $([ -n "$NOTIFICATION_EMAIL" ] && echo "-var=notification_email=$NOTIFICATION_EMAIL" || echo "") \
    -out="$PLAN_FILE"

# Ask for confirmation
echo ""
echo "[INFO] 🤔 Review the plan above. Do you want to proceed with the deployment?"
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "[INFO] ❌ Deployment cancelled"
    rm -f "$PLAN_FILE"
    exit 0
fi

# Apply the plan
echo "[INFO] 🚀 Applying infrastructure changes..."
terraform apply "$PLAN_FILE"

# Clean up plan file
rm -f "$PLAN_FILE"

# Get outputs
echo "[INFO] 📊 Deployment completed! Getting outputs..."
echo ""

# Pipeline information
PIPELINE_NAME=$(terraform output -raw pipeline_name 2>/dev/null || echo "N/A")
PIPELINE_URL=$(terraform output -raw pipeline_url 2>/dev/null || echo "N/A")
CODEBUILD_PROJECT=$(terraform output -raw codebuild_project_name 2>/dev/null || echo "N/A")
S3_BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "N/A")

echo "🎉 CI/CD Pipeline Infrastructure Deployed Successfully!"
echo ""
echo "📋 Pipeline Details:"
echo "  Pipeline Name:     $PIPELINE_NAME"
echo "  CodeBuild Project: $CODEBUILD_PROJECT"
echo "  Artifacts Bucket:  $S3_BUCKET"
echo "  Environment:       $ENVIRONMENT"
echo "  Region:            $AWS_REGION"
echo ""
echo "🔗 Console URLs:"
echo "  Pipeline:          $PIPELINE_URL"
echo "  CodeBuild:         https://${AWS_REGION}.console.aws.amazon.com/codesuite/codebuild/projects/${CODEBUILD_PROJECT}"
echo "  S3 Bucket:         https://s3.console.aws.amazon.com/s3/buckets/${S3_BUCKET}"
echo ""
echo "🚀 Next Steps:"
echo "  1. Trigger pipeline:   ../scripts/trigger-pipeline.sh $ENVIRONMENT"
echo "  2. Monitor execution:  MONITOR_EXECUTION=true ../scripts/trigger-pipeline.sh $ENVIRONMENT"
echo "  3. View logs:          aws logs describe-log-groups --log-group-name-prefix '/aws/codebuild'"
echo ""

# Optional: Subscribe to SNS notifications
if [[ -n "$NOTIFICATION_EMAIL" ]]; then
    SNS_TOPIC_ARN=$(terraform output -raw sns_topic_arn 2>/dev/null || echo "")
    if [[ -n "$SNS_TOPIC_ARN" ]]; then
        echo "[INFO] 📧 Subscribing $NOTIFICATION_EMAIL to pipeline notifications..."
        aws sns subscribe \
            --topic-arn "$SNS_TOPIC_ARN" \
            --protocol email \
            --notification-endpoint "$NOTIFICATION_EMAIL" \
            --region "$AWS_REGION"
        echo "[INFO] ✅ Email subscription created. Check your email to confirm the subscription."
    fi
fi

echo ""
echo "💡 Useful Commands:"
echo "  View pipeline state:   aws codepipeline get-pipeline-state --name $PIPELINE_NAME"
echo "  List executions:       aws codepipeline list-pipeline-executions --pipeline-name $PIPELINE_NAME"
echo "  Terraform outputs:     terraform output"
echo "  Destroy infrastructure: terraform destroy"

cd - >/dev/null
echo "[INFO] ✅ Pipeline infrastructure deployment completed!"