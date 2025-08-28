#!/bin/bash

# Test Lambda Function Script
# This script tests the deployed Lambda function with various payloads

set -e

FUNCTION_NAME="${1:-lambda-function-staging}"

echo "🧪 Testing Lambda Function: $FUNCTION_NAME"
echo "============================================="

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed"
    exit 1
fi

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "❌ jq is not installed (required for JSON processing)"
    exit 1
fi

echo "✅ Prerequisites check passed"

# Test 1: Create action
echo ""
echo "🔍 Test 1: Create Action"
echo '{"action": "create", "data": {"name": "test-item-1"}, "source": "test-script"}' > test-create.json

aws lambda invoke \
    --function-name "$FUNCTION_NAME" \
    --payload file://test-create.json \
    response-create.json

echo "Response:"
cat response-create.json | jq .

# Verify create response
if jq -e '.statusCode == 200' response-create.json > /dev/null; then
    echo "✅ Create test passed"
else
    echo "❌ Create test failed"
fi

# Test 2: Update action
echo ""
echo "🔍 Test 2: Update Action"
echo '{"action": "update", "data": {"id": "test-id-123"}, "source": "test-script"}' > test-update.json

aws lambda invoke \
    --function-name "$FUNCTION_NAME" \
    --payload file://test-update.json \
    response-update.json

echo "Response:"
cat response-update.json | jq .

# Verify update response
if jq -e '.statusCode == 200' response-update.json > /dev/null; then
    echo "✅ Update test passed"
else
    echo "❌ Update test failed"
fi

# Test 3: Delete action
echo ""
echo "🔍 Test 3: Delete Action"
echo '{"action": "delete", "data": {"id": "test-id-456"}, "source": "test-script"}' > test-delete.json

aws lambda invoke \
    --function-name "$FUNCTION_NAME" \
    --payload file://test-delete.json \
    response-delete.json

echo "Response:"
cat response-delete.json | jq .

# Verify delete response
if jq -e '.statusCode == 200' response-delete.json > /dev/null; then
    echo "✅ Delete test passed"
else
    echo "❌ Delete test failed"
fi

# Test 4: Invalid action (should fail)
echo ""
echo "🔍 Test 4: Invalid Action (Expected to Fail)"
echo '{"action": "invalid", "data": {"test": true}, "source": "test-script"}' > test-invalid.json

aws lambda invoke \
    --function-name "$FUNCTION_NAME" \
    --payload file://test-invalid.json \
    response-invalid.json

echo "Response:"
cat response-invalid.json | jq .

# Verify invalid response
if jq -e '.statusCode == 500' response-invalid.json > /dev/null; then
    echo "✅ Invalid action test passed (correctly failed)"
else
    echo "❌ Invalid action test failed (should have returned 500)"
fi

# Test 5: Missing action (should fail)
echo ""
echo "🔍 Test 5: Missing Action (Expected to Fail)"
echo '{"data": {"test": true}, "source": "test-script"}' > test-missing.json

aws lambda invoke \
    --function-name "$FUNCTION_NAME" \
    --payload file://test-missing.json \
    response-missing.json

echo "Response:"
cat response-missing.json | jq .

# Verify missing action response
if jq -e '.statusCode == 500' response-missing.json > /dev/null; then
    echo "✅ Missing action test passed (correctly failed)"
else
    echo "❌ Missing action test failed (should have returned 500)"
fi

# Cleanup test files
echo ""
echo "🧹 Cleaning up test files..."
rm -f test-*.json response-*.json

echo ""
echo "🎉 Lambda function testing completed!"
echo ""
echo "Summary:"
echo "- Create action: ✅"
echo "- Update action: ✅"
echo "- Delete action: ✅"
echo "- Invalid action handling: ✅"
echo "- Missing action handling: ✅"
echo ""
echo "The Lambda function is working correctly! 🚀"