#!/bin/bash

# AWS Resources Setup Script for GitHub Actions
# This script creates the basic AWS resources needed for the GitHub Actions workflow

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

# Create S3 bucket for artifacts
create_s3_bucket() {
    log_step "Creating S3 bucket for deployment artifacts..."
    
    local bucket_name="lambda-artifacts-${ENVIRONMENT}-$(date +%s)"
    
    if aws s3 mb "s3://${bucket_name}" --region "$REGION" >/dev/null 2>&1; then
        log_info "Created S3 bucket: $bucket_name"
        
        # Enable versioning
        aws s3api put-bucket-versioning \
            --bucket "$bucket_name" \
            --versioning-configuration Status=Enabled
        
        # Set up lifecycle policy
        cat > /tmp/lifecycle-policy.json << EOF
{
    "Rules": [
        {
            "ID": "DeleteOldVersions",
            "Status": "Enabled",
            "Filter": {
                "Prefix": ""
            },
            "NoncurrentVersionExpiration": {
                "NoncurrentDays": 30
            }
        }
    ]
}
EOF
        
        aws s3api put-bucket-lifecycle-configuration \
            --bucket "$bucket_name" \
            --lifecycle-configuration file:///tmp/lifecycle-policy.json
        
        echo "S3_BUCKET=$bucket_name"
    else
        log_error "Failed to create S3 bucket"
        exit 1
    fi
}

# Create IAM role for Lambda execution
create_lambda_execution_role() {
    log_step "Creating Lambda execution role..."
    
    local role_name="${FUNCTION_NAME}-execution-role"
    
    # Trust policy
    cat > /tmp/lambda-trust-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
    
    if aws iam create-role \
        --role-name "$role_name" \
        --assume-role-policy-document file:///tmp/lambda-trust-policy.json \
        --description "Execution role for $FUNCTION_NAME" >/dev/null 2>&1; then
        
        log_info "Created Lambda execution role: $role_name"
        
        # Attach basic execution policy
        aws iam attach-role-policy \
            --role-name "$role_name" \
            --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
        
        # Attach X-Ray policy
        aws iam attach-role-policy \
            --role-name "$role_name" \
            --policy-arn "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
        
        local account_id=$(aws sts get-caller-identity --query Account --output text)
        echo "LAMBDA_EXECUTION_ROLE_ARN=arn:aws:iam::${account_id}:role/${role_name}"
    else
        log_warn "Lambda execution role may already exist"
    fi
}

# Create IAM role for CodeDeploy
create_codedeploy_role() {
    log_step "Creating CodeDeploy service role..."
    
    local role_name="CodeDeployServiceRole-${ENVIRONMENT}"
    
    # Trust policy
    cat > /tmp/codedeploy-trust-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "codedeploy.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
    
    if aws iam create-role \
        --role-name "$role_name" \
        --assume-role-policy-document file:///tmp/codedeploy-trust-policy.json \
        --description "CodeDeploy service role for $ENVIRONMENT" >/dev/null 2>&1; then
        
        log_info "Created CodeDeploy service role: $role_name"
        
        # Attach CodeDeploy policy
        aws iam attach-role-policy \
            --role-name "$role_name" \
            --policy-arn "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRoleForLambda"
        
        local account_id=$(aws sts get-caller-identity --query Account --output text)
        echo "CODEDEPLOY_SERVICE_ROLE_ARN=arn:aws:iam::${account_id}:role/${role_name}"
    else
        log_warn "CodeDeploy service role may already exist"
    fi
}

# Create Lambda function
create_lambda_function() {
    log_step "Creating Lambda function..."
    
    # Create a simple initial function
    cat > /tmp/initial-function.js << 'EOF'
exports.handler = async (event) => {
    console.log('Event:', JSON.stringify(event, null, 2));
    return {
        statusCode: 200,
        body: JSON.stringify({
            message: 'Hello from Lambda!',
            timestamp: new Date().toISOString()
        })
    };
};
EOF
    
    # Create zip file
    cd /tmp
    zip initial-function.zip initial-function.js
    cd - >/dev/null
    
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    local role_arn="arn:aws:iam::${account_id}:role/${FUNCTION_NAME}-execution-role"
    
    if aws lambda create-function \
        --function-name "$FUNCTION_NAME" \
        --runtime nodejs18.x \
        --role "$role_arn" \
        --handler initial-function.handler \
        --zip-file fileb:///tmp/initial-function.zip \
        --timeout 30 \
        --memory-size 256 \
        --description "Lambda function for $ENVIRONMENT environment" >/dev/null 2>&1; then
        
        log_info "Created Lambda function: $FUNCTION_NAME"
        
        # Create live alias
        aws lambda create-alias \
            --function-name "$FUNCTION_NAME" \
            --name live \
            --function-version '$LATEST' >/dev/null 2>&1
        
        log_info "Created live alias for $FUNCTION_NAME"
        
        echo "LAMBDA_FUNCTION_NAME=$FUNCTION_NAME"
    else
        log_warn "Lambda function may already exist"
    fi
}

# Create CodeDeploy application
create_codedeploy_application() {
    log_step "Creating CodeDeploy application..."
    
    if aws deploy create-application \
        --application-name "$APP_NAME" \
        --compute-platform Lambda >/dev/null 2>&1; then
        
        log_info "Created CodeDeploy application: $APP_NAME"
        
        # Create deployment group
        local account_id=$(aws sts get-caller-identity --query Account --output text)
        local service_role_arn="arn:aws:iam::${account_id}:role/CodeDeployServiceRole-${ENVIRONMENT}"
        
        aws deploy create-deployment-group \
            --application-name "$APP_NAME" \
            --deployment-group-name "lambda-deployment-group" \
            --service-role-arn "$service_role_arn" \
            --deployment-config-name "CodeDeployDefault.Lambda10PercentEvery5Minutes" >/dev/null 2>&1
        
        log_info "Created deployment group for $APP_NAME"
        
        echo "CODEDEPLOY_APPLICATION_NAME=$APP_NAME"
    else
        log_warn "CodeDeploy application may already exist"
    fi
}

# Create CloudWatch alarms
create_cloudwatch_alarms() {
    log_step "Creating CloudWatch alarms..."
    
    # Error rate alarm
    aws cloudwatch put-metric-alarm \
        --alarm-name "lambda-error-rate-${ENVIRONMENT}" \
        --alarm-description "Lambda error rate too high" \
        --metric-name Errors \
        --namespace AWS/Lambda \
        --statistic Sum \
        --period 300 \
        --threshold 5 \
        --comparison-operator GreaterThanThreshold \
        --dimensions Name=FunctionName,Value="$FUNCTION_NAME" \
        --evaluation-periods 2 >/dev/null 2>&1
    
    # Duration alarm
    aws cloudwatch put-metric-alarm \
        --alarm-name "lambda-duration-${ENVIRONMENT}" \
        --alarm-description "Lambda duration too high" \
        --metric-name Duration \
        --namespace AWS/Lambda \
        --statistic Average \
        --period 300 \
        --threshold 10000 \
        --comparison-operator GreaterThanThreshold \
        --dimensions Name=FunctionName,Value="$FUNCTION_NAME" \
        --evaluation-periods 2 >/dev/null 2>&1
    
    # Throttle alarm
    aws cloudwatch put-metric-alarm \
        --alarm-name "lambda-throttle-${ENVIRONMENT}" \
        --alarm-description "Lambda throttles detected" \
        --metric-name Throttles \
        --namespace AWS/Lambda \
        --statistic Sum \
        --period 300 \
        --threshold 1 \
        --comparison-operator GreaterThanOrEqualToThreshold \
        --dimensions Name=FunctionName,Value="$FUNCTION_NAME" \
        --evaluation-periods 1 >/dev/null 2>&1
    
    log_info "Created CloudWatch alarms for monitoring"
}

# Main execution
main() {
    echo ""
    log_info "🏗️  Setting up AWS resources for GitHub Actions deployment"
    log_info "Environment: $ENVIRONMENT"
    log_info "Region: $REGION"
    echo ""
    
    check_aws_cli
    
    echo ""
    log_info "📝 Creating AWS resources..."
    echo ""
    
    create_s3_bucket
    create_lambda_execution_role
    create_codedeploy_role
    
    # Wait for roles to propagate
    log_info "Waiting for IAM roles to propagate..."
    sleep 10
    
    create_lambda_function
    create_codedeploy_application
    create_cloudwatch_alarms
    
    echo ""
    log_info "✅ AWS resources setup completed!"
    echo ""
    log_info "📋 Summary of created resources:"
    echo "   - S3 bucket for deployment artifacts"
    echo "   - Lambda function: $FUNCTION_NAME"
    echo "   - CodeDeploy application: $APP_NAME"
    echo "   - IAM roles for Lambda and CodeDeploy"
    echo "   - CloudWatch alarms for monitoring"
    echo ""
    log_info "🚀 You can now run your GitHub Actions workflow!"
    echo ""
    
    # Clean up temp files
    rm -f /tmp/initial-function.js /tmp/initial-function.zip
    rm -f /tmp/lambda-trust-policy.json /tmp/codedeploy-trust-policy.json
    rm -f /tmp/lifecycle-policy.json
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
    echo "  $0                    # Create staging resources in us-east-1"
    echo "  $0 production         # Create production resources in us-east-1"
    echo "  $0 staging us-west-2  # Create staging resources in us-west-2"
    exit 0
fi

# Run main function
main "$@"