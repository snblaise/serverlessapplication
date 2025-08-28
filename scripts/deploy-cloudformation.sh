#!/bin/bash

# CloudFormation Deployment Script
# Deploy Lambda infrastructure using CloudFormation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Function to show usage
show_usage() {
    echo "Usage: $0 <environment> [options]"
    echo ""
    echo "Arguments:"
    echo "  environment    Environment to deploy (staging|production)"
    echo ""
    echo "Options:"
    echo "  --validate     Only validate the template"
    echo "  --dry-run      Show what would be deployed without deploying"
    echo "  --force        Force deployment even if no changes detected"
    echo "  --help         Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 staging"
    echo "  $0 production --validate"
    echo "  $0 staging --dry-run"
}

# Parse command line arguments
ENVIRONMENT=""
VALIDATE_ONLY=false
DRY_RUN=false
FORCE_DEPLOY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        staging|production)
            ENVIRONMENT="$1"
            shift
            ;;
        --validate)
            VALIDATE_ONLY=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE_DEPLOY=true
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate environment parameter
if [[ -z "$ENVIRONMENT" ]]; then
    print_error "Environment parameter is required"
    show_usage
    exit 1
fi

if [[ "$ENVIRONMENT" != "staging" && "$ENVIRONMENT" != "production" ]]; then
    print_error "Environment must be 'staging' or 'production'"
    exit 1
fi

# Set variables
STACK_NAME="lambda-infrastructure-${ENVIRONMENT}"
TEMPLATE_FILE="cloudformation/lambda-infrastructure.yml"
PARAMETERS_FILE="cloudformation/parameters/${ENVIRONMENT}.json"
AWS_REGION=$(aws configure get region || echo "us-east-1")

print_status "CloudFormation Deployment for ${ENVIRONMENT} environment"
print_status "Stack Name: ${STACK_NAME}"
print_status "Template: ${TEMPLATE_FILE}"
print_status "Parameters: ${PARAMETERS_FILE}"
print_status "Region: ${AWS_REGION}"
echo ""

# Check if AWS CLI is configured
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed"
    exit 1
fi

if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS CLI is not configured or credentials are invalid"
    exit 1
fi

# Check if template file exists
if [[ ! -f "$TEMPLATE_FILE" ]]; then
    print_error "Template file not found: $TEMPLATE_FILE"
    exit 1
fi

# Check if parameters file exists
if [[ ! -f "$PARAMETERS_FILE" ]]; then
    print_error "Parameters file not found: $PARAMETERS_FILE"
    exit 1
fi

# Validate CloudFormation template
print_status "Validating CloudFormation template..."
if aws cloudformation validate-template --template-body file://"$TEMPLATE_FILE" > /dev/null; then
    print_success "Template validation passed"
else
    print_error "Template validation failed"
    exit 1
fi

# If validate only, exit here
if [[ "$VALIDATE_ONLY" == true ]]; then
    print_success "Template validation completed successfully"
    exit 0
fi

# Check if stack exists
STACK_EXISTS=false
if aws cloudformation describe-stacks --stack-name "$STACK_NAME" &> /dev/null; then
    STACK_EXISTS=true
    print_status "Stack exists - will update"
else
    print_status "Stack does not exist - will create"
fi

# Prepare deployment command
if [[ "$STACK_EXISTS" == true ]]; then
    DEPLOY_COMMAND="aws cloudformation update-stack"
    ACTION="update"
else
    DEPLOY_COMMAND="aws cloudformation create-stack"
    ACTION="create"
fi

DEPLOY_COMMAND="$DEPLOY_COMMAND --stack-name $STACK_NAME"
DEPLOY_COMMAND="$DEPLOY_COMMAND --template-body file://$TEMPLATE_FILE"
DEPLOY_COMMAND="$DEPLOY_COMMAND --parameters file://$PARAMETERS_FILE"
DEPLOY_COMMAND="$DEPLOY_COMMAND --capabilities CAPABILITY_NAMED_IAM"
DEPLOY_COMMAND="$DEPLOY_COMMAND --tags Key=Environment,Value=$ENVIRONMENT Key=Project,Value=lambda-production-readiness Key=ManagedBy,Value=cloudformation"

# Show what would be deployed (dry run)
if [[ "$DRY_RUN" == true ]]; then
    print_status "DRY RUN - Would execute:"
    echo "$DEPLOY_COMMAND"
    echo ""
    
    # Show change set for updates
    if [[ "$STACK_EXISTS" == true ]]; then
        print_status "Creating change set to preview changes..."
        CHANGE_SET_NAME="preview-$(date +%s)"
        
        aws cloudformation create-change-set \
            --stack-name "$STACK_NAME" \
            --template-body file://"$TEMPLATE_FILE" \
            --parameters file://"$PARAMETERS_FILE" \
            --capabilities CAPABILITY_NAMED_IAM \
            --change-set-name "$CHANGE_SET_NAME" > /dev/null
        
        print_status "Waiting for change set to be created..."
        aws cloudformation wait change-set-create-complete \
            --stack-name "$STACK_NAME" \
            --change-set-name "$CHANGE_SET_NAME"
        
        print_status "Change set preview:"
        aws cloudformation describe-change-set \
            --stack-name "$STACK_NAME" \
            --change-set-name "$CHANGE_SET_NAME" \
            --query 'Changes[*].[Action,ResourceChange.LogicalResourceId,ResourceChange.ResourceType]' \
            --output table
        
        # Clean up change set
        aws cloudformation delete-change-set \
            --stack-name "$STACK_NAME" \
            --change-set-name "$CHANGE_SET_NAME" > /dev/null
    fi
    
    print_success "Dry run completed"
    exit 0
fi

# Confirm deployment
if [[ "$FORCE_DEPLOY" != true ]]; then
    echo ""
    print_warning "This will ${ACTION} the CloudFormation stack: $STACK_NAME"
    echo "Do you want to continue? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        print_status "Deployment cancelled by user"
        exit 0
    fi
fi

# Execute deployment
print_status "Starting CloudFormation stack ${ACTION}..."
echo ""

if eval "$DEPLOY_COMMAND"; then
    print_success "CloudFormation ${ACTION} initiated successfully"
else
    print_error "Failed to initiate CloudFormation ${ACTION}"
    exit 1
fi

# Wait for deployment to complete
print_status "Waiting for stack ${ACTION} to complete..."
if [[ "$ACTION" == "create" ]]; then
    aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME"
    WAIT_RESULT=$?
else
    aws cloudformation wait stack-update-complete --stack-name "$STACK_NAME"
    WAIT_RESULT=$?
fi

if [[ $WAIT_RESULT -eq 0 ]]; then
    print_success "Stack ${ACTION} completed successfully!"
else
    print_error "Stack ${ACTION} failed or timed out"
    
    # Show stack events for debugging
    print_status "Recent stack events:"
    aws cloudformation describe-stack-events \
        --stack-name "$STACK_NAME" \
        --query 'StackEvents[0:10].[Timestamp,LogicalResourceId,ResourceStatus,ResourceStatusReason]' \
        --output table
    exit 1
fi

# Display stack outputs
print_status "Stack outputs:"
aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
    --output table

echo ""
print_success "CloudFormation deployment completed successfully! 🎉"
echo ""
print_status "Stack Name: $STACK_NAME"
print_status "Environment: $ENVIRONMENT"
print_status "Region: $AWS_REGION"
echo ""
print_status "Next steps:"
echo "1. Update your GitHub Actions workflow to use CloudFormation"
echo "2. Test the deployed Lambda function"
echo "3. Monitor CloudWatch alarms and logs"