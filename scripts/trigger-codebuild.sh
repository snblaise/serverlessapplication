#!/bin/bash

# Script to trigger AWS CodeBuild project for Lambda function
# Usage: ./scripts/trigger-codebuild.sh [environment] [source-version]

set -euo pipefail

# Configuration
ENVIRONMENT="${1:-staging}"
SOURCE_VERSION="${2:-main}"
PROJECT_NAME="lambda-function-${ENVIRONMENT}-build"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo "[INFO] 🚀 Triggering CodeBuild project..."
echo "[INFO] Project: $PROJECT_NAME"
echo "[INFO] Environment: $ENVIRONMENT"
echo "[INFO] Source Version: $SOURCE_VERSION"
echo "[INFO] Region: $AWS_REGION"

# Check if project exists
if ! aws codebuild batch-get-projects --names "$PROJECT_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
    echo "[ERROR] CodeBuild project '$PROJECT_NAME' not found in region '$AWS_REGION'"
    echo "[INFO] Make sure to deploy the infrastructure first:"
    echo "       cd infrastructure && terraform apply"
    exit 1
fi

# Start the build
echo "[INFO] Starting build..."
BUILD_ID=$(aws codebuild start-build \
    --project-name "$PROJECT_NAME" \
    --source-version "$SOURCE_VERSION" \
    --region "$AWS_REGION" \
    --query 'build.id' \
    --output text)

if [[ -z "$BUILD_ID" ]]; then
    echo "[ERROR] Failed to start build"
    exit 1
fi

echo "[INFO] ✅ Build started successfully!"
echo "[INFO] Build ID: $BUILD_ID"
echo "[INFO] 🔗 Console URL: https://${AWS_REGION}.console.aws.amazon.com/codesuite/codebuild/projects/${PROJECT_NAME}/build/${BUILD_ID}"

# Optional: Wait for build to complete
if [[ "${WAIT_FOR_COMPLETION:-false}" == "true" ]]; then
    echo "[INFO] ⏳ Waiting for build to complete..."
    
    while true; do
        BUILD_STATUS=$(aws codebuild batch-get-builds \
            --ids "$BUILD_ID" \
            --region "$AWS_REGION" \
            --query 'builds[0].buildStatus' \
            --output text)
        
        case "$BUILD_STATUS" in
            "SUCCEEDED")
                echo "[INFO] ✅ Build completed successfully!"
                break
                ;;
            "FAILED"|"FAULT"|"STOPPED"|"TIMED_OUT")
                echo "[ERROR] ❌ Build failed with status: $BUILD_STATUS"
                exit 1
                ;;
            "IN_PROGRESS")
                echo "[INFO] 🔄 Build in progress..."
                sleep 30
                ;;
            *)
                echo "[INFO] 📊 Build status: $BUILD_STATUS"
                sleep 10
                ;;
        esac
    done
    
    # Get build logs URL
    LOGS_URL=$(aws codebuild batch-get-builds \
        --ids "$BUILD_ID" \
        --region "$AWS_REGION" \
        --query 'builds[0].logs.deepLink' \
        --output text)
    
    if [[ "$LOGS_URL" != "None" ]]; then
        echo "[INFO] 📋 Build logs: $LOGS_URL"
    fi
fi

echo "[INFO] 🎉 CodeBuild trigger completed!"