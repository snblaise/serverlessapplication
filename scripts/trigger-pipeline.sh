#!/bin/bash

# Script to trigger the complete CI/CD pipeline
# Usage: ./scripts/trigger-pipeline.sh [environment] [source-path]

set -euo pipefail

# Configuration
ENVIRONMENT="${1:-staging}"
SOURCE_PATH="${2:-.}"
PIPELINE_NAME="lambda-function-${ENVIRONMENT}-pipeline"
AWS_REGION="${AWS_REGION:-us-east-1}"
BUCKET_NAME="lambda-artifacts-${ENVIRONMENT}"

echo "[INFO] 🚀 Triggering CI/CD pipeline..."
echo "[INFO] Pipeline: $PIPELINE_NAME"
echo "[INFO] Environment: $ENVIRONMENT"
echo "[INFO] Source Path: $SOURCE_PATH"
echo "[INFO] Region: $AWS_REGION"

# Check if pipeline exists
if ! aws codepipeline get-pipeline --name "$PIPELINE_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
    echo "[ERROR] Pipeline '$PIPELINE_NAME' not found in region '$AWS_REGION'"
    echo "[INFO] Make sure to deploy the infrastructure first:"
    echo "       cd infrastructure && terraform apply"
    exit 1
fi

# Check if S3 bucket exists
if ! aws s3 ls "s3://$BUCKET_NAME" >/dev/null 2>&1; then
    echo "[ERROR] S3 bucket '$BUCKET_NAME' not found"
    echo "[INFO] Make sure to deploy the infrastructure first"
    exit 1
fi

# Create source package
echo "[INFO] 📦 Creating source package..."
SOURCE_ZIP="source-$(date +%Y%m%d-%H%M%S).zip"
TEMP_DIR=$(mktemp -d)

# Copy source files to temp directory
cp -r "$SOURCE_PATH"/* "$TEMP_DIR/" 2>/dev/null || true

# Exclude unnecessary files
cd "$TEMP_DIR"
rm -rf .git* node_modules coverage build dist .DS_Store *.log 2>/dev/null || true

# Create the zip file
zip -r "$SOURCE_ZIP" . -q

# Upload source to S3
echo "[INFO] ⬆️  Uploading source to S3..."
aws s3 cp "$SOURCE_ZIP" "s3://$BUCKET_NAME/source/source.zip" --region "$AWS_REGION"

# Clean up temp files
cd - >/dev/null
rm -rf "$TEMP_DIR" "$SOURCE_ZIP"

# Start the pipeline
echo "[INFO] ▶️  Starting pipeline execution..."
EXECUTION_ID=$(aws codepipeline start-pipeline-execution \
    --name "$PIPELINE_NAME" \
    --region "$AWS_REGION" \
    --query 'pipelineExecutionId' \
    --output text)

if [[ -z "$EXECUTION_ID" ]]; then
    echo "[ERROR] Failed to start pipeline"
    exit 1
fi

echo "[INFO] ✅ Pipeline started successfully!"
echo "[INFO] Execution ID: $EXECUTION_ID"
echo "[INFO] 🔗 Console URL: https://${AWS_REGION}.console.aws.amazon.com/codesuite/codepipeline/pipelines/${PIPELINE_NAME}/executions/${EXECUTION_ID}"

# Optional: Monitor pipeline execution
if [[ "${MONITOR_EXECUTION:-false}" == "true" ]]; then
    echo "[INFO] 👀 Monitoring pipeline execution..."
    
    while true; do
        PIPELINE_STATUS=$(aws codepipeline get-pipeline-execution \
            --pipeline-name "$PIPELINE_NAME" \
            --pipeline-execution-id "$EXECUTION_ID" \
            --region "$AWS_REGION" \
            --query 'pipelineExecution.status' \
            --output text)
        
        case "$PIPELINE_STATUS" in
            "Succeeded")
                echo "[INFO] ✅ Pipeline completed successfully!"
                break
                ;;
            "Failed"|"Cancelled"|"Superseded")
                echo "[ERROR] ❌ Pipeline failed with status: $PIPELINE_STATUS"
                
                # Get failure details
                aws codepipeline get-pipeline-execution \
                    --pipeline-name "$PIPELINE_NAME" \
                    --pipeline-execution-id "$EXECUTION_ID" \
                    --region "$AWS_REGION" \
                    --query 'pipelineExecution.statusSummary' \
                    --output text
                
                exit 1
                ;;
            "InProgress")
                echo "[INFO] 🔄 Pipeline in progress..."
                
                # Show current stage
                CURRENT_STAGE=$(aws codepipeline list-action-executions \
                    --pipeline-name "$PIPELINE_NAME" \
                    --filter pipelineExecutionId="$EXECUTION_ID" \
                    --region "$AWS_REGION" \
                    --query 'actionExecutionDetails[?status==`InProgress`].stageName' \
                    --output text | head -1)
                
                if [[ -n "$CURRENT_STAGE" ]]; then
                    echo "[INFO] 📍 Current stage: $CURRENT_STAGE"
                fi
                
                sleep 30
                ;;
            *)
                echo "[INFO] 📊 Pipeline status: $PIPELINE_STATUS"
                sleep 15
                ;;
        esac
    done
    
    # Get final execution details
    echo "[INFO] 📋 Final execution details:"
    aws codepipeline get-pipeline-execution \
        --pipeline-name "$PIPELINE_NAME" \
        --pipeline-execution-id "$EXECUTION_ID" \
        --region "$AWS_REGION" \
        --query 'pipelineExecution' \
        --output table
fi

echo "[INFO] 🎉 Pipeline trigger completed!"

# Show useful commands
echo ""
echo "[INFO] 💡 Useful commands:"
echo "  Monitor pipeline:    aws codepipeline get-pipeline-state --name $PIPELINE_NAME"
echo "  View execution:      aws codepipeline get-pipeline-execution --pipeline-name $PIPELINE_NAME --pipeline-execution-id $EXECUTION_ID"
echo "  Stop pipeline:       aws codepipeline stop-pipeline-execution --pipeline-name $PIPELINE_NAME --pipeline-execution-id $EXECUTION_ID"
echo "  View logs:           Check CodeBuild project logs in CloudWatch"