#!/bin/bash

# Validation script for CI/CD IAM Permission Boundary
# This script tests the effectiveness of the permission boundary policy
# by attempting various actions that should be allowed or denied

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PERMISSION_BOUNDARY_POLICY_NAME="CICDPermissionBoundary"
TEST_ROLE_NAME="test-cicd-role-$(date +%s)"
TEST_FUNCTION_NAME="test-lambda-$(date +%s)"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo -e "${YELLOW}Starting CI/CD Permission Boundary Validation${NC}"
echo "Region: $AWS_REGION"
echo "Test Role: $TEST_ROLE_NAME"
echo "Test Function: $TEST_FUNCTION_NAME"
echo ""

# Function to print test results
print_result() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"
    
    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
    else
        echo -e "${RED}✗ FAIL${NC}: $test_name (Expected: $expected, Got: $actual)"
    fi
}

# Function to test if an action is allowed or denied
test_action() {
    local description="$1"
    local command="$2"
    local expected_result="$3"  # "ALLOW" or "DENY"
    
    echo -n "Testing: $description... "
    
    if eval "$command" >/dev/null 2>&1; then
        actual_result="ALLOW"
    else
        actual_result="DENY"
    fi
    
    print_result "$description" "$expected_result" "$actual_result"
}

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}Cleaning up test resources...${NC}"
    
    # Delete test Lambda function if it exists
    aws lambda delete-function --function-name "$TEST_FUNCTION_NAME" --region "$AWS_REGION" 2>/dev/null || true
    
    # Delete test role if it exists
    aws iam detach-role-policy --role-name "$TEST_ROLE_NAME" --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" 2>/dev/null || true
    aws iam delete-role --role-name "$TEST_ROLE_NAME" 2>/dev/null || true
    
    echo -e "${GREEN}Cleanup completed${NC}"
}

# Set up cleanup trap
trap cleanup EXIT

# Check if permission boundary policy exists
echo -e "${YELLOW}Checking permission boundary policy...${NC}"
if ! aws iam get-policy --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/$PERMISSION_BOUNDARY_POLICY_NAME" >/dev/null 2>&1; then
    echo -e "${RED}Error: Permission boundary policy '$PERMISSION_BOUNDARY_POLICY_NAME' not found${NC}"
    echo "Please deploy the permission boundary policy first"
    exit 1
fi
echo -e "${GREEN}Permission boundary policy found${NC}"

# Create test role with permission boundary
echo -e "\n${YELLOW}Creating test role with permission boundary...${NC}"
TRUST_POLICY='{
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
}'

aws iam create-role \
    --role-name "$TEST_ROLE_NAME" \
    --assume-role-policy-document "$TRUST_POLICY" \
    --permissions-boundary "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/$PERMISSION_BOUNDARY_POLICY_NAME" \
    --tags Key=ManagedBy,Value=CI/CD Key=Environment,Value=dev

# Attach basic execution role policy
aws iam attach-role-policy \
    --role-name "$TEST_ROLE_NAME" \
    --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"

echo -e "${GREEN}Test role created successfully${NC}"

# Wait for role to propagate
echo "Waiting for role propagation..."
sleep 10

# Test 1: Lambda function creation with required tags (should be allowed)
echo -e "\n${YELLOW}Test 1: Lambda function creation with required tags${NC}"
LAMBDA_CODE='{"ZipFile": "def handler(event, context): return {\"statusCode\": 200}"}'
test_action "Create Lambda with required tags" \
    "aws lambda create-function --function-name $TEST_FUNCTION_NAME --runtime python3.9 --role arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/$TEST_ROLE_NAME --handler index.handler --code '$LAMBDA_CODE' --tags ManagedBy=CI/CD,Environment=dev --region $AWS_REGION" \
    "ALLOW"

# Test 2: Lambda function URL creation (should be denied)
echo -e "\n${YELLOW}Test 2: Lambda function URL creation (should be denied)${NC}"
test_action "Create Lambda function URL" \
    "aws lambda create-function-url-config --function-name $TEST_FUNCTION_NAME --auth-type NONE --region $AWS_REGION" \
    "DENY"

# Test 3: Update function code without code signing (should be denied)
echo -e "\n${YELLOW}Test 3: Update function code without code signing${NC}"
test_action "Update function code without signing" \
    "aws lambda update-function-code --function-name $TEST_FUNCTION_NAME --zip-file fileb://<(echo 'def handler(event, context): return {\"statusCode\": 201}' | base64) --region $AWS_REGION" \
    "DENY"

# Test 4: IAM user creation (should be denied)
echo -e "\n${YELLOW}Test 4: IAM user creation (should be denied)${NC}"
test_action "Create IAM user" \
    "aws iam create-user --user-name test-user-$(date +%s)" \
    "DENY"

# Test 5: Lambda function creation without required tags (should be denied)
echo -e "\n${YELLOW}Test 5: Lambda function creation without required tags${NC}"
test_action "Create Lambda without required tags" \
    "aws lambda create-function --function-name test-lambda-no-tags-$(date +%s) --runtime python3.9 --role arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/$TEST_ROLE_NAME --handler index.handler --code '$LAMBDA_CODE' --region $AWS_REGION" \
    "DENY"

# Test 6: Cross-region access (should be denied for non-allowed regions)
echo -e "\n${YELLOW}Test 6: Cross-region access to non-allowed region${NC}"
test_action "Create Lambda in non-allowed region" \
    "aws lambda create-function --function-name test-lambda-wrong-region-$(date +%s) --runtime python3.9 --role arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/$TEST_ROLE_NAME --handler index.handler --code '$LAMBDA_CODE' --tags ManagedBy=CI/CD,Environment=dev --region ap-south-1" \
    "DENY"

# Test 7: CloudFormation stack operations (should be allowed with proper naming)
echo -e "\n${YELLOW}Test 7: CloudFormation stack operations${NC}"
STACK_TEMPLATE='{
  "AWSTemplateFormatVersion": "2010-09-09",
  "Resources": {
    "DummyParameter": {
      "Type": "AWS::SSM::Parameter",
      "Properties": {
        "Name": "/test/dummy",
        "Type": "String",
        "Value": "test"
      }
    }
  }
}'

test_action "Create CloudFormation stack with proper naming" \
    "aws cloudformation create-stack --stack-name test-dev-stack-$(date +%s) --template-body '$STACK_TEMPLATE' --region $AWS_REGION" \
    "ALLOW"

# Test 8: S3 access to deployment artifacts bucket (should be allowed)
echo -e "\n${YELLOW}Test 8: S3 deployment artifacts access${NC}"
# Note: This test assumes a deployment artifacts bucket exists
# In a real environment, you would test with an actual bucket
echo "Skipping S3 test - requires existing deployment artifacts bucket"

# Test 9: CodeDeploy operations (should be allowed)
echo -e "\n${YELLOW}Test 9: CodeDeploy operations${NC}"
test_action "List CodeDeploy applications" \
    "aws deploy list-applications --region $AWS_REGION" \
    "ALLOW"

# Test 10: High privilege IAM actions (should be denied)
echo -e "\n${YELLOW}Test 10: High privilege IAM actions${NC}"
test_action "Create IAM policy" \
    "aws iam create-policy --policy-name test-policy-$(date +%s) --policy-document '{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":\"s3:GetObject\",\"Resource\":\"*\"}]}'" \
    "DENY"

echo -e "\n${YELLOW}Validation completed!${NC}"
echo -e "${GREEN}All tests have been executed. Review the results above.${NC}"
echo -e "${YELLOW}Note: Some tests may show unexpected results in sandbox environments.${NC}"
echo -e "${YELLOW}For production validation, ensure all DENY tests actually fail and ALLOW tests succeed.${NC}"