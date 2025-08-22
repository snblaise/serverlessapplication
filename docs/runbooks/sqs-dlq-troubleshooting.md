# SQS/DLQ Troubleshooting Runbook

## Overview

This runbook provides comprehensive procedures for troubleshooting Amazon SQS queues and Dead Letter Queues (DLQ) in Lambda-based serverless architectures, including poisoned message handling, message replay strategies, and queue management.

## Common SQS/DLQ Issues

### Issue Categories
1. **Poisoned Messages** - Messages that consistently fail processing
2. **Queue Backlog** - Messages accumulating faster than processing
3. **DLQ Overflow** - High volume of failed messages
4. **Visibility Timeout Issues** - Messages reappearing too quickly/slowly
5. **Idempotency Failures** - Duplicate processing causing errors

## Poisoned Message Investigation

### Initial Assessment (0-5 minutes)

1. **Check Queue Metrics**
   ```bash
   # Review CloudWatch metrics for the queue
   aws cloudwatch get-metric-statistics \
     --namespace AWS/SQS \
     --metric-name ApproximateNumberOfMessages \
     --dimensions Name=QueueName,Value=<queue-name> \
     --start-time $(date -d '1 hour ago' --iso-8601) \
     --end-time $(date --iso-8601) \
     --period 300 \
     --statistics Average,Maximum
   ```

2. **Identify DLQ Message Pattern**
   ```bash
   # Check DLQ message count
   aws sqs get-queue-attributes \
     --queue-url <dlq-url> \
     --attribute-names ApproximateNumberOfMessages,ApproximateNumberOfMessagesNotVisible
   ```

3. **Sample DLQ Messages**
   ```bash
   # Receive messages from DLQ without deleting (for analysis)
   aws sqs receive-message \
     --queue-url <dlq-url> \
     --max-number-of-messages 10 \
     --message-attribute-names All \
     --attribute-names All
   ```

### Message Analysis (5-15 minutes)

4. **Examine Message Structure**
   ```bash
   # Look for common patterns in failed messages:
   # - Malformed JSON
   # - Missing required fields
   # - Invalid data types
   # - Oversized payloads (>256KB)
   ```

5. **Check Lambda Function Logs**
   ```bash
   # Find specific error patterns for DLQ messages
   aws logs filter-log-events \
     --log-group-name /aws/lambda/<function-name> \
     --filter-pattern "ERROR" \
     --start-time $(date -d '2 hours ago' +%s)000 \
     --end-time $(date +%s)000
   ```

6. **Correlate Message Attributes**
   ```bash
   # Check message attributes for retry count and timestamps
   # Look for SentTimestamp, ApproximateReceiveCount, ApproximateFirstReceiveTimestamp
   ```

## Poisoned Message Isolation

### Immediate Isolation (0-10 minutes)

1. **Create Quarantine Queue**
   ```bash
   # Create temporary quarantine queue for problematic messages
   aws sqs create-queue \
     --queue-name <original-queue-name>-quarantine \
     --attributes '{
       "MessageRetentionPeriod": "1209600",
       "VisibilityTimeoutSeconds": "300"
     }'
   ```

2. **Move Poisoned Messages**
   ```bash
   # Script to move messages from DLQ to quarantine
   #!/bin/bash
   
   DLQ_URL="<dlq-url>"
   QUARANTINE_URL="<quarantine-queue-url>"
   
   while true; do
     # Receive message from DLQ
     MESSAGE=$(aws sqs receive-message \
       --queue-url $DLQ_URL \
       --max-number-of-messages 1 \
       --message-attribute-names All)
     
     if [ -z "$(echo $MESSAGE | jq -r '.Messages')" ] || [ "$(echo $MESSAGE | jq -r '.Messages')" = "null" ]; then
       echo "No more messages in DLQ"
       break
     fi
     
     # Extract message details
     BODY=$(echo $MESSAGE | jq -r '.Messages[0].Body')
     RECEIPT_HANDLE=$(echo $MESSAGE | jq -r '.Messages[0].ReceiptHandle')
     ATTRIBUTES=$(echo $MESSAGE | jq -r '.Messages[0].Attributes')
     
     # Send to quarantine queue
     aws sqs send-message \
       --queue-url $QUARANTINE_URL \
       --message-body "$BODY" \
       --message-attributes "$(echo $MESSAGE | jq -r '.Messages[0].MessageAttributes')"
     
     # Delete from DLQ
     aws sqs delete-message \
       --queue-url $DLQ_URL \
       --receipt-handle "$RECEIPT_HANDLE"
     
     echo "Moved message to quarantine"
   done
   ```

3. **Pause Queue Processing** (if needed)
   ```bash
   # Temporarily disable Lambda trigger or reduce concurrency
   aws lambda put-event-source-mapping \
     --uuid <event-source-mapping-uuid> \
     --enabled false
   ```

### Message Pattern Analysis

4. **Categorize Message Types**
   ```python
   # Python script to analyze message patterns
   import boto3
   import json
   from collections import defaultdict
   
   sqs = boto3.client('sqs')
   queue_url = '<quarantine-queue-url>'
   
   message_patterns = defaultdict(int)
   error_types = defaultdict(int)
   
   # Analyze messages in quarantine queue
   while True:
       response = sqs.receive_message(
           QueueUrl=queue_url,
           MaxNumberOfMessages=10,
           MessageAttributeNames=['All'],
           AttributeNames=['All']
       )
       
       messages = response.get('Messages', [])
       if not messages:
           break
           
       for message in messages:
           try:
               body = json.loads(message['Body'])
               # Analyze message structure
               if 'eventName' in body:
                   message_patterns[body['eventName']] += 1
               if 'errorType' in body:
                   error_types[body['errorType']] += 1
           except json.JSONDecodeError:
               error_types['malformed_json'] += 1
   
   print("Message Patterns:", dict(message_patterns))
   print("Error Types:", dict(error_types))
   ```

## Message Replay Procedures

### Preparation Phase

1. **Fix Root Cause**
   - Deploy Lambda function fix
   - Update configuration if needed
   - Verify fix in staging environment

2. **Prepare Replay Strategy**
   ```bash
   # Determine replay batch size based on:
   # - Lambda concurrency limits
   # - Downstream service capacity
   # - Error rate tolerance
   
   BATCH_SIZE=10  # Start small
   DELAY_BETWEEN_BATCHES=30  # seconds
   ```

### Controlled Replay with Backoff

3. **Implement Exponential Backoff Replay**
   ```python
   import boto3
   import time
   import json
   from botocore.exceptions import ClientError
   
   def replay_messages_with_backoff():
       sqs = boto3.client('sqs')
       source_queue = '<quarantine-queue-url>'
       target_queue = '<original-queue-url>'
       
       batch_size = 10
       max_retries = 3
       base_delay = 1
       
       while True:
           # Receive batch of messages
           response = sqs.receive_message(
               QueueUrl=source_queue,
               MaxNumberOfMessages=batch_size,
               MessageAttributeNames=['All'],
               AttributeNames=['All']
           )
           
           messages = response.get('Messages', [])
           if not messages:
               print("No more messages to replay")
               break
           
           successful_replays = 0
           
           for message in messages:
               retry_count = 0
               while retry_count < max_retries:
                   try:
                       # Send message to original queue
                       sqs.send_message(
                           QueueUrl=target_queue,
                           MessageBody=message['Body'],
                           MessageAttributes=message.get('MessageAttributes', {})
                       )
                       
                       # Delete from quarantine queue
                       sqs.delete_message(
                           QueueUrl=source_queue,
                           ReceiptHandle=message['ReceiptHandle']
                       )
                       
                       successful_replays += 1
                       break
                       
                   except ClientError as e:
                       retry_count += 1
                       delay = base_delay * (2 ** retry_count)
                       print(f"Retry {retry_count} after {delay}s delay")
                       time.sleep(delay)
               
               if retry_count >= max_retries:
                   print(f"Failed to replay message after {max_retries} retries")
           
           print(f"Successfully replayed {successful_replays}/{len(messages)} messages")
           
           # Wait between batches
           time.sleep(30)
   
   if __name__ == "__main__":
       replay_messages_with_backoff()
   ```

4. **Monitor Replay Progress**
   ```bash
   # Watch CloudWatch metrics during replay
   watch -n 30 'aws cloudwatch get-metric-statistics \
     --namespace AWS/SQS \
     --metric-name ApproximateNumberOfMessages \
     --dimensions Name=QueueName,Value=<queue-name> \
     --start-time $(date -d "5 minutes ago" --iso-8601) \
     --end-time $(date --iso-8601) \
     --period 300 \
     --statistics Average'
   ```

## Idempotency Bug Fixes

### Identifying Idempotency Issues

1. **Check for Duplicate Processing**
   ```bash
   # Look for duplicate correlation IDs in logs
   aws logs filter-log-events \
     --log-group-name /aws/lambda/<function-name> \
     --filter-pattern "correlationId" \
     --start-time $(date -d '1 hour ago' +%s)000 | \
     jq -r '.events[].message' | \
     grep -o 'correlationId":"[^"]*' | \
     sort | uniq -c | sort -nr
   ```

2. **Analyze Message Receive Count**
   ```bash
   # Check ApproximateReceiveCount for messages
   aws sqs receive-message \
     --queue-url <queue-url> \
     --attribute-names ApproximateReceiveCount \
     --max-number-of-messages 10
   ```

### Implementing Idempotency Fixes

3. **Add Idempotency Key Tracking**
   ```python
   # Example Lambda function with idempotency
   import boto3
   import json
   import hashlib
   
   dynamodb = boto3.resource('dynamodb')
   idempotency_table = dynamodb.Table('lambda-idempotency')
   
   def lambda_handler(event, context):
       # Generate idempotency key
       message_body = json.dumps(event, sort_keys=True)
       idempotency_key = hashlib.sha256(message_body.encode()).hexdigest()
       
       try:
           # Check if already processed
           response = idempotency_table.get_item(
               Key={'idempotency_key': idempotency_key}
           )
           
           if 'Item' in response:
               print(f"Message already processed: {idempotency_key}")
               return response['Item']['result']
           
           # Process message
           result = process_message(event)
           
           # Store result with TTL
           idempotency_table.put_item(
               Item={
                   'idempotency_key': idempotency_key,
                   'result': result,
                   'ttl': int(time.time()) + 86400  # 24 hours
               }
           )
           
           return result
           
       except Exception as e:
           print(f"Error processing message: {str(e)}")
           raise
   ```

4. **Create Idempotency DynamoDB Table**
   ```bash
   # Create table for idempotency tracking
   aws dynamodb create-table \
     --table-name lambda-idempotency \
     --attribute-definitions \
       AttributeName=idempotency_key,AttributeType=S \
     --key-schema \
       AttributeName=idempotency_key,KeyType=HASH \
     --billing-mode PAY_PER_REQUEST \
     --time-to-live-specification \
       AttributeName=ttl,Enabled=true
   ```

## Visibility Timeout Adjustment

### Calculating Optimal Timeout

1. **Analyze Function Duration**
   ```bash
   # Get function duration statistics
   aws cloudwatch get-metric-statistics \
     --namespace AWS/Lambda \
     --metric-name Duration \
     --dimensions Name=FunctionName,Value=<function-name> \
     --start-time $(date -d '24 hours ago' --iso-8601) \
     --end-time $(date --iso-8601) \
     --period 3600 \
     --statistics Average,Maximum
   ```

2. **Calculate Recommended Timeout**
   ```
   Visibility Timeout = (Lambda Timeout × 6) + Buffer
   
   Where:
   - Lambda Timeout: Maximum execution time
   - Buffer: 30-60 seconds for processing overhead
   - Factor of 6: Accounts for retries and processing delays
   ```

### Implementing Timeout Adjustments

3. **Update Queue Visibility Timeout**
   ```bash
   # Update main queue visibility timeout
   aws sqs set-queue-attributes \
     --queue-url <queue-url> \
     --attributes '{
       "VisibilityTimeoutSeconds": "<calculated-timeout>"
     }'
   ```

4. **Dynamic Timeout Adjustment**
   ```python
   # Lambda function to dynamically adjust visibility timeout
   import boto3
   
   def adjust_visibility_timeout(queue_url, message_receipt_handle, additional_time):
       sqs = boto3.client('sqs')
       
       try:
           sqs.change_message_visibility(
               QueueUrl=queue_url,
               ReceiptHandle=message_receipt_handle,
               VisibilityTimeout=additional_time
           )
           print(f"Extended visibility timeout by {additional_time} seconds")
       except Exception as e:
           print(f"Failed to adjust visibility timeout: {str(e)}")
   ```

## Queue Management Procedures

### Queue Health Monitoring

1. **Set Up Queue Alarms**
   ```bash
   # Alarm for queue depth
   aws cloudwatch put-metric-alarm \
     --alarm-name "SQS-QueueDepth-High" \
     --alarm-description "SQS queue depth > 1000 messages" \
     --metric-name ApproximateNumberOfMessages \
     --namespace AWS/SQS \
     --statistic Average \
     --period 300 \
     --threshold 1000 \
     --comparison-operator GreaterThanThreshold \
     --dimensions Name=QueueName,Value=<queue-name> \
     --evaluation-periods 2
   
   # Alarm for DLQ messages
   aws cloudwatch put-metric-alarm \
     --alarm-name "SQS-DLQ-Messages" \
     --alarm-description "Messages in DLQ" \
     --metric-name ApproximateNumberOfMessages \
     --namespace AWS/SQS \
     --statistic Average \
     --period 300 \
     --threshold 1 \
     --comparison-operator GreaterThanThreshold \
     --dimensions Name=QueueName,Value=<dlq-name> \
     --evaluation-periods 1
   ```

2. **Queue Metrics Dashboard**
   ```json
   {
     "widgets": [
       {
         "type": "metric",
         "properties": {
           "metrics": [
             ["AWS/SQS", "ApproximateNumberOfMessages", "QueueName", "<queue-name>"],
             [".", "ApproximateNumberOfMessagesVisible", ".", "."],
             [".", "ApproximateNumberOfMessagesNotVisible", ".", "."],
             [".", "NumberOfMessagesSent", ".", "."],
             [".", "NumberOfMessagesReceived", ".", "."],
             [".", "NumberOfMessagesDeleted", ".", "."]
           ],
           "period": 300,
           "stat": "Average",
           "region": "us-east-1",
           "title": "SQS Queue Health"
         }
       }
     ]
   }
   ```

### Queue Maintenance

3. **Purge Queue (Emergency)**
   ```bash
   # WARNING: This deletes ALL messages in the queue
   aws sqs purge-queue --queue-url <queue-url>
   ```

4. **Drain Queue Gradually**
   ```python
   # Script to gradually drain queue for maintenance
   import boto3
   import time
   
   def drain_queue_gradually(queue_url, batch_size=10, delay=5):
       sqs = boto3.client('sqs')
       total_processed = 0
       
       while True:
           response = sqs.receive_message(
               QueueUrl=queue_url,
               MaxNumberOfMessages=batch_size,
               WaitTimeSeconds=1
           )
           
           messages = response.get('Messages', [])
           if not messages:
               print(f"Queue drained. Total processed: {total_processed}")
               break
           
           # Process messages (or just delete them)
           for message in messages:
               # Add processing logic here if needed
               sqs.delete_message(
                   QueueUrl=queue_url,
                   ReceiptHandle=message['ReceiptHandle']
               )
               total_processed += 1
           
           print(f"Processed batch of {len(messages)} messages")
           time.sleep(delay)
   ```

## Troubleshooting Checklist

### Pre-Investigation Checklist
- [ ] Check CloudWatch alarms for the queue and Lambda function
- [ ] Verify recent deployments or configuration changes
- [ ] Review queue attributes (visibility timeout, message retention, DLQ config)
- [ ] Check Lambda function concurrency and error rates

### During Investigation
- [ ] Sample messages from DLQ for pattern analysis
- [ ] Check Lambda function logs for specific error messages
- [ ] Verify queue permissions and IAM roles
- [ ] Monitor queue metrics during troubleshooting

### Post-Resolution
- [ ] Update monitoring thresholds based on findings
- [ ] Document root cause and resolution steps
- [ ] Update Lambda function error handling if needed
- [ ] Schedule follow-up monitoring period

## Emergency Procedures

### Queue Overflow Emergency
1. **Immediate Actions**
   - Increase Lambda concurrency if throttling
   - Enable additional processing instances
   - Consider temporary queue purging if data loss acceptable

2. **Communication**
   - Notify stakeholders of queue backlog
   - Provide ETA for resolution
   - Document business impact

### DLQ Overflow Emergency
1. **Immediate Actions**
   - Move DLQ messages to quarantine queue
   - Pause main queue processing if needed
   - Investigate root cause immediately

2. **Recovery Steps**
   - Fix underlying issue
   - Implement controlled message replay
   - Monitor for recurring issues

## Quick Reference Commands

```bash
# Check queue attributes
aws sqs get-queue-attributes --queue-url <url> --attribute-names All

# Receive messages without deleting
aws sqs receive-message --queue-url <url> --max-number-of-messages 10

# Change message visibility timeout
aws sqs change-message-visibility --queue-url <url> --receipt-handle <handle> --visibility-timeout <seconds>

# Get queue message count
aws sqs get-queue-attributes --queue-url <url> --attribute-names ApproximateNumberOfMessages

# Purge queue (emergency only)
aws sqs purge-queue --queue-url <url>

# Create temporary quarantine queue
aws sqs create-queue --queue-name temp-quarantine --attributes '{"MessageRetentionPeriod":"1209600"}'
```