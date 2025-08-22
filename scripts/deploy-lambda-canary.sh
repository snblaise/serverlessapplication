#!/bin/bash
set -euo pipefail

# Lambda canary deployment script using AWS CodeDeploy
# Implements blue/green deployment with automated health checks and rollback

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default values
FUNCTION_NAME=""
ENVIRONMENT="staging"
AWS_REGION="${AWS_REGION:-us-east-1}"
PACKAGE_FILE="lambda-function-signed.zip"
DEPLOYMENT_CONFIG="CodeDeployDefault.Lambda10PercentEvery5Minutes"
HEALTH_CHECK_TIMEOUT=600  # 10 minutes
ROLLBACK_ON_ALARM="true"

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

Deploy Lambda function using CodeDeploy canary deployment

OPTIONS:
    -f, --function NAME     Lambda function name (required)
    -e, --environment ENV   Environment (staging/production) (default: staging)
    -p, --package FILE      Package file (default: lambda-function-signed.zip)
    -c, --config CONFIG     Deployment configuration (default: CodeDeployDefault.Lambda10PercentEvery5Minutes)
    -t, --timeout SECONDS   Health check timeout (default: 600)
    -r, --region REGION     AWS region (default: us-east-1)
    --no-rollback          Disable automatic rollback on alarms
    -h, --help             Show this help message

DEPLOYMENT CONFIGURATIONS:
    CodeDeployDefault.LambdaCanary10Percent5Minutes
    CodeDeployDefault.LambdaCanary10Percent10Minutes
    CodeDeployDefault.LambdaCanary10Percent15Minutes
    CodeDeployDefault.LambdaLinear10PercentEvery1Minute
    CodeDeployDefault.LambdaLinear10PercentEvery2Minutes
    CodeDeployDefault.LambdaLinear10PercentEvery3Minutes
    CodeDeployDefault.LambdaLinear10PercentEvery10Minutes
    CodeDeployDefault.LambdaAllAtOnce

EXAMPLES:
    $0 -f lambda-function-staging -e staging
    $0 -f lambda-function-prod -e production -c CodeDeployDefault.LambdaCanary10Percent10Minutes

ENVIRONMENT VARIABLES:
    AWS_REGION              AWS region (default: us-east-1)
    DEBUG                   Enable debug logging (true/false)
EOF
}

# Function to parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--function)
                FUNCTION_NAME="$2"
                shift 2
                ;;
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -p|--package)
                PACKAGE_FILE="$2"
                shift 2
                ;;
            -c|--config)
                DEPLOYMENT_CONFIG="$2"
                shift 2
                ;;
            -t|--timeout)
                HEALTH_CHECK_TIMEOUT="$2"
                shift 2
                ;;
            -r|--region)
                AWS_REGION="$2"
                shift 2
                ;;
            --no-rollback)
                ROLLBACK_ON_ALARM="false"
                shift
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
    if [ -z "$FUNCTION_NAME" ]; then
        log_error "Function name is required (-f/--function)"
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

# Function to validate Lambda function exists
validate_lambda_function() {
    log_info "Validating Lambda function: $FUNCTION_NAME"
    
    # Check if function exists
    if ! aws lambda get-function \
        --function-name "$FUNCTION_NAME" \
        --region "$AWS_REGION" > /dev/null 2>&1; then
        log_error "Lambda function '$FUNCTION_NAME' not found"
        exit 1
    fi
    
    # Get current function configuration
    FUNCTION_CONFIG=$(aws lambda get-function \
        --function-name "$FUNCTION_NAME" \
        --region "$AWS_REGION" \
        --output json)
    
    CURRENT_VERSION=$(echo "$FUNCTION_CONFIG" | jq -r '.Configuration.Version')
    CODE_SIGNING_CONFIG=$(echo "$FUNCTION_CONFIG" | jq -r '.Configuration.CodeSigningConfigArn // "none"')
    
    log_info "Current function version: $CURRENT_VERSION"
    
    if [ "$CODE_SIGNING_CONFIG" = "none" ]; then
        log_warn "Function does not have code signing configuration"
    else
        log_info "Code signing configuration: $CODE_SIGNING_CONFIG"
    fi
    
    # Check if 'live' alias exists
    if aws lambda get-alias \
        --function-name "$FUNCTION_NAME" \
        --name "live" \
        --region "$AWS_REGION" > /dev/null 2>&1; then
        
        CURRENT_LIVE_VERSION=$(aws lambda get-alias \
            --function-name "$FUNCTION_NAME" \
            --name "live" \
            --region "$AWS_REGION" \
            --query 'FunctionVersion' --output text)
        
        log_info "Current 'live' alias points to version: $CURRENT_LIVE_VERSION"
    else
        log_warn "'live' alias not found - will be created"
    fi
}

# Function to validate CodeDeploy application
validate_codedeploy_application() {
    log_info "Validating CodeDeploy application..."
    
    local app_name="lambda-app-$ENVIRONMENT"
    local deployment_group="lambda-deployment-group"
    
    # Check if application exists
    if ! aws deploy get-application \
        --application-name "$app_name" \
        --region "$AWS_REGION" > /dev/null 2>&1; then
        log_error "CodeDeploy application '$app_name' not found"
        exit 1
    fi
    
    # Check if deployment group exists
    if ! aws deploy get-deployment-group \
        --application-name "$app_name" \
        --deployment-group-name "$deployment_group" \
        --region "$AWS_REGION" > /dev/null 2>&1; then
        log_error "CodeDeploy deployment group '$deployment_group' not found"
        exit 1
    fi
    
    log_info "CodeDeploy application validation passed"
    
    export CODEDEPLOY_APP_NAME="$app_name"
    export CODEDEPLOY_DEPLOYMENT_GROUP="$deployment_group"
}

# Function to update Lambda function code
update_function_code() {
    log_info "Updating Lambda function code..."
    
    cd "$PROJECT_ROOT"
    
    # Update function code
    UPDATE_RESULT=$(aws lambda update-function-code \
        --function-name "$FUNCTION_NAME" \
        --zip-file "fileb://$PACKAGE_FILE" \
        --region "$AWS_REGION" \
        --output json)
    
    if [ $? -ne 0 ]; then
        log_error "Failed to update function code"
        exit 1
    fi
    
    # Wait for update to complete
    log_info "Waiting for function update to complete..."
    
    aws lambda wait function-updated \
        --function-name "$FUNCTION_NAME" \
        --region "$AWS_REGION"
    
    if [ $? -ne 0 ]; then
        log_error "Function update did not complete successfully"
        exit 1
    fi
    
    log_info "Function code updated successfully"
}

# Function to publish new version
publish_new_version() {
    log_info "Publishing new function version..."
    
    # Get current function SHA256
    FUNCTION_SHA256=$(echo "$UPDATE_RESULT" | jq -r '.CodeSha256')
    
    # Publish version with description
    VERSION_RESULT=$(aws lambda publish-version \
        --function-name "$FUNCTION_NAME" \
        --description "Deployed via CI/CD on $(date -u +"%Y-%m-%d %H:%M:%S UTC")" \
        --region "$AWS_REGION" \
        --output json)
    
    if [ $? -ne 0 ]; then
        log_error "Failed to publish new version"
        exit 1
    fi
    
    NEW_VERSION=$(echo "$VERSION_RESULT" | jq -r '.Version')
    
    if [ -z "$NEW_VERSION" ] || [ "$NEW_VERSION" = "null" ]; then
        log_error "Failed to get new version number"
        exit 1
    fi
    
    log_info "Published new version: $NEW_VERSION"
    log_info "Function SHA256: $FUNCTION_SHA256"
    
    export NEW_FUNCTION_VERSION="$NEW_VERSION"
}

# Function to create CodeDeploy deployment
create_codedeploy_deployment() {
    log_info "Creating CodeDeploy canary deployment..."
    
    # Create deployment configuration
    local deployment_config="{
        \"applicationName\": \"$CODEDEPLOY_APP_NAME\",
        \"deploymentGroupName\": \"$CODEDEPLOY_DEPLOYMENT_GROUP\",
        \"deploymentConfigName\": \"$DEPLOYMENT_CONFIG\",
        \"description\": \"Canary deployment for version $NEW_FUNCTION_VERSION\",
        \"revision\": {
            \"revisionType\": \"AppSpecContent\",
            \"appSpecContent\": {
                \"content\": \"{\\\"version\\\": 0.0, \\\"Resources\\\": [{\\\"myLambdaFunction\\\": {\\\"Type\\\": \\\"AWS::Lambda::Function\\\", \\\"Properties\\\": {\\\"Name\\\": \\\"$FUNCTION_NAME\\\", \\\"Alias\\\": \\\"live\\\", \\\"CurrentVersion\\\": \\\"$CURRENT_LIVE_VERSION\\\", \\\"TargetVersion\\\": \\\"$NEW_FUNCTION_VERSION\\\"}}}]}\"
            }
        }
    }"
    
    # Start deployment
    DEPLOYMENT_RESULT=$(aws deploy create-deployment \
        --cli-input-json "$deployment_config" \
        --region "$AWS_REGION" \
        --output json)
    
    if [ $? -ne 0 ]; then
        log_error "Failed to create CodeDeploy deployment"
        exit 1
    fi
    
    DEPLOYMENT_ID=$(echo "$DEPLOYMENT_RESULT" | jq -r '.deploymentId')
    
    if [ -z "$DEPLOYMENT_ID" ] || [ "$DEPLOYMENT_ID" = "null" ]; then
        log_error "Failed to get deployment ID"
        exit 1
    fi
    
    log_info "CodeDeploy deployment started: $DEPLOYMENT_ID"
    export CODEDEPLOY_DEPLOYMENT_ID="$DEPLOYMENT_ID"
}

# Function to monitor deployment progress
monitor_deployment() {
    log_info "Monitoring deployment progress..."
    
    local start_time=$(date +%s)
    local end_time=$((start_time + HEALTH_CHECK_TIMEOUT))
    
    while [ $(date +%s) -lt $end_time ]; do
        # Get deployment status
        DEPLOYMENT_STATUS=$(aws deploy get-deployment \
            --deployment-id "$CODEDEPLOY_DEPLOYMENT_ID" \
            --region "$AWS_REGION" \
            --output json)
        
        STATUS=$(echo "$DEPLOYMENT_STATUS" | jq -r '.deploymentInfo.status')
        
        case "$STATUS" in
            "Succeeded")
                log_info "Deployment completed successfully"
                return 0
                ;;
            "Failed"|"Stopped")
                local error_info=$(echo "$DEPLOYMENT_STATUS" | jq -r '.deploymentInfo.errorInformation // {}')
                log_error "Deployment failed: $error_info"
                return 1
                ;;
            "InProgress"|"Queued"|"Ready")
                log_debug "Deployment status: $STATUS"
                ;;
            *)
                log_warn "Unknown deployment status: $STATUS"
                ;;
        esac
        
        sleep 30
    done
    
    log_error "Deployment monitoring timed out after $HEALTH_CHECK_TIMEOUT seconds"
    return 1
}

# Function to check CloudWatch alarms
check_cloudwatch_alarms() {
    log_info "Checking CloudWatch alarms..."
    
    # Define alarm names based on function and environment
    local alarm_names=(
        "lambda-error-rate-$ENVIRONMENT"
        "lambda-duration-$ENVIRONMENT"
        "lambda-throttle-$ENVIRONMENT"
    )
    
    local alarm_triggered=false
    
    for alarm_name in "${alarm_names[@]}"; do
        # Check if alarm exists and get its state
        ALARM_STATE=$(aws cloudwatch describe-alarms \
            --alarm-names "$alarm_name" \
            --region "$AWS_REGION" \
            --query 'MetricAlarms[0].StateValue' --output text 2>/dev/null || echo "UNKNOWN")
        
        case "$ALARM_STATE" in
            "ALARM")
                log_error "CloudWatch alarm triggered: $alarm_name"
                alarm_triggered=true
                ;;
            "OK")
                log_debug "CloudWatch alarm OK: $alarm_name"
                ;;
            "INSUFFICIENT_DATA")
                log_warn "CloudWatch alarm has insufficient data: $alarm_name"
                ;;
            "UNKNOWN")
                log_debug "CloudWatch alarm not found or not accessible: $alarm_name"
                ;;
        esac
    done
    
    if [ "$alarm_triggered" = true ]; then
        if [ "$ROLLBACK_ON_ALARM" = "true" ]; then
            log_error "CloudWatch alarms triggered - initiating rollback"
            return 1
        else
            log_warn "CloudWatch alarms triggered but rollback disabled"
        fi
    else
        log_info "All CloudWatch alarms are in OK state"
    fi
    
    return 0
}

# Function to perform health checks
perform_health_checks() {
    log_info "Performing deployment health checks..."
    
    # Monitor deployment progress
    if ! monitor_deployment; then
        log_error "Deployment monitoring failed"
        return 1
    fi
    
    # Check CloudWatch alarms
    if ! check_cloudwatch_alarms; then
        log_error "Health check failed due to CloudWatch alarms"
        return 1
    fi
    
    # Additional custom health checks can be added here
    log_info "All health checks passed"
    return 0
}

# Function to rollback deployment
rollback_deployment() {
    log_error "Initiating deployment rollback..."
    
    # Stop current deployment if still in progress
    aws deploy stop-deployment \
        --deployment-id "$CODEDEPLOY_DEPLOYMENT_ID" \
        --auto-rollback-enabled \
        --region "$AWS_REGION" 2>/dev/null || true
    
    # Get previous version for rollback
    if [ -n "${CURRENT_LIVE_VERSION:-}" ] && [ "$CURRENT_LIVE_VERSION" != "null" ]; then
        log_info "Rolling back to previous version: $CURRENT_LIVE_VERSION"
        
        # Update alias to previous version
        aws lambda update-alias \
            --function-name "$FUNCTION_NAME" \
            --name "live" \
            --function-version "$CURRENT_LIVE_VERSION" \
            --region "$AWS_REGION"
        
        if [ $? -eq 0 ]; then
            log_info "Rollback completed successfully"
        else
            log_error "Rollback failed"
        fi
    else
        log_error "No previous version available for rollback"
    fi
}

# Function to generate deployment report
generate_deployment_report() {
    log_info "Generating deployment report..."
    
    cd "$PROJECT_ROOT"
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local deployment_status="unknown"
    
    if [ -n "${CODEDEPLOY_DEPLOYMENT_ID:-}" ]; then
        deployment_status=$(aws deploy get-deployment \
            --deployment-id "$CODEDEPLOY_DEPLOYMENT_ID" \
            --region "$AWS_REGION" \
            --query 'deploymentInfo.status' --output text 2>/dev/null || echo "unknown")
    fi
    
    cat > "deployment-report.json" << EOF
{
  "functionName": "$FUNCTION_NAME",
  "environment": "$ENVIRONMENT",
  "awsRegion": "$AWS_REGION",
  "timestamp": "$timestamp",
  "packageFile": "$PACKAGE_FILE",
  "deploymentConfig": "$DEPLOYMENT_CONFIG",
  "previousVersion": "${CURRENT_LIVE_VERSION:-unknown}",
  "newVersion": "${NEW_FUNCTION_VERSION:-unknown}",
  "codeDeploymentId": "${CODEDEPLOY_DEPLOYMENT_ID:-unknown}",
  "deploymentStatus": "$deployment_status",
  "healthCheckTimeout": $HEALTH_CHECK_TIMEOUT,
  "rollbackOnAlarm": $ROLLBACK_ON_ALARM,
  "gitCommit": "$(git rev-parse HEAD 2>/dev/null || echo 'unknown')",
  "gitBranch": "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')"
}
EOF
    
    log_info "Deployment report generated: deployment-report.json"
}

# Main execution
main() {
    log_info "Starting Lambda canary deployment..."
    
    parse_args "$@"
    check_prerequisites
    validate_lambda_function
    validate_codedeploy_application
    update_function_code
    publish_new_version
    create_codedeploy_deployment
    
    # Perform health checks and handle rollback if needed
    if ! perform_health_checks; then
        if [ "$ROLLBACK_ON_ALARM" = "true" ]; then
            rollback_deployment
            generate_deployment_report
            exit 1
        else
            log_warn "Health checks failed but rollback disabled"
        fi
    fi
    
    generate_deployment_report
    
    log_info "Lambda canary deployment completed successfully!"
    log_info "Function: $FUNCTION_NAME"
    log_info "New version: $NEW_FUNCTION_VERSION"
    log_info "Deployment ID: $CODEDEPLOY_DEPLOYMENT_ID"
    log_info "Report: deployment-report.json"
}

# Execute main function
main "$@"