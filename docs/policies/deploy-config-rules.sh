#!/bin/bash

# Deploy AWS Config Conformance Pack for Lambda Production Readiness
# This script deploys the conformance pack and custom Config rules

set -e

# Configuration
STACK_NAME="lambda-production-config-rules"
REGION=${AWS_DEFAULT_REGION:-us-east-1}
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Deploying Lambda Production Readiness Config Rules..."
echo "Account ID: $ACCOUNT_ID"
echo "Region: $REGION"

# Deploy the conformance pack CloudFormation stack
echo "Deploying conformance pack..."
aws cloudformation deploy \
  --template-file config-conformance-pack-lambda.yaml \
  --stack-name $STACK_NAME \
  --capabilities CAPABILITY_IAM \
  --region $REGION \
  --parameter-overrides \
    DeliveryChannelName=default

# Package and deploy custom Config rule Lambda functions
echo "Packaging custom Config rules..."

# Create deployment package for each custom rule
for rule_file in custom-rules/*.py; do
  rule_name=$(basename "$rule_file" .py)
  echo "Packaging $rule_name..."
  
  # Create temporary directory
  temp_dir=$(mktemp -d)
  cp "$rule_file" "$temp_dir/lambda_function.py"
  
  # Create deployment package
  cd "$temp_dir"
  zip -r "../${rule_name}.zip" .
  cd - > /dev/null
  
  # Deploy the Lambda function
  echo "Deploying $rule_name Lambda function..."
  
  # Check if function exists
  if aws lambda get-function --function-name "$rule_name" --region $REGION >/dev/null 2>&1; then
    # Update existing function
    aws lambda update-function-code \
      --function-name "$rule_name" \
      --zip-file "fileb://${temp_dir}/../${rule_name}.zip" \
      --region $REGION
  else
    # Create new function
    aws lambda create-function \
      --function-name "$rule_name" \
      --runtime python3.11 \
      --role "arn:aws:iam::${ACCOUNT_ID}:role/config-rule-execution-role" \
      --handler lambda_function.lambda_handler \
      --zip-file "fileb://${temp_dir}/../${rule_name}.zip" \
      --timeout 60 \
      --region $REGION \
      --tags Environment=prod,Purpose=config-compliance
  fi
  
  # Grant Config service permission to invoke the function
  aws lambda add-permission \
    --function-name "$rule_name" \
    --statement-id "config-rule-invoke-${rule_name}" \
    --action lambda:InvokeFunction \
    --principal config.amazonaws.com \
    --region $REGION \
    --source-account $ACCOUNT_ID || true
  
  # Clean up
  rm -rf "$temp_dir" "${temp_dir}/../${rule_name}.zip"
done

echo "Config rules deployment completed successfully!"
echo "Stack name: $STACK_NAME"
echo "Custom rules deployed:"
echo "  - lambda-cmk-encryption-check"
echo "  - api-gateway-waf-association-check"
echo "  - lambda-code-signing-check"
echo "  - lambda-concurrency-validation-check"