#!/bin/bash
set -euo pipefail

# Lambda deployment rollback script
# Provides emergency rollback capabilities for Lambda deployments

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default values
FUNCTION_NAME=""
ENVIRONMENT="staging"
AWS_REGION="${AWS_REGION:-us-east-1}"
TARGET_VERSION=""
ROLLBACK_MODE="auto"  # auto, manual, emergency
FORCE_ROLLBACK="false"

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

Rollback Lambda deployment to previous version

OPTIONS:
    -f, --function NAME     Lambda function name (required)
    -e, --environment ENV   Environment (staging/production) (default: staging)
    -v, --version VERSION   Target version to rollback to (auto-detected if not specified)
    -m, --mode MODE         Rollback mode: auto, manual, emergency (default: auto)
    -r, --region REGION     AWS region (default: us-east-1)
    --force                Force rollback without confirmation
    -h, --help             Show this help message

ROLLBACK MODES:
    auto                   Automatic rollback to previous version
    manual                 Manual rollback with user confirmation
    emergency              Emergency rollback with minimal checks

EXAMPLES:
    $0 -f lambda-function-staging -e staging
    $0 -f lambda-function-prod -e production -v 5 -m manual
    $0 -f lambda-function-prod -m emergency --force

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
            -v|--version)
                TARGET_VERSION="$2"
                shift 2
                ;;
            -m|--mode)
                ROLLBACK_MODE="$2"
                shift 2
                ;;
            -r|--region)
                AWS_REGION="$2"
                shift 2
                ;;
            --force)
                FORCE_ROLLBACK="true"
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
    
    # Validate rollback mode
    case "$ROLLBACK_MODE" in
        auto|manual|emergency)
            ;;
        *)
            log_error "Invalid rollback mode: $ROLLBACK_MODE"
            exit 1
            ;;
    esac
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
    
    # Check jq for JSON parsing
    if ! command -v jq &> /dev/null; then
        log_error "jq is required for JSON parsing"
        exit 1
    fi
    
    log_info "Prerequisites check passed"
}

# Function to get function information
get_function_info() {
    log_info "Getting function information..."
    
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
    
    # Get current alias configuration
    if aws lambda get-alias \
        --function-name "$FUNCTION_NAME" \
        --name "live" \
        --region "$AWS_REGION" > /dev/null 2>&1; then
        
        ALIAS_CONFIG=$(aws lambda get-alias \
            --function-name "$FUNCTION_NAME" \
            --name "live" \
            --region "$AWS_REGION" \
            --output json)
        
        CURRENT_LIVE_VERSION=$(echo "$ALIAS_CONFIG" | jq -r '.FunctionVersion')
        
        log_info "Current function version: $CURRENT_VERSION"
        log_info "Current 'live' alias version: $CURRENT_LIVE_VERSION"
    else
        log_error "'live' alias not found"
        exit 1
    fi
    
    export CURRENT_FUNCTION_VERSION="$CURRENT_VERSION"
    export CURRENT_LIVE_VERSION
}

# Function to list available versions
list_available_versions() {
    log_info "Listing available versions..."
    
    # Get all versions
    VERSIONS=$(aws lambda list-versions-by-function \
        --function-name "$FUNCTION_NAME" \
        --region "$AWS_REGION" \
        --output json)
    
    # Extract version numbers (excluding $LATEST)
    AVAILABLE_VERSIONS=$(echo "$VERSIONS" | jq -r '.Versions[] | select(.Version != "$LATEST") | .Version' | sort -n)
    
    if [ -z "$AVAILABLE_VERSIONS" ]; then
        log_error "No versions available for rollback"
        exit 1
    fi
    
    log_info "Available versions:"
    echo "$AVAILABLE_VERSIONS" | while read -r version; do
        # Get version details
        VERSION_INFO=$(echo "$VERSIONS" | jq -r ".Versions[] | select(.Version == \"$version\")")
        LAST_MODIFIED=$(echo "$VERSION_INFO" | jq -r '.LastModified')
        DESCRIPTION=$(echo "$VERSION_INFO" | jq -r '.Description // "No description"')
        
        if [ "$version" = "$CURRENT_LIVE_VERSION" ]; then
            echo "  $version (CURRENT) - $LAST_MODIFIED - $DESCRIPTION"
        else
            echo "  $version - $LAST_MODIFIED - $DESCRIPTION"
        fi
    done
    
    export AVAILABLE_VERSIONS
}

# Function to determine target version
determine_target_version() {
    log_info "Determining target version for rollback..."
    
    if [ -n "$TARGET_VERSION" ]; then
        # Validate specified version exists
        if ! echo "$AVAILABLE_VERSIONS" | grep -q "^$TARGET_VERSION$"; then
            log_error "Specified version '$TARGET_VERSION' not found"
            exit 1
        fi
        
        log_info "Using specified target version: $TARGET_VERSION"
    else
        # Auto-determine previous version
        SORTED_VERSIONS=$(echo "$AVAILABLE_VERSIONS" | sort -n)
        
        # Find version before current live version
        PREVIOUS_VERSION=""
        while read -r version; do
            if [ "$version" = "$CURRENT_LIVE_VERSION" ]; then
                break
            fi
            PREVIOUS_VERSION="$version"
        done <<< "$SORTED_VERSIONS"
        
        if [ -z "$PREVIOUS_VERSION" ]; then
            log_error "No previous version available for rollback"
            exit 1
        fi
        
        TARGET_VERSION="$PREVIOUS_VERSION"
        log_info "Auto-determined target version: $TARGET_VERSION"
    fi
    
    # Validate target version is different from current
    if [ "$TARGET_VERSION" = "$CURRENT_LIVE_VERSION" ]; then
        log_error "Target version is the same as current version"
        exit 1
    fi
    
    export TARGET_VERSION
}

# Function to check rollback safety
check_rollback_safety() {
    if [ "$ROLLBACK_MODE" = "emergency" ]; then
        log_warn "Emergency mode - skipping safety checks"
        return 0
    fi
    
    log_info "Performing rollback safety checks..."
    
    # Check if there are any active CodeDeploy deployments
    local app_name="lambda-app-$ENVIRONMENT"
    
    if aws deploy list-deployments \
        --application-name "$app_name" \
        --deployment-group-name "lambda-deployment-group" \
        --include-only-statuses "InProgress" "Queued" "Ready" \
        --region "$AWS_REGION" \
        --output text --query 'deployments[0]' 2>/dev/null | grep -q .; then
        
        log_warn "Active CodeDeploy deployment found"
        
        if [ "$FORCE_ROLLBACK" != "true" ]; then
            log_error "Cannot rollback with active deployment. Use --force to override."
            exit 1
        fi
    fi
    
    # Check CloudWatch alarms
    local alarm_names=(
        "lambda-error-rate-$ENVIRONMENT"
        "lambda-duration-$ENVIRONMENT"
        "lambda-throttle-$ENVIRONMENT"
    )
    
    local critical_alarms=0
    
    for alarm_name in "${alarm_names[@]}"; do
        ALARM_STATE=$(aws cloudwatch describe-alarms \
            --alarm-names "$alarm_name" \
            --region "$AWS_REGION" \
            --query 'MetricAlarms[0].StateValue' --output text 2>/dev/null || echo "UNKNOWN")
        
        if [ "$ALARM_STATE" = "ALARM" ]; then
            log_warn "Critical alarm active: $alarm_name"
            critical_alarms=$((critical_alarms + 1))
        fi
    done
    
    if [ $critical_alarms -gt 0 ]; then
        log_warn "$critical_alarms critical alarms are active"
        if [ "$ROLLBACK_MODE" = "auto" ]; then
            log_info "Proceeding with rollback due to critical alarms"
        fi
    fi
    
    log_info "Safety checks completed"
}

# Function to confirm rollback
confirm_rollback() {
    if [ "$FORCE_ROLLBACK" = "true" ] || [ "$ROLLBACK_MODE" = "auto" ]; then
        return 0
    fi
    
    log_warn "ROLLBACK CONFIRMATION REQUIRED"
    echo "Function: $FUNCTION_NAME"
    echo "Environment: $ENVIRONMENT"
    echo "Current version: $CURRENT_LIVE_VERSION"
    echo "Target version: $TARGET_VERSION"
    echo "Rollback mode: $ROLLBACK_MODE"
    echo ""
    
    read -p "Are you sure you want to proceed with rollback? (yes/no): " confirmation
    
    case "$confirmation" in
        yes|YES|y|Y)
            log_info "Rollback confirmed by user"
            return 0
            ;;
        *)
            log_info "Rollback cancelled by user"
            exit 0
            ;;
    esac
}

# Function to stop active deployments
stop_active_deployments() {
    log_info "Stopping active deployments..."
    
    local app_name="lambda-app-$ENVIRONMENT"
    
    # Get active deployments
    ACTIVE_DEPLOYMENTS=$(aws deploy list-deployments \
        --application-name "$app_name" \
        --deployment-group-name "lambda-deployment-group" \
        --include-only-statuses "InProgress" "Queued" "Ready" \
        --region "$AWS_REGION" \
        --output text --query 'deployments' 2>/dev/null || echo "")
    
    if [ -n "$ACTIVE_DEPLOYMENTS" ]; then
        for deployment_id in $ACTIVE_DEPLOYMENTS; do
            log_info "Stopping deployment: $deployment_id"
            
            aws deploy stop-deployment \
                --deployment-id "$deployment_id" \
                --auto-rollback-enabled \
                --region "$AWS_REGION" || true
        done
        
        # Wait a moment for deployments to stop
        sleep 10
    else
        log_info "No active deployments to stop"
    fi
}

# Function to perform rollback
perform_rollback() {
    log_info "Performing rollback to version $TARGET_VERSION..."
    
    # Update alias to target version
    ROLLBACK_RESULT=$(aws lambda update-alias \
        --function-name "$FUNCTION_NAME" \
        --name "live" \
        --function-version "$TARGET_VERSION" \
        --description "Rollback from version $CURRENT_LIVE_VERSION to $TARGET_VERSION on $(date -u +"%Y-%m-%d %H:%M:%S UTC")" \
        --region "$AWS_REGION" \
        --output json)
    
    if [ $? -ne 0 ]; then
        log_error "Failed to update alias for rollback"
        exit 1
    fi
    
    # Verify rollback
    NEW_LIVE_VERSION=$(echo "$ROLLBACK_RESULT" | jq -r '.FunctionVersion')
    
    if [ "$NEW_LIVE_VERSION" = "$TARGET_VERSION" ]; then
        log_info "Rollback completed successfully"
        log_info "Live alias now points to version: $NEW_LIVE_VERSION"
    else
        log_error "Rollback verification failed"
        exit 1
    fi
    
    export ROLLBACK_SUCCESS="true"
}

# Function to verify rollback
verify_rollback() {
    log_info "Verifying rollback..."
    
    # Wait a moment for changes to propagate
    sleep 5
    
    # Get current alias configuration
    CURRENT_ALIAS=$(aws lambda get-alias \
        --function-name "$FUNCTION_NAME" \
        --name "live" \
        --region "$AWS_REGION" \
        --output json)
    
    VERIFIED_VERSION=$(echo "$CURRENT_ALIAS" | jq -r '.FunctionVersion')
    
    if [ "$VERIFIED_VERSION" = "$TARGET_VERSION" ]; then
        log_info "Rollback verification successful"
        
        # Optional: Perform basic health check
        if [ "$ROLLBACK_MODE" != "emergency" ]; then
            log_info "Performing basic health check..."
            
            # Check if function is invokable (dry run)
            if aws lambda invoke \
                --function-name "$FUNCTION_NAME:live" \
                --invocation-type "DryRun" \
                --region "$AWS_REGION" \
                /dev/null > /dev/null 2>&1; then
                log_info "Function is invokable after rollback"
            else
                log_warn "Function may not be invokable after rollback"
            fi
        fi
    else
        log_error "Rollback verification failed - version mismatch"
        exit 1
    fi
}

# Function to generate rollback report
generate_rollback_report() {
    log_info "Generating rollback report..."
    
    cd "$PROJECT_ROOT"
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    cat > "rollback-report.json" << EOF
{
  "functionName": "$FUNCTION_NAME",
  "environment": "$ENVIRONMENT",
  "awsRegion": "$AWS_REGION",
  "timestamp": "$timestamp",
  "rollbackMode": "$ROLLBACK_MODE",
  "forceRollback": $FORCE_ROLLBACK,
  "previousVersion": "$CURRENT_LIVE_VERSION",
  "targetVersion": "$TARGET_VERSION",
  "rollbackSuccess": ${ROLLBACK_SUCCESS:-false},
  "availableVersions": [$(echo "$AVAILABLE_VERSIONS" | tr '\n' ',' | sed 's/,$//' | sed 's/,/", "/g' | sed 's/^/"/' | sed 's/$/"/')],
  "gitCommit": "$(git rev-parse HEAD 2>/dev/null || echo 'unknown')",
  "gitBranch": "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')"
}
EOF
    
    log_info "Rollback report generated: rollback-report.json"
}

# Function to send notifications
send_notifications() {
    log_info "Sending rollback notifications..."
    
    # This is a placeholder for notification logic
    # In a real implementation, you might send notifications via:
    # - SNS
    # - Slack
    # - Email
    # - PagerDuty
    
    local message="Lambda rollback completed for $FUNCTION_NAME in $ENVIRONMENT environment. Rolled back from version $CURRENT_LIVE_VERSION to $TARGET_VERSION."
    
    log_info "Notification message: $message"
    
    # Example SNS notification (uncomment and configure as needed)
    # aws sns publish \
    #     --topic-arn "arn:aws:sns:$AWS_REGION:ACCOUNT:lambda-rollback-notifications" \
    #     --message "$message" \
    #     --region "$AWS_REGION" || true
}

# Main execution
main() {
    log_info "Starting Lambda deployment rollback..."
    
    parse_args "$@"
    check_prerequisites
    get_function_info
    list_available_versions
    determine_target_version
    check_rollback_safety
    confirm_rollback
    stop_active_deployments
    perform_rollback
    verify_rollback
    generate_rollback_report
    send_notifications
    
    log_info "Lambda deployment rollback completed successfully!"
    log_info "Function: $FUNCTION_NAME"
    log_info "Rolled back from version: $CURRENT_LIVE_VERSION"
    log_info "Rolled back to version: $TARGET_VERSION"
    log_info "Report: rollback-report.json"
}

# Execute main function
main "$@"