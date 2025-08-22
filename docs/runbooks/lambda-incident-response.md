# Lambda Incident Response Runbook

## Overview

This runbook provides step-by-step procedures for investigating and resolving common AWS Lambda production incidents, including 5XX errors, throttling spikes, and performance degradation.

## Incident Classification

### Severity Levels
- **P1 (Critical)**: Complete service outage, >50% error rate, customer-facing impact
- **P2 (High)**: Significant degradation, 10-50% error rate, partial functionality loss
- **P3 (Medium)**: Minor issues, <10% error rate, limited impact
- **P4 (Low)**: Performance degradation, no functional impact

### Common Lambda Incident Types
1. **5XX Error Spikes** - Function errors, timeouts, memory issues
2. **Throttling Events** - Concurrency limits exceeded
3. **Performance Degradation** - Increased latency, cold starts
4. **Dependency Failures** - Downstream service issues

## 5XX Error Spike Investigation

### Initial Assessment (0-5 minutes)

1. **Check CloudWatch Dashboard**
   ```bash
   # Navigate to Lambda function CloudWatch dashboard
   # Check these key metrics for the last 1-4 hours:
   ```
   - Error count and error rate percentage
   - Duration (average, p95, p99)
   - Invocations count
   - Throttles count
   - Dead letter queue messages

2. **Identify Error Pattern**
   ```bash
   # Check CloudWatch Logs Insights for error patterns
   # Use this query to identify common errors:
   ```
   ```
   fields @timestamp, @message, @requestId
   | filter @message like /ERROR/
   | stats count() by bin(5m)
   | sort @timestamp desc
   | limit 100
   ```

3. **Check Recent Deployments**
   ```bash
   # Verify if errors correlate with recent deployments
   # Check CodeDeploy deployment history
   aws deploy list-deployments --application-name <app-name> \
     --create-time-range beginTime=$(date -d '4 hours ago' +%s),endTime=$(date +%s)
   ```

### Deep Investigation (5-15 minutes)

4. **Analyze Error Types**
   ```bash
   # Group errors by type using CloudWatch Logs Insights
   ```
   ```
   fields @timestamp, @message, @requestId
   | filter @message like /ERROR/
   | parse @message /(?<error_type>.*Error):/
   | stats count() by error_type
   | sort count desc
   ```

5. **Check Memory and Timeout Issues**
   ```bash
   # Look for memory exceeded or timeout errors
   ```
   ```
   fields @timestamp, @message, @requestId, @duration, @maxMemoryUsed
   | filter @type = "REPORT"
   | filter @maxMemoryUsed > (@memorySize * 0.9) or @duration > (@timeout * 0.9)
   | sort @timestamp desc
   ```

6. **Examine X-Ray Traces** (if enabled)
   - Navigate to X-Ray console
   - Filter traces by error status
   - Identify bottlenecks in service map
   - Check for downstream service failures

### Resolution Actions

7. **Immediate Mitigation**
   
   **For Memory Issues:**
   ```bash
   # Increase memory allocation
   aws lambda update-function-configuration \
     --function-name <function-name> \
     --memory-size <new-memory-size>
   ```
   
   **For Timeout Issues:**
   ```bash
   # Increase timeout (max 15 minutes)
   aws lambda update-function-configuration \
     --function-name <function-name> \
     --timeout <new-timeout-seconds>
   ```
   
   **For Code Issues - Rollback:**
   ```bash
   # Rollback to previous version using alias
   aws lambda update-alias \
     --function-name <function-name> \
     --name LIVE \
     --function-version <previous-version>
   ```

8. **Monitor Recovery**
   - Watch error rate decrease in CloudWatch
   - Verify normal invocation patterns resume
   - Check downstream service health
   - Monitor for 15-30 minutes post-resolution

## Throttling Spike Investigation

### Initial Assessment (0-3 minutes)

1. **Check Concurrency Metrics**
   ```bash
   # Review these CloudWatch metrics:
   ```
   - ConcurrentExecutions
   - UnreservedConcurrentExecutions
   - Throttles
   - Duration and invocation patterns

2. **Identify Throttling Source**
   ```bash
   # Check if throttling is at function or account level
   aws lambda get-account-settings
   ```

### Resolution Actions

3. **Immediate Concurrency Adjustment**
   
   **Increase Reserved Concurrency:**
   ```bash
   # Set reserved concurrency for critical functions
   aws lambda put-reserved-concurrency-configuration \
     --function-name <function-name> \
     --reserved-concurrent-executions <number>
   ```
   
   **Enable Provisioned Concurrency:**
   ```bash
   # For predictable traffic patterns
   aws lambda put-provisioned-concurrency-config \
     --function-name <function-name> \
     --qualifier <alias-or-version> \
     --provisioned-concurrent-executions <number>
   ```

4. **Traffic Management**
   - Enable API Gateway throttling if not configured
   - Implement exponential backoff in client applications
   - Consider SQS buffering for asynchronous workloads

## CloudWatch Metrics Analysis Procedures

### Key Metrics Dashboard Setup

1. **Create Custom Dashboard**
   ```json
   {
     "widgets": [
       {
         "type": "metric",
         "properties": {
           "metrics": [
             ["AWS/Lambda", "Errors", "FunctionName", "<function-name>"],
             [".", "Invocations", ".", "."],
             [".", "Duration", ".", "."],
             [".", "Throttles", ".", "."],
             [".", "ConcurrentExecutions", ".", "."]
           ],
           "period": 300,
           "stat": "Sum",
           "region": "us-east-1",
           "title": "Lambda Function Health"
         }
       }
     ]
   }
   ```

2. **Set Up Critical Alarms**
   ```bash
   # Error rate alarm
   aws cloudwatch put-metric-alarm \
     --alarm-name "Lambda-ErrorRate-High" \
     --alarm-description "Lambda error rate > 5%" \
     --metric-name Errors \
     --namespace AWS/Lambda \
     --statistic Sum \
     --period 300 \
     --threshold 5 \
     --comparison-operator GreaterThanThreshold \
     --dimensions Name=FunctionName,Value=<function-name> \
     --evaluation-periods 2
   ```

### Metrics Interpretation Guide

- **Error Rate > 5%**: Investigate immediately
- **Duration > p95 baseline + 50%**: Performance degradation
- **Throttles > 0**: Concurrency issues
- **Cold Start Rate > 20%**: Consider provisioned concurrency

## Deployment Rollback Procedures

### Automated Rollback (CodeDeploy)

1. **Check Deployment Status**
   ```bash
   aws deploy get-deployment --deployment-id <deployment-id>
   ```

2. **Trigger Automatic Rollback**
   ```bash
   # Stop current deployment and rollback
   aws deploy stop-deployment --deployment-id <deployment-id> --auto-rollback-enabled
   ```

### Manual Rollback

1. **Identify Previous Stable Version**
   ```bash
   # List function versions
   aws lambda list-versions-by-function --function-name <function-name>
   ```

2. **Update Alias to Previous Version**
   ```bash
   # Point LIVE alias to previous version
   aws lambda update-alias \
     --function-name <function-name> \
     --name LIVE \
     --function-version <previous-stable-version>
   ```

3. **Verify Rollback Success**
   ```bash
   # Check current alias configuration
   aws lambda get-alias --function-name <function-name> --name LIVE
   ```

## Provisioned Concurrency Adjustment

### Assessment

1. **Analyze Traffic Patterns**
   ```bash
   # Review invocation patterns over 24-48 hours
   # Look for predictable spikes and baseline traffic
   ```

2. **Calculate Optimal Concurrency**
   ```
   Provisioned Concurrency = Peak RPS × Average Duration (seconds)
   Add 20% buffer for safety margin
   ```

### Implementation

1. **Gradual Scaling Approach**
   ```bash
   # Start with 50% of calculated need
   aws lambda put-provisioned-concurrency-config \
     --function-name <function-name> \
     --qualifier <alias> \
     --provisioned-concurrent-executions <calculated-number>
   ```

2. **Monitor and Adjust**
   - Watch ProvisionedConcurrencyUtilization metric
   - Adjust based on actual usage patterns
   - Consider cost implications

## WAF Analysis Procedures

### When Lambda is Behind API Gateway with WAF

1. **Check WAF Metrics**
   ```bash
   # Review WAF CloudWatch metrics
   ```
   - AllowedRequests
   - BlockedRequests
   - CountedRequests
   - SampledRequests

2. **Analyze Blocked Requests**
   ```bash
   # Check WAF logs for blocked requests that might be legitimate
   # Look for patterns in blocked traffic
   ```

3. **Correlate with Lambda Errors**
   - Compare WAF block times with Lambda error spikes
   - Verify if legitimate traffic is being blocked
   - Check rate limiting rules effectiveness

### WAF Rule Adjustment

1. **Temporary Rule Modification**
   ```bash
   # Switch rule from BLOCK to COUNT for testing
   aws wafv2 update-rule-group \
     --scope CLOUDFRONT \
     --id <rule-group-id> \
     --rules file://modified-rules.json
   ```

2. **Monitor Impact**
   - Watch for changes in Lambda error patterns
   - Verify security posture maintained
   - Adjust rules based on analysis

## Escalation Procedures

### Escalation Triggers
- P1 incidents not resolved within 30 minutes
- P2 incidents not resolved within 2 hours
- Customer-reported issues
- Security-related incidents

### Escalation Contacts
1. **Level 1**: On-call engineer (immediate)
2. **Level 2**: Senior engineer + Team lead (15 minutes)
3. **Level 3**: Engineering manager + Principal engineer (30 minutes)
4. **Level 4**: Director + AWS Support (1 hour)

### Communication Template
```
INCIDENT: [P1/P2/P3] Lambda Function Error Spike
FUNCTION: <function-name>
IMPACT: <customer/business impact>
STARTED: <timestamp>
CURRENT STATUS: <investigating/mitigating/resolved>
NEXT UPDATE: <timestamp>
OWNER: <engineer-name>
```

## Post-Incident Actions

1. **Document Timeline**
   - Record all actions taken
   - Note resolution time and methods
   - Identify root cause

2. **Update Monitoring**
   - Adjust alarm thresholds if needed
   - Add new metrics based on incident learnings
   - Update runbook procedures

3. **Conduct Blameless Post-Mortem**
   - Schedule within 48 hours
   - Focus on process improvements
   - Update documentation and procedures

## Quick Reference Commands

```bash
# Get function configuration
aws lambda get-function-configuration --function-name <name>

# List recent invocations with errors
aws logs filter-log-events --log-group-name /aws/lambda/<function-name> \
  --filter-pattern "ERROR" --start-time $(date -d '1 hour ago' +%s)000

# Check current concurrency usage
aws lambda get-account-settings

# Update function memory
aws lambda update-function-configuration --function-name <name> --memory-size <size>

# Rollback alias to previous version
aws lambda update-alias --function-name <name> --name LIVE --function-version <version>
```