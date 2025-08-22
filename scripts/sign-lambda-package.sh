#!/bin/bash
set -euo pipefail

# AWS Signer integration script for Lambda code signing
# This script signs Lambda deployment packages using AWS Signer

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default values
PACKAGE_FILE="lambda-function.zip"
ENVIRONMENT="staging"
AWS_REGION="${AWS_REGION:-us-east-1}"
SIGNING_PROFILE=""
S3_BUCKET=""
WAIT_TIMEOUT=300  # 5 minutes

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

log_debug() {
    if [ "${DEBUG:-false}" = "true" ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Sign Lambda deployment package using AWS Signer

OPTIONS:
    -f, --file FILE         Lambda package file (default: lambda-function.zip)
    -e, --environment ENV   Environment (staging/production) (default: staging)
    -p, --profile PROFILE   Signing profile name (required)
    -b, --bucket BUCKET     S3 bucket for artifacts (required)
    -r, --region REGION     AWS region (default: us-east-1)
    -t, --timeout SECONDS   Wait timeout for signing job (default: 300)
    -h, --help             Show this help message

EXAMPLES:
    $0 -p lambda-staging -b lambda-artifacts-staging
    $0 -f my-function.zip -e production -p lambda-prod -b lambda-artifacts-prod

ENVIRONMENT VARIABLES:
    AWS_REGION              AWS region (default: us-east-1)
    DEBUG                   Enable debug logging (true/false)
EOF
}

# Function to parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--file)
                PACKAGE_FILE="$2"
                shift 2
                ;;
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -p|--profile)
                SIGNING_PROFILE="$2"
                shift 2
                ;;
            -b|--bucket)
                S3_BUCKET="$2"
                shift 2
                ;;
            -r|--region)
                AWS_REGION="$2"
                shift 2
                ;;
            -t|--timeout)
                WAIT_TIMEOUT="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Validate required parameters
    if [ -z "$SIGNING_PROFILE" ]; then
        log_error "Signing profile is required (-p/--profile)"
        exit 1
    fi
    
    if [ -z "$S3_BUCKET" ]; then
        log_error "S3 bucket is required (-b/--bucket)"
        exit 1
    fi
}

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured or invalid"
        exit 1
    fi
    
    # Check package file exists
    if [ ! -f "$PROJECT_ROOT/$PACKAGE_FILE" ]; then
        log_error "Package file not found: $PACKAGE_FILE"
        exit 1
    fi
    
    # Check jq for JSON parsing
    if ! command -v jq &> /dev/null; then
        log_error "jq is required for JSON parsing"
        exit 1
    fi
    
    log_info "Prerequisites check passed"
}

# Function to validate signing profile
validate_signing_profile() {
    log_info "Validating signing profile: $SIGNING_PROFILE"
    
    # Check if signing profile exists and is active
    PROFILE_STATUS=$(aws signer describe-signing-job \
        --job-id "dummy" \
        --region "$AWS_REGION" 2>/dev/null || echo "")
    
    # Get signing profile details
    PROFILE_INFO=$(aws signer get-signing-profile \
        --profile-name "$SIGNING_PROFILE" \
        --region "$AWS_REGION" 2>/dev/null || echo "")
    
    if [ -z "$PROFILE_INFO" ]; then
        log_error "Signing profile '$SIGNING_PROFILE' not found or not accessible"
        exit 1
    fi
    
    # Check profile status
    PROFILE_STATUS=$(echo "$PROFILE_INFO" | jq -r '.status // "Unknown"')
    if [ "$PROFILE_STATUS" != "Active" ]; then
        log_error "Signing profile '$SIGNING_PROFILE' is not active (status: $PROFILE_STATUS)"
        exit 1
    fi
    
    # Check platform compatibility
    PLATFORM_ID=$(echo "$PROFILE_INFO" | jq -r '.platformId // "Unknown"')
    if [ "$PLATFORM_ID" != "AWSLambda-SHA384-ECDSA" ]; then
        log_warn "Signing profile platform '$PLATFORM_ID' may not be compatible with Lambda"
    fi
    
    log_info "Signing profile validation passed"
}

# Function to upload package to S3
upload_to_s3() {
    log_info "Uploading package to S3..."
    
    cd "$PROJECT_ROOT"
    
    # Generate unique key for this upload
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    S3_KEY="unsigned/${ENVIRONMENT}/${TIMESTAMP}-${GIT_COMMIT}/${PACKAGE_FILE}"
    
    log_debug "S3 key: s3://$S3_BUCKET/$S3_KEY"
    
    # Upload with metadata
    aws s3 cp "$PACKAGE_FILE" "s3://$S3_BUCKET/$S3_KEY" \
        --metadata "environment=$ENVIRONMENT,timestamp=$TIMESTAMP,commit=$GIT_COMMIT" \
        --region "$AWS_REGION"
    
    if [ $? -ne 0 ]; then
        log_error "Failed to upload package to S3"
        exit 1
    fi
    
    # Get object version if versioning is enabled
    S3_VERSION=$(aws s3api head-object \
        --bucket "$S3_BUCKET" \
        --key "$S3_KEY" \
        --region "$AWS_REGION" \
        --query 'VersionId' --output text 2>/dev/null || echo "null")
    
    log_info "Package uploaded to S3: s3://$S3_BUCKET/$S3_KEY"
    if [ "$S3_VERSION" != "null" ]; then
        log_debug "S3 version: $S3_VERSION"
    fi
    
    # Export for use in signing job
    export S3_SOURCE_KEY="$S3_KEY"
    export S3_SOURCE_VERSION="$S3_VERSION"
}

# Function to start signing job
start_signing_job() {
    log_info "Starting signing job..."
    
    # Prepare source configuration
    SOURCE_CONFIG="{\"s3\":{\"bucketName\":\"$S3_BUCKET\",\"key\":\"$S3_SOURCE_KEY\""
    if [ "$S3_SOURCE_VERSION" != "null" ]; then
        SOURCE_CONFIG="$SOURCE_CONFIG,\"version\":\"$S3_SOURCE_VERSION\""
    fi
    SOURCE_CONFIG="$SOURCE_CONFIG}}"
    
    # Prepare destination configuration
    DEST_PREFIX="signed/${ENVIRONMENT}/$(date +%Y%m%d-%H%M%S)"
    DEST_CONFIG="{\"s3\":{\"bucketName\":\"$S3_BUCKET\",\"prefix\":\"$DEST_PREFIX\"}}"
    
    log_debug "Source config: $SOURCE_CONFIG"
    log_debug "Destination config: $DEST_CONFIG"
    
    # Start signing job
    SIGNING_JOB=$(aws signer start-signing-job \
        --source "$SOURCE_CONFIG" \
        --destination "$DEST_CONFIG" \
        --profile-name "$SIGNING_PROFILE" \
        --region "$AWS_REGION" \
        --output json)
    
    if [ $? -ne 0 ]; then
        log_error "Failed to start signing job"
        exit 1
    fi
    
    JOB_ID=$(echo "$SIGNING_JOB" | jq -r '.jobId')
    
    if [ -z "$JOB_ID" ] || [ "$JOB_ID" = "null" ]; then
        log_error "Failed to get signing job ID"
        exit 1
    fi
    
    log_info "Signing job started: $JOB_ID"
    export SIGNING_JOB_ID="$JOB_ID"
}

# Function to wait for signing job completion
wait_for_signing_job() {
    log_info "Waiting for signing job to complete..."
    
    local start_time=$(date +%s)
    local end_time=$((start_time + WAIT_TIMEOUT))
    
    while [ $(date +%s) -lt $end_time ]; do
        # Get job status
        JOB_STATUS=$(aws signer describe-signing-job \
            --job-id "$SIGNING_JOB_ID" \
            --region "$AWS_REGION" \
            --output json)
        
        STATUS=$(echo "$JOB_STATUS" | jq -r '.status')
        
        case "$STATUS" in
            "Succeeded")
                log_info "Signing job completed successfully"
                
                # Get signed object details
                SIGNED_OBJECT=$(echo "$JOB_STATUS" | jq -r '.signedObject.s3')
                SIGNED_BUCKET=$(echo "$SIGNED_OBJECT" | jq -r '.bucketName')
                SIGNED_KEY=$(echo "$SIGNED_OBJECT" | jq -r '.key')
                
                log_info "Signed package: s3://$SIGNED_BUCKET/$SIGNED_KEY"
                
                # Export signed package details
                export SIGNED_S3_BUCKET="$SIGNED_BUCKET"
                export SIGNED_S3_KEY="$SIGNED_KEY"
                
                return 0
                ;;
            "Failed")
                local reason=$(echo "$JOB_STATUS" | jq -r '.statusReason // "Unknown error"')
                log_error "Signing job failed: $reason"
                exit 1
                ;;
            "InProgress")
                log_debug "Signing job in progress..."
                ;;
            *)
                log_debug "Signing job status: $STATUS"
                ;;
        esac
        
        sleep 10
    done
    
    log_error "Signing job timed out after $WAIT_TIMEOUT seconds"
    exit 1
}

# Function to download signed package
download_signed_package() {
    log_info "Downloading signed package..."
    
    cd "$PROJECT_ROOT"
    
    # Create signed package filename
    SIGNED_PACKAGE_FILE="${PACKAGE_FILE%.zip}-signed.zip"
    
    # Download signed package
    aws s3 cp "s3://$SIGNED_S3_BUCKET/$SIGNED_S3_KEY" "$SIGNED_PACKAGE_FILE" \
        --region "$AWS_REGION"
    
    if [ $? -ne 0 ]; then
        log_error "Failed to download signed package"
        exit 1
    fi
    
    log_info "Signed package downloaded: $SIGNED_PACKAGE_FILE"
    
    # Verify signed package
    if [ ! -f "$SIGNED_PACKAGE_FILE" ]; then
        log_error "Signed package file not found after download"
        exit 1
    fi
    
    # Get package size
    SIGNED_SIZE=$(stat -f%z "$SIGNED_PACKAGE_FILE" 2>/dev/null || stat -c%s "$SIGNED_PACKAGE_FILE" 2>/dev/null)
    ORIGINAL_SIZE=$(stat -f%z "$PACKAGE_FILE" 2>/dev/null || stat -c%s "$PACKAGE_FILE" 2>/dev/null)
    
    log_info "Package sizes - Original: $ORIGINAL_SIZE bytes, Signed: $SIGNED_SIZE bytes"
    
    # Generate checksums for signed package
    if command -v sha256sum &> /dev/null; then
        SIGNED_SHA256=$(sha256sum "$SIGNED_PACKAGE_FILE" | cut -d' ' -f1)
    elif command -v shasum &> /dev/null; then
        SIGNED_SHA256=$(shasum -a 256 "$SIGNED_PACKAGE_FILE" | cut -d' ' -f1)
    else
        SIGNED_SHA256="unavailable"
    fi
    
    echo "$SIGNED_SHA256  $SIGNED_PACKAGE_FILE" > "${SIGNED_PACKAGE_FILE}.sha256"
    
    log_info "Signed package checksum: ${SIGNED_SHA256:0:16}..."
    
    export SIGNED_PACKAGE_FILE
}

# Function to generate signing report
generate_signing_report() {
    log_info "Generating signing report..."
    
    cd "$PROJECT_ROOT"
    
    # Create signing report
    cat > "signing-report.json" << EOF
{
  "signingJobId": "$SIGNING_JOB_ID",
  "signingProfile": "$SIGNING_PROFILE",
  "environment": "$ENVIRONMENT",
  "awsRegion": "$AWS_REGION",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "originalPackage": {
    "file": "$PACKAGE_FILE",
    "size": $(stat -f%z "$PACKAGE_FILE" 2>/dev/null || stat -c%s "$PACKAGE_FILE" 2>/dev/null),
    "sha256": "$(cat "${PACKAGE_FILE}.sha256" 2>/dev/null | cut -d' ' -f1 || echo 'unavailable')"
  },
  "signedPackage": {
    "file": "$SIGNED_PACKAGE_FILE",
    "size": $(stat -f%z "$SIGNED_PACKAGE_FILE" 2>/dev/null || stat -c%s "$SIGNED_PACKAGE_FILE" 2>/dev/null),
    "sha256": "$SIGNED_SHA256",
    "s3Location": "s3://$SIGNED_S3_BUCKET/$SIGNED_S3_KEY"
  },
  "gitCommit": "$(git rev-parse HEAD 2>/dev/null || echo 'unknown')",
  "gitBranch": "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')"
}
EOF
    
    log_info "Signing report generated: signing-report.json"
}

# Function to cleanup temporary files
cleanup() {
    log_info "Cleaning up temporary files..."
    
    # Remove unsigned package from S3 (optional, for security)
    if [ "${CLEANUP_S3:-true}" = "true" ] && [ -n "${S3_SOURCE_KEY:-}" ]; then
        log_debug "Removing unsigned package from S3: s3://$S3_BUCKET/$S3_SOURCE_KEY"
        aws s3 rm "s3://$S3_BUCKET/$S3_SOURCE_KEY" --region "$AWS_REGION" 2>/dev/null || true
    fi
}

# Main execution
main() {
    log_info "Starting Lambda package signing process..."
    
    parse_args "$@"
    check_prerequisites
    validate_signing_profile
    upload_to_s3
    start_signing_job
    wait_for_signing_job
    download_signed_package
    generate_signing_report
    cleanup
    
    log_info "Lambda package signing completed successfully!"
    log_info "Signed package: $SIGNED_PACKAGE_FILE"
    log_info "Signing report: signing-report.json"
    log_info "S3 location: s3://$SIGNED_S3_BUCKET/$SIGNED_S3_KEY"
}

# Trap for cleanup on exit
trap cleanup EXIT

# Execute main function
main "$@"