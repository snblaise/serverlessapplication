# Secret Rotation and Runtime Upgrade Runbook

## Overview

This runbook provides comprehensive procedures for AWS Secrets Manager rotation, Lambda runtime upgrades, and environment variable updates using alias-targeted versions to ensure zero-downtime deployments and maintain security best practices.

## Secret Rotation Procedures

### Pre-Rotation Planning

1. **Inventory Secret Dependencies**
   ```bash
   # List all Lambda functions using the secret
   aws lambda list-functions --query 'Functions[?Environment.Variables.SECRET_ARN==`<secret-arn>`]'
   
   # Check which functions reference the secret in code
   grep -r "GetSecretValue" . --include="*.py" --include="*.js" --include="*.java"
   ```

2. **Identify Rotation Strategy**
   - **Database Credentials**: Use AWS RDS/Aurora automatic rotation
   - **API Keys**: Manual rotation with validation
   - **Certificates**: Coordinate with certificate renewal
   - **Custom Secrets**: Implement custom rotation logic

### Automated Secret Rotation (RDS/Aurora)

3. **Enable Automatic Rotation**
   ```bash
   # Enable rotation for RDS credentials
   aws secretsmanager rotate-secret \
     --secret-id <secret-arn> \
     --rotation-lambda-arn <rotation-lambda-arn> \
     --rotation-rules AutomaticallyAfterDays=30
   ```

4. **Monitor Rotation Status**
   ```bash
   # Check rotation status
   aws secretsmanager describe-secret --secret-id <secret-arn> \
     --query 'RotationEnabled,RotationLambdaARN,RotationRules'
   
   # Get rotation history
   aws secretsmanager list-secret-version-ids --secret-id <secret-arn>
   ```

### Manual Secret Rotation with Canary Deployment

5. **Create New Secret Version**
   ```bash
   # Update secret with new value
   aws secretsmanager update-secret \
     --secret-id <secret-arn> \
     --secret-string '{"username":"user","password":"new-password"}'
   ```

6. **Deploy Lambda Function Update**
   ```bash
   # Create new Lambda version with updated secret reference
   aws lambda publish-version \
     --function-name <function-name> \
     --description "Updated for secret rotation $(date)"
   ```

7. **Canary Deployment with Secret Validation**
   ```python
   # Lambda function code to validate secret access
   import boto3
   import json
   import os
   
   def validate_secret_access():
       """Validate that the function can access the rotated secret"""
       secrets_client = boto3.client('secretsmanager')
       secret_arn = os.environ['SECRET_ARN']
       
       try:
           response = secrets_client.get_secret_value(SecretId=secret_arn)
           secret_data = json.loads(response['SecretString'])
           
           # Test connection with new credentials
           # Add your specific validation logic here
           # e.g., database connection test, API call test
           
           return {
               'statusCode': 200,
               'body': json.dumps({
                   'message': 'Secret validation successful',
                   'version_id': response['VersionId']
               })
           }
       except Exception as e:
           return {
               'statusCode': 500,
               'body': json.dumps({
                   'error': str(e),
                   'message': 'Secret validation failed'
               })
           }
   
   def lambda_handler(event, context):
       # Your main function logic here
       validation_result = validate_secret_access()
       
       if validation_result['statusCode'] != 200:
           raise Exception("Secret validation failed")
       
       # Continue with normal processing
       return process_request(event)
   ```

8. **Gradual Traffic Shift**
   ```bash
   # Start with 10% traffic to new version
   aws lambda update-alias \
     --function-name <function-name> \
     --name LIVE \
     --function-version <new-version> \
     --routing-config AdditionalVersionWeights='{
       "<new-version>": 0.1
     }'
   
   # Monitor for 15 minutes, then increase to 50%
   aws lambda update-alias \
     --function-name <function-name> \
     --name LIVE \
     --function-version <new-version> \
     --routing-config AdditionalVersionWeights='{
       "<new-version>": 0.5
     }'
   
   # If successful, complete the shift
   aws lambda update-alias \
     --function-name <function-name> \
     --name LIVE \
     --function-version <new-version>
   ```

### Secret Rotation Validation

9. **Test Secret Connectivity**
   ```python
   # Validation script for different secret types
   import boto3
   import json
   import psycopg2
   import requests
   from datetime import datetime
   
   def validate_database_secret(secret_arn):
       """Validate database credentials"""
       secrets_client = boto3.client('secretsmanager')
       
       try:
           response = secrets_client.get_secret_value(SecretId=secret_arn)
           creds = json.loads(response['SecretString'])
           
           # Test database connection
           conn = psycopg2.connect(
               host=creds['host'],
               database=creds['dbname'],
               user=creds['username'],
               password=creds['password'],
               port=creds['port']
           )
           
           cursor = conn.cursor()
           cursor.execute('SELECT 1')
           result = cursor.fetchone()
           
           conn.close()
           return True, "Database connection successful"
           
       except Exception as e:
           return False, f"Database connection failed: {str(e)}"
   
   def validate_api_key_secret(secret_arn, test_endpoint):
       """Validate API key credentials"""
       secrets_client = boto3.client('secretsmanager')
       
       try:
           response = secrets_client.get_secret_value(SecretId=secret_arn)
           secret_data = json.loads(response['SecretString'])
           
           # Test API call
           headers = {'Authorization': f"Bearer {secret_data['api_key']}"}
           response = requests.get(test_endpoint, headers=headers, timeout=10)
           
           if response.status_code == 200:
               return True, "API key validation successful"
           else:
               return False, f"API returned status {response.status_code}"
               
       except Exception as e:
           return False, f"API key validation failed: {str(e)}"
   
   def run_validation_suite():
       """Run complete validation suite"""
       validations = [
           ('database', 'arn:aws:secretsmanager:region:account:secret:db-creds'),
           ('api', 'arn:aws:secretsmanager:region:account:secret:api-key')
       ]
       
       results = []
       for validation_type, secret_arn in validations:
           if validation_type == 'database':
               success, message = validate_database_secret(secret_arn)
           elif validation_type == 'api':
               success, message = validate_api_key_secret(secret_arn, 'https://api.example.com/health')
           
           results.append({
               'type': validation_type,
               'secret_arn': secret_arn,
               'success': success,
               'message': message,
               'timestamp': datetime.utcnow().isoformat()
           })
       
       return results
   ```

## Lambda Runtime Upgrade Procedures

### Pre-Upgrade Assessment

1. **Inventory Current Runtime Versions**
   ```bash
   # List all Lambda functions and their runtimes
   aws lambda list-functions \
     --query 'Functions[*].[FunctionName,Runtime,LastModified]' \
     --output table
   
   # Filter functions by specific runtime
   aws lambda list-functions \
     --query 'Functions[?Runtime==`python3.8`].[FunctionName,Runtime]' \
     --output table
   ```

2. **Check Runtime Deprecation Timeline**
   ```bash
   # Check AWS documentation for runtime deprecation dates
   # Prioritize functions using deprecated runtimes
   ```

3. **Analyze Function Dependencies**
   ```bash
   # Check package.json, requirements.txt, or other dependency files
   # Identify potential compatibility issues with new runtime
   
   # For Python functions
   find . -name "requirements.txt" -exec echo "=== {} ===" \; -exec cat {} \;
   
   # For Node.js functions
   find . -name "package.json" -exec echo "=== {} ===" \; -exec cat {} \;
   ```

### Staging Environment Testing

4. **Create Test Environment**
   ```bash
   # Deploy function to staging with new runtime
   aws lambda create-function \
     --function-name <function-name>-staging \
     --runtime python3.11 \
     --role <execution-role-arn> \
     --handler lambda_function.lambda_handler \
     --zip-file fileb://function.zip \
     --environment Variables='{
       "ENVIRONMENT": "staging",
       "SECRET_ARN": "<staging-secret-arn>"
     }'
   ```

5. **Run Compatibility Tests**
   ```python
   # Automated testing script for runtime compatibility
   import boto3
   import json
   import time
   from concurrent.futures import ThreadPoolExecutor
   
   def test_function_compatibility(function_name, test_events):
       """Test Lambda function with various event types"""
       lambda_client = boto3.client('lambda')
       results = []
       
       for event_name, event_payload in test_events.items():
           try:
               response = lambda_client.invoke(
                   FunctionName=function_name,
                   InvocationType='RequestResponse',
                   Payload=json.dumps(event_payload)
               )
               
               status_code = response['StatusCode']
               payload = json.loads(response['Payload'].read())
               
               results.append({
                   'event_type': event_name,
                   'status_code': status_code,
                   'success': status_code == 200,
                   'duration': response.get('Duration', 0),
                   'memory_used': response.get('MemoryUsed', 0),
                   'error': payload.get('errorMessage') if status_code != 200 else None
               })
               
           except Exception as e:
               results.append({
                   'event_type': event_name,
                   'success': False,
                   'error': str(e)
               })
       
       return results
   
   def run_load_test(function_name, concurrent_requests=10, duration_seconds=60):
       """Run load test against the function"""
       lambda_client = boto3.client('lambda')
       
       def invoke_function():
           try:
               response = lambda_client.invoke(
                   FunctionName=function_name,
                   InvocationType='RequestResponse',
                   Payload=json.dumps({'test': 'load_test'})
               )
               return response['StatusCode'] == 200
           except:
               return False
       
       start_time = time.time()
       successful_invocations = 0
       total_invocations = 0
       
       with ThreadPoolExecutor(max_workers=concurrent_requests) as executor:
           while time.time() - start_time < duration_seconds:
               futures = [executor.submit(invoke_function) for _ in range(concurrent_requests)]
               
               for future in futures:
                   total_invocations += 1
                   if future.result():
                       successful_invocations += 1
               
               time.sleep(1)
       
       success_rate = (successful_invocations / total_invocations) * 100
       return {
           'total_invocations': total_invocations,
           'successful_invocations': successful_invocations,
           'success_rate': success_rate
       }
   ```

### Production Runtime Upgrade

6. **Create New Function Version**
   ```bash
   # Update function configuration with new runtime
   aws lambda update-function-configuration \
     --function-name <function-name> \
     --runtime python3.11
   
   # Publish new version
   NEW_VERSION=$(aws lambda publish-version \
     --function-name <function-name> \
     --description "Runtime upgrade to python3.11 $(date)" \
     --query 'Version' --output text)
   
   echo "New version: $NEW_VERSION"
   ```

7. **Canary Deployment for Runtime Upgrade**
   ```bash
   # Get current production version
   CURRENT_VERSION=$(aws lambda get-alias \
     --function-name <function-name> \
     --name LIVE \
     --query 'FunctionVersion' --output text)
   
   # Start with 5% traffic to new runtime version
   aws lambda update-alias \
     --function-name <function-name> \
     --name LIVE \
     --function-version $CURRENT_VERSION \
     --routing-config AdditionalVersionWeights="{
       \"$NEW_VERSION\": 0.05
     }"
   
   echo "Started canary deployment: 5% traffic to version $NEW_VERSION"
   ```

8. **Monitor Runtime Upgrade**
   ```bash
   # Monitor key metrics during upgrade
   watch -n 30 'echo "=== Error Rate ===" && \
   aws cloudwatch get-metric-statistics \
     --namespace AWS/Lambda \
     --metric-name Errors \
     --dimensions Name=FunctionName,Value=<function-name> \
     --start-time $(date -d "10 minutes ago" --iso-8601) \
     --end-time $(date --iso-8601) \
     --period 300 \
     --statistics Sum && \
   echo "=== Duration ===" && \
   aws cloudwatch get-metric-statistics \
     --namespace AWS/Lambda \
     --metric-name Duration \
     --dimensions Name=FunctionName,Value=<function-name> \
     --start-time $(date -d "10 minutes ago" --iso-8601) \
     --end-time $(date --iso-8601) \
     --period 300 \
     --statistics Average'
   ```

9. **Gradual Traffic Increase**
   ```bash
   # If 5% looks good after 30 minutes, increase to 25%
   aws lambda update-alias \
     --function-name <function-name> \
     --name LIVE \
     --function-version $CURRENT_VERSION \
     --routing-config AdditionalVersionWeights="{
       \"$NEW_VERSION\": 0.25
     }"
   
   # After another 30 minutes, increase to 50%
   aws lambda update-alias \
     --function-name <function-name> \
     --name LIVE \
     --function-version $CURRENT_VERSION \
     --routing-config AdditionalVersionWeights="{
       \"$NEW_VERSION\": 0.50
     }"
   
   # Finally, complete the migration
   aws lambda update-alias \
     --function-name <function-name> \
     --name LIVE \
     --function-version $NEW_VERSION
   ```

## Environment Variable Updates

### Alias-Targeted Version Updates

1. **Plan Environment Variable Changes**
   ```bash
   # Document current environment variables
   aws lambda get-function-configuration \
     --function-name <function-name> \
     --query 'Environment.Variables' > current-env-vars.json
   
   # Prepare new environment variables
   cat > new-env-vars.json << EOF
   {
     "DATABASE_URL": "new-database-endpoint",
     "API_ENDPOINT": "https://api-v2.example.com",
     "LOG_LEVEL": "INFO",
     "SECRET_ARN": "arn:aws:secretsmanager:region:account:secret:new-secret"
   }
   EOF
   ```

2. **Create Version with Updated Variables**
   ```bash
   # Update function configuration
   aws lambda update-function-configuration \
     --function-name <function-name> \
     --environment Variables="$(cat new-env-vars.json | jq -c .)"
   
   # Publish new version
   NEW_VERSION=$(aws lambda publish-version \
     --function-name <function-name> \
     --description "Environment variable update $(date)" \
     --query 'Version' --output text)
   ```

3. **Test New Configuration**
   ```python
   # Test script for environment variable changes
   import boto3
   import json
   
   def test_environment_variables(function_name, version):
       """Test function with new environment variables"""
       lambda_client = boto3.client('lambda')
       
       # Test invocation
       test_event = {
           'test_type': 'environment_validation',
           'timestamp': '2024-01-01T00:00:00Z'
       }
       
       try:
           response = lambda_client.invoke(
               FunctionName=f"{function_name}:{version}",
               InvocationType='RequestResponse',
               Payload=json.dumps(test_event)
           )
           
           result = json.loads(response['Payload'].read())
           
           return {
               'success': response['StatusCode'] == 200,
               'result': result,
               'duration': response.get('Duration', 0),
               'memory_used': response.get('MemoryUsed', 0)
           }
           
       except Exception as e:
           return {
               'success': False,
               'error': str(e)
           }
   ```

4. **Gradual Rollout with Alias**
   ```bash
   # Get current alias configuration
   CURRENT_VERSION=$(aws lambda get-alias \
     --function-name <function-name> \
     --name LIVE \
     --query 'FunctionVersion' --output text)
   
   # Start with 10% traffic to new configuration
   aws lambda update-alias \
     --function-name <function-name> \
     --name LIVE \
     --function-version $CURRENT_VERSION \
     --routing-config AdditionalVersionWeights="{
       \"$NEW_VERSION\": 0.10
     }"
   ```

### Rollback Procedures

5. **Automated Rollback Triggers**
   ```python
   # CloudWatch alarm-based rollback automation
   import boto3
   
   def setup_rollback_alarms(function_name, current_version, new_version):
       """Set up CloudWatch alarms for automatic rollback"""
       cloudwatch = boto3.client('cloudwatch')
       lambda_client = boto3.client('lambda')
       
       # Error rate alarm
       cloudwatch.put_metric_alarm(
           AlarmName=f'{function_name}-ErrorRate-Rollback',
           ComparisonOperator='GreaterThanThreshold',
           EvaluationPeriods=2,
           MetricName='Errors',
           Namespace='AWS/Lambda',
           Period=300,
           Statistic='Sum',
           Threshold=10.0,
           ActionsEnabled=True,
           AlarmActions=[
               f'arn:aws:sns:region:account:rollback-topic'
           ],
           AlarmDescription='Trigger rollback on high error rate',
           Dimensions=[
               {
                   'Name': 'FunctionName',
                   'Value': function_name
               }
           ]
       )
       
       # Duration alarm
       cloudwatch.put_metric_alarm(
           AlarmName=f'{function_name}-Duration-Rollback',
           ComparisonOperator='GreaterThanThreshold',
           EvaluationPeriods=3,
           MetricName='Duration',
           Namespace='AWS/Lambda',
           Period=300,
           Statistic='Average',
           Threshold=5000.0,  # 5 seconds
           ActionsEnabled=True,
           AlarmActions=[
               f'arn:aws:sns:region:account:rollback-topic'
           ],
           AlarmDescription='Trigger rollback on high duration',
           Dimensions=[
               {
                   'Name': 'FunctionName',
                   'Value': function_name
               }
           ]
       )
   
   def execute_rollback(function_name, rollback_version):
       """Execute immediate rollback"""
       lambda_client = boto3.client('lambda')
       
       try:
           # Update alias to rollback version
           response = lambda_client.update_alias(
               FunctionName=function_name,
               Name='LIVE',
               FunctionVersion=rollback_version
           )
           
           print(f"Rollback completed: {function_name} -> version {rollback_version}")
           return True
           
       except Exception as e:
           print(f"Rollback failed: {str(e)}")
           return False
   ```

6. **Manual Rollback Process**
   ```bash
   # Emergency rollback to previous version
   ROLLBACK_VERSION="<previous-stable-version>"
   
   aws lambda update-alias \
     --function-name <function-name> \
     --name LIVE \
     --function-version $ROLLBACK_VERSION
   
   echo "Emergency rollback completed to version $ROLLBACK_VERSION"
   
   # Verify rollback
   aws lambda get-alias \
     --function-name <function-name> \
     --name LIVE
   ```

## Monitoring and Validation

### Continuous Monitoring Setup

1. **Key Metrics Dashboard**
   ```json
   {
     "widgets": [
       {
         "type": "metric",
         "properties": {
           "metrics": [
             ["AWS/Lambda", "Errors", "FunctionName", "<function-name>"],
             [".", "Duration", ".", "."],
             [".", "Invocations", ".", "."],
             [".", "Throttles", ".", "."],
             ["AWS/SecretsManager", "SuccessfulRequestLatency", "SecretName", "<secret-name>"]
           ],
           "period": 300,
           "stat": "Average",
           "region": "us-east-1",
           "title": "Function Health During Updates"
         }
       }
     ]
   }
   ```

2. **Automated Health Checks**
   ```python
   # Scheduled health check function
   import boto3
   import json
   from datetime import datetime, timedelta
   
   def lambda_handler(event, context):
       """Automated health check for updated functions"""
       
       functions_to_check = [
           'function-1',
           'function-2',
           'function-3'
       ]
       
       results = []
       
       for function_name in functions_to_check:
           health_result = check_function_health(function_name)
           results.append(health_result)
           
           if not health_result['healthy']:
               send_alert(function_name, health_result)
       
       return {
           'statusCode': 200,
           'body': json.dumps({
               'timestamp': datetime.utcnow().isoformat(),
               'results': results
           })
       }
   
   def check_function_health(function_name):
       """Check individual function health"""
       cloudwatch = boto3.client('cloudwatch')
       
       end_time = datetime.utcnow()
       start_time = end_time - timedelta(minutes=15)
       
       # Check error rate
       error_response = cloudwatch.get_metric_statistics(
           Namespace='AWS/Lambda',
           MetricName='Errors',
           Dimensions=[{'Name': 'FunctionName', 'Value': function_name}],
           StartTime=start_time,
           EndTime=end_time,
           Period=300,
           Statistics=['Sum']
       )
       
       # Check invocation count
       invocation_response = cloudwatch.get_metric_statistics(
           Namespace='AWS/Lambda',
           MetricName='Invocations',
           Dimensions=[{'Name': 'FunctionName', 'Value': function_name}],
           StartTime=start_time,
           EndTime=end_time,
           Period=300,
           Statistics=['Sum']
       )
       
       total_errors = sum([dp['Sum'] for dp in error_response['Datapoints']])
       total_invocations = sum([dp['Sum'] for dp in invocation_response['Datapoints']])
       
       error_rate = (total_errors / total_invocations * 100) if total_invocations > 0 else 0
       
       return {
           'function_name': function_name,
           'healthy': error_rate < 5.0,  # Less than 5% error rate
           'error_rate': error_rate,
           'total_errors': total_errors,
           'total_invocations': total_invocations,
           'timestamp': datetime.utcnow().isoformat()
       }
   ```

## Quick Reference Commands

```bash
# Secret rotation
aws secretsmanager rotate-secret --secret-id <arn>
aws secretsmanager describe-secret --secret-id <arn>
aws secretsmanager get-secret-value --secret-id <arn>

# Lambda version management
aws lambda publish-version --function-name <name> --description "Update $(date)"
aws lambda update-alias --function-name <name> --name LIVE --function-version <version>
aws lambda get-alias --function-name <name> --name LIVE

# Runtime updates
aws lambda update-function-configuration --function-name <name> --runtime python3.11
aws lambda list-functions --query 'Functions[?Runtime==`python3.8`]'

# Environment variables
aws lambda update-function-configuration --function-name <name> --environment Variables='{"KEY":"value"}'
aws lambda get-function-configuration --function-name <name> --query 'Environment.Variables'

# Monitoring
aws cloudwatch get-metric-statistics --namespace AWS/Lambda --metric-name Errors \
  --dimensions Name=FunctionName,Value=<name> --start-time <time> --end-time <time> \
  --period 300 --statistics Sum
```

## Emergency Procedures

### Secret Compromise Response
1. **Immediate Actions**
   - Rotate compromised secret immediately
   - Update all dependent functions
   - Monitor for unauthorized access

2. **Communication**
   - Notify security team
   - Document incident timeline
   - Update security procedures

### Runtime Upgrade Failure
1. **Immediate Rollback**
   - Revert to previous runtime version
   - Restore previous alias configuration
   - Monitor for stability

2. **Investigation**
   - Analyze failure logs
   - Test in staging environment
   - Plan remediation approach