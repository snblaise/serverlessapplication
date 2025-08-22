# AWS Lambda Production Readiness Requirements

## Document Information

| Field | Value |
|-------|-------|
| Document Type | PRR |
| Version | 1.0 |
| Last Updated | 2025-08-22 |
| Owner | Principal Serverless Architecture Team |
| Reviewers | Security, Compliance, Operations, DevOps |
| Approval Status | Draft |

## Table of Contents

- [Overview](#overview)
- [Non-Functional Requirements](#non-functional-requirements)
- [Security Baseline](#security-baseline)
- [Lambda Runtime & Reliability](#lambda-runtime--reliability)
- [Event Sources & API Configuration](#event-sources--api-configuration)
- [Observability & Operations](#observability--operations)
- [Data Protection](#data-protection)
- [CI/CD Controls](#cicd-controls)
- [Change & Release Management](#change--release-management)
- [Cost & FinOps](#cost--finops)
- [Compliance Mapping](#compliance-mapping)
- [Validation](#validation)
- [References](#references)

## Overview

### Purpose
This document defines comprehensive Production Readiness Requirements (PRR) for AWS Lambda serverless workloads in regulated financial services environments. It establishes production-grade standards for security, reliability, compliance, and operational excellence to ensure Lambda systems can pass go-live reviews and maintain regulatory compliance.

### Audience
- Principal Serverless Architects
- DevOps Engineers
- Security Engineers
- Compliance Auditors
- Operations Teams
- Release Managers

### Prerequisites
- AWS Account with appropriate service access
- Understanding of AWS Lambda, API Gateway, EventBridge, SQS, SNS
- Familiarity with financial services compliance requirements (ISO 27001, SOC 2, NIST CSF)
- Knowledge of CI/CD practices and Infrastructure as Code

## Non-Functional Requirements

### NFR-001: Availability & Service Level Objectives

#### NFR-001.1 Service Availability
- **Requirement**: Lambda functions SHALL maintain 99.9% availability SLO (Service Level Objective)
- **Measurement**: Monthly uptime calculated as (Total Time - Downtime) / Total Time × 100
- **Downtime Definition**: Any period where function returns 5XX errors for >1 minute
- **Error Budget**: 43.2 minutes of downtime per month (0.1% of 720 hours)
- **Validation**: CloudWatch availability metrics and SLO dashboards

#### NFR-001.2 Regional Resilience
- **Requirement**: Critical Lambda functions SHALL be deployable across multiple AWS regions
- **Implementation**: Multi-region deployment capability with traffic routing
- **Failover**: Automated failover to secondary region within 5 minutes
- **Validation**: Disaster recovery testing and region failover procedures

### NFR-002: Performance & Latency Requirements

#### NFR-002.1 Response Time Budgets
- **API Gateway + Lambda (Synchronous)**:
  - P50 latency: ≤ 200ms
  - P95 latency: ≤ 500ms  
  - P99 latency: ≤ 1000ms
- **Event-driven (Asynchronous)**:
  - Processing initiation: ≤ 100ms from event receipt
  - End-to-end processing: ≤ 5 seconds for standard workflows
- **Validation**: X-Ray tracing and CloudWatch metrics analysis

#### NFR-002.2 Cold Start Optimization
- **Requirement**: Cold start latency SHALL be minimized through architectural patterns
- **Implementation**: 
  - Provisioned concurrency for latency-critical functions
  - Runtime optimization (prefer compiled languages for performance-critical paths)
  - Connection pooling and SDK reuse patterns
- **Target**: Cold start overhead ≤ 1 second for Node.js/Python, ≤ 500ms for compiled runtimes
- **Validation**: Cold start metrics tracking and optimization reporting

### NFR-003: Throughput & Scaling Requirements

#### NFR-003.1 Concurrent Execution Limits
- **Account-level**: Reserve 80% of regional concurrent execution limit for production workloads
- **Function-level**: Configure reserved concurrency based on load testing results
- **Burst capacity**: Account for 2x normal traffic during peak periods
- **Validation**: Load testing reports and concurrency monitoring

#### NFR-003.2 Throughput Targets
- **Synchronous invocations**: Support up to 1000 TPS per function with <1% error rate
- **Asynchronous processing**: Handle batch sizes up to 10,000 messages with linear scaling
- **Event source scaling**: Auto-scaling based on queue depth and processing velocity
- **Validation**: Performance testing results and production metrics

### NFR-004: Disaster Recovery & Business Continuity

#### NFR-004.1 Recovery Time Objective (RTO)
- **Critical functions**: RTO ≤ 4 hours
- **Standard functions**: RTO ≤ 8 hours  
- **Non-critical functions**: RTO ≤ 24 hours
- **Implementation**: Automated disaster recovery procedures and cross-region deployment
- **Validation**: DR testing and recovery time measurement

#### NFR-004.2 Recovery Point Objective (RPO)
- **Critical data**: RPO ≤ 15 minutes
- **Standard data**: RPO ≤ 1 hour
- **Non-critical data**: RPO ≤ 4 hours
- **Implementation**: Cross-region replication and backup strategies
- **Validation**: Data recovery testing and backup verification

#### NFR-004.3 Backup & Restore
- **Code artifacts**: Versioned storage in S3 with cross-region replication
- **Configuration**: Infrastructure as Code stored in version control
- **Dependencies**: Dependency management and reproducible builds
- **Validation**: Restore testing and artifact integrity verification

### NFR-005: Data Retention & Lifecycle Management

#### NFR-005.1 Log Retention Policies
- **Application logs**: 90 days in CloudWatch Logs
- **Audit logs**: 7 years in S3 with Glacier transition after 90 days
- **Performance metrics**: 15 months in CloudWatch
- **Trace data**: 30 days in X-Ray
- **Validation**: Automated lifecycle policy enforcement

#### NFR-005.2 Data Classification & Handling
- **PII/Sensitive data**: Encrypted at rest and in transit, access logging required
- **Financial data**: Compliance with data residency requirements
- **Operational data**: Standard encryption and access controls
- **Validation**: Data classification scanning and compliance reporting

### NFR-006: Cost Management & FinOps

#### NFR-006.1 Cost Key Performance Indicators
- **Cost per transaction**: Track and optimize cost per API call/event processed
- **Resource utilization**: >80% utilization of provisioned concurrency
- **Waste elimination**: <5% of invocations result in timeouts or errors
- **Cost allocation**: 100% of costs allocated to business units via tagging
- **Validation**: Cost and usage reports with trend analysis

#### NFR-006.2 Cost Optimization Requirements
- **Right-sizing**: Memory allocation based on profiling and cost analysis
- **Scheduling**: Use EventBridge scheduling for batch processing during off-peak hours
- **Resource cleanup**: Automated cleanup of unused versions and aliases
- **Reserved capacity**: Cost-benefit analysis for provisioned concurrency
- **Validation**: Monthly cost optimization reviews and recommendations

### NFR-007: Capacity Planning & Scaling

#### NFR-007.1 Growth Planning
- **Traffic growth**: Plan for 100% year-over-year growth in transaction volume
- **Geographic expansion**: Support for new regions within 30 days
- **Feature scaling**: Modular architecture supporting independent scaling
- **Validation**: Capacity planning models and growth projections

#### NFR-007.2 Auto-scaling Configuration
- **Event source scaling**: Automatic scaling based on queue depth and processing rate
- **Provisioned concurrency**: Dynamic adjustment based on traffic patterns
- **Circuit breakers**: Automatic throttling to prevent cascade failures
- **Validation**: Scaling behavior testing and performance validation

---

*This section establishes the foundational non-functional requirements that all Lambda workloads must meet. The following sections detail specific implementation requirements for security, reliability, and operational excellence.*
## Se
curity Baseline

### SEC-001: Identity & Access Management

#### SEC-001.1 IAM Execution Roles - Least Privilege
- **Requirement**: Lambda functions SHALL use dedicated IAM execution roles with minimal required permissions
- **Implementation**:
  - One role per function or logical grouping of functions
  - No wildcard (*) permissions in production policies
  - Resource-specific ARNs where possible
  - Regular access review and permission pruning
- **Policy Structure**:
  ```json
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "logs:CreateLogGroup",
          "logs:CreateLogStream", 
          "logs:PutLogEvents"
        ],
        "Resource": "arn:aws:logs:region:account:log-group:/aws/lambda/function-name:*"
      }
    ]
  }
  ```
- **Validation**: IAM Access Analyzer and policy simulation testing

#### SEC-001.2 Permission Boundaries
- **Requirement**: All Lambda execution roles SHALL have permission boundaries attached
- **Implementation**:
  - Centrally managed permission boundary policy
  - Prevents privilege escalation beyond defined limits
  - Enforced via Service Control Policies (SCPs)
- **Boundary Policy**: Restrict actions to approved AWS services and regions
- **Validation**: Automated policy compliance scanning

#### SEC-001.3 AWS IAM Identity Center Integration
- **Requirement**: Human access to Lambda resources SHALL use Identity Center federation
- **Implementation**:
  - No long-lived IAM user access keys for human users
  - Role-based access through Identity Center permission sets
  - Multi-factor authentication (MFA) required
  - Session duration limits (max 8 hours)
- **Validation**: Access audit logs and session monitoring

### SEC-002: Secrets & Configuration Management

#### SEC-002.1 AWS Secrets Manager Integration
- **Requirement**: Sensitive configuration data SHALL be stored in AWS Secrets Manager
- **Implementation**:
  - Database credentials, API keys, certificates stored in Secrets Manager
  - Automatic rotation enabled where supported
  - Cross-region replication for disaster recovery
  - Lambda extension for optimized secret retrieval
- **Access Pattern**:
  ```python
  import boto3
  import json
  
  def get_secret(secret_name, region_name):
      session = boto3.session.Session()
      client = session.client('secretsmanager', region_name=region_name)
      get_secret_value_response = client.get_secret_value(SecretId=secret_name)
      return json.loads(get_secret_value_response['SecretString'])
  ```
- **Validation**: Secret access logging and rotation compliance

#### SEC-002.2 AWS Systems Manager Parameter Store
- **Requirement**: Non-sensitive configuration SHALL use Parameter Store with encryption
- **Implementation**:
  - SecureString parameters with KMS encryption
  - Hierarchical parameter organization (/app/env/component/setting)
  - Parameter versioning and change tracking
  - Lambda extension for parameter caching
- **Validation**: Parameter access audit and encryption verification

#### SEC-002.3 KMS Encryption Requirements
- **Requirement**: All encryption SHALL use customer-managed KMS keys (CMKs)
- **Implementation**:
  - Dedicated CMKs per environment and data classification
  - Key rotation enabled (annual)
  - Cross-account access policies for shared resources
  - Lambda environment variable encryption with CMKs
- **Key Policy Example**:
  ```json
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "LambdaEnvironmentVariableAccess",
        "Effect": "Allow",
        "Principal": {"AWS": "arn:aws:iam::account:role/lambda-execution-role"},
        "Action": ["kms:Decrypt"],
        "Resource": "*",
        "Condition": {
          "StringEquals": {
            "kms:ViaService": "lambda.region.amazonaws.com"
          }
        }
      }
    ]
  }
  ```
- **Validation**: KMS key usage monitoring and rotation compliance

### SEC-003: Code Integrity & Signing

#### SEC-003.1 AWS Lambda Code Signing
- **Requirement**: All Lambda functions SHALL have code signing enabled in production
- **Implementation**:
  - AWS Signer signing profiles for each application
  - Code Signing Configuration attached to Lambda functions
  - Signature validation before deployment
  - Revocation capability for compromised signatures
- **Configuration**:
  ```yaml
  CodeSigningConfig:
    Type: AWS::Lambda::CodeSigningConfig
    Properties:
      AllowedPublishers:
        SigningProfileVersionArns:
          - !Ref SigningProfileVersionArn
      CodeSigningPolicies:
        UntrustedArtifactOnDeployment: Enforce
  ```
- **Validation**: Signature verification in CI/CD pipeline

#### SEC-003.2 Artifact Integrity
- **Requirement**: Deployment artifacts SHALL have integrity verification
- **Implementation**:
  - SHA256 checksums for all deployment packages
  - Artifact storage in S3 with versioning and MFA delete
  - Immutable artifact tags and metadata
  - Supply chain security scanning
- **Validation**: Checksum verification and artifact provenance tracking

### SEC-004: Network Security Controls

#### SEC-004.1 VPC Configuration
- **Requirement**: Lambda functions accessing private resources SHALL be VPC-attached
- **Implementation**:
  - Dedicated subnets for Lambda functions
  - Security groups with minimal required access
  - VPC endpoints for AWS services (avoid NAT gateway costs)
  - Network ACLs for additional layer of security
- **Security Group Example**:
  ```yaml
  LambdaSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: Lambda function security group
      VpcId: !Ref VPC
      SecurityGroupEgress:
        - IpProtocol: tcp
          FromPort: 443
          ToPort: 443
          CidrIp: 0.0.0.0/0
          Description: HTTPS outbound for AWS services
  ```
- **Validation**: Network flow analysis and security group auditing

#### SEC-004.2 VPC Endpoints
- **Requirement**: VPC-attached Lambdas SHALL use VPC endpoints for AWS service access
- **Implementation**:
  - Gateway endpoints for S3 and DynamoDB
  - Interface endpoints for other AWS services
  - Private DNS resolution enabled
  - Endpoint policies for access control
- **Validation**: Network traffic analysis and cost optimization

### SEC-005: API Gateway Security

#### SEC-005.1 AWS WAF Protection
- **Requirement**: Internet-facing API Gateway stages SHALL have AWS WAF protection
- **Implementation**:
  - WAF Web ACL attached to API Gateway stage
  - Rate limiting rules (1000 requests per 5 minutes per IP)
  - Geographic restrictions based on business requirements
  - SQL injection and XSS protection rules
- **WAF Rules**:
  - AWS Managed Rules: Core Rule Set, Known Bad Inputs
  - Custom rules for application-specific threats
  - IP reputation lists and bot control
- **Validation**: WAF metrics monitoring and attack simulation testing

#### SEC-005.2 API Authentication & Authorization
- **Requirement**: API Gateway endpoints SHALL implement proper authentication
- **Implementation Options**:
  - AWS Cognito User Pools for user authentication
  - IAM authentication for service-to-service calls
  - Lambda authorizers for custom authentication logic
  - API keys for partner integrations (with usage plans)
- **Validation**: Authentication testing and authorization matrix verification

#### SEC-005.3 API Gateway Configuration Security
- **Requirement**: API Gateway SHALL be configured with security best practices
- **Implementation**:
  - HTTPS-only endpoints (TLS 1.2 minimum)
  - Request/response validation enabled
  - CloudWatch logging enabled (INFO level minimum)
  - X-Ray tracing enabled for request tracking
- **Validation**: Configuration compliance scanning

### SEC-006: Data Protection

#### SEC-006.1 Encryption in Transit
- **Requirement**: All data transmission SHALL use encryption in transit
- **Implementation**:
  - TLS 1.2 or higher for all HTTPS connections
  - Certificate management through AWS Certificate Manager
  - Perfect Forward Secrecy (PFS) enabled
  - HSTS headers for web applications
- **Validation**: SSL/TLS configuration testing and certificate monitoring

#### SEC-006.2 Encryption at Rest
- **Requirement**: All data at rest SHALL be encrypted using approved algorithms
- **Implementation**:
  - Lambda environment variables encrypted with CMKs
  - S3 bucket encryption with SSE-KMS
  - DynamoDB encryption with customer-managed keys
  - CloudWatch Logs encryption with KMS
- **Validation**: Encryption compliance scanning and key usage monitoring

---

*This section establishes the security baseline requirements that all Lambda workloads must implement. The following sections detail specific implementation requirements for runtime reliability and operational excellence.*

## Lambda Runtime & Reliability

### LRR-001: Version Management & Deployment Strategy

#### LRR-001.1 Lambda Function Versioning
- **Requirement**: Lambda functions SHALL use versioning with immutable releases
- **Implementation**:
  - Publish new version for each deployment ($LATEST prohibited in production)
  - Semantic versioning for function releases (major.minor.patch)
  - Version descriptions with deployment metadata (commit SHA, build number, timestamp)
  - Retention policy: Keep last 10 versions, archive older versions to S3
- **Version Publishing**:
  ```yaml
  LambdaVersion:
    Type: AWS::Lambda::Version
    Properties:
      FunctionName: !Ref LambdaFunction
      Description: !Sub "Version ${BuildNumber} - Commit ${CommitSHA}"
      CodeSha256: !GetAtt LambdaFunction.CodeSha256
  ```
- **Validation**: Version history tracking and automated cleanup verification

#### LRR-001.2 Lambda Aliases for Traffic Management
- **Requirement**: Production traffic SHALL route through Lambda aliases
- **Implementation**:
  - LIVE alias pointing to current production version
  - STAGING alias for pre-production validation
  - Weighted routing for canary deployments (10% new version, 90% current)
  - Alias-specific environment variables and configuration
- **Alias Configuration**:
  ```yaml
  ProductionAlias:
    Type: AWS::Lambda::Alias
    Properties:
      FunctionName: !Ref LambdaFunction
      FunctionVersion: !GetAtt LambdaVersion.Version
      Name: LIVE
      RoutingConfig:
        AdditionalVersionWeights:
          - FunctionVersion: !GetAtt PreviousVersion.Version
            FunctionWeight: 0.1
  ```
- **Validation**: Alias routing verification and traffic distribution monitoring

#### LRR-001.3 AWS CodeDeploy Integration
- **Requirement**: Production deployments SHALL use AWS CodeDeploy for automated canary releases
- **Implementation**:
  - CodeDeploy application and deployment group configuration
  - Canary deployment strategy: 10% traffic for 5 minutes, then 100%
  - Automatic rollback on CloudWatch alarm triggers
  - Pre and post-deployment hooks for validation
- **Deployment Configuration**:
  ```yaml
  CodeDeployApplication:
    Type: AWS::CodeDeploy::Application
    Properties:
      ApplicationName: !Sub "${FunctionName}-deploy"
      ComputePlatform: Lambda
  
  DeploymentGroup:
    Type: AWS::CodeDeploy::DeploymentGroup
    Properties:
      ApplicationName: !Ref CodeDeployApplication
      DeploymentGroupName: production
      ServiceRoleArn: !GetAtt CodeDeployRole.Arn
      DeploymentConfigName: CodeDeployDefault.Lambda10PercentEvery5Minutes
      AutoRollbackConfiguration:
        Enabled: true
        Events:
          - DEPLOYMENT_FAILURE
          - DEPLOYMENT_STOP_ON_ALARM
      AlarmConfiguration:
        Enabled: true
        Alarms:
          - Name: !Ref ErrorRateAlarm
          - Name: !Ref DurationAlarm
  ```
- **Validation**: Deployment success rate monitoring and rollback testing

### LRR-002: Concurrency Management & Performance

#### LRR-002.1 Reserved Concurrency Configuration
- **Requirement**: Production Lambda functions SHALL have reserved concurrency configured
- **Implementation**:
  - Reserved concurrency based on load testing and capacity planning
  - Account-level concurrency allocation (80% for production, 20% for non-production)
  - Function-level limits to prevent resource starvation
  - Monitoring and alerting on concurrency utilization
- **Concurrency Calculation**:
  ```
  Reserved Concurrency = (Peak TPS × Average Duration) × Safety Factor
  Safety Factor = 1.5 (50% buffer for traffic spikes)
  Example: (100 TPS × 2s) × 1.5 = 300 concurrent executions
  ```
- **Configuration**:
  ```yaml
  LambdaFunction:
    Type: AWS::Lambda::Function
    Properties:
      ReservedConcurrencyLimit: 300
  ```
- **Validation**: Concurrency metrics monitoring and throttling analysis

#### LRR-002.2 Provisioned Concurrency for Latency-Critical Functions
- **Requirement**: Latency-critical functions SHALL use provisioned concurrency to eliminate cold starts
- **Implementation**:
  - Provisioned concurrency for functions with <500ms latency requirements
  - Auto-scaling based on CloudWatch metrics and scheduled scaling
  - Cost-benefit analysis for provisioned vs on-demand concurrency
  - Warm-up strategies for predictable traffic patterns
- **Provisioned Concurrency Configuration**:
  ```yaml
  ProvisionedConcurrency:
    Type: AWS::Lambda::ProvisionedConcurrencyConfig
    Properties:
      FunctionName: !Ref LambdaFunction
      Qualifier: !Ref ProductionAlias
      ProvisionedConcurrencyLimit: 50
  
  # Auto Scaling for Provisioned Concurrency
  ScalableTarget:
    Type: AWS::ApplicationAutoScaling::ScalableTarget
    Properties:
      ServiceNamespace: lambda
      ResourceId: !Sub "function:${LambdaFunction}:${ProductionAlias}"
      ScalableDimension: lambda:provisioned-concurrency:utilization
      MinCapacity: 10
      MaxCapacity: 100
  ```
- **Validation**: Cold start metrics analysis and cost optimization review

#### LRR-002.3 Timeout Configuration & Optimization
- **Requirement**: Lambda function timeouts SHALL be optimized based on performance testing
- **Implementation**:
  - Timeout values based on P99 execution duration + 20% buffer
  - Maximum timeout: 15 minutes (900 seconds) for batch processing
  - Typical API functions: 30 seconds maximum
  - Event processing functions: Based on SLA requirements
- **Timeout Guidelines**:
  ```yaml
  # API Gateway synchronous functions
  ApiFunction:
    Type: AWS::Lambda::Function
    Properties:
      Timeout: 30  # 30 seconds max for API responses
  
  # Asynchronous event processing
  EventProcessor:
    Type: AWS::Lambda::Function
    Properties:
      Timeout: 300  # 5 minutes for complex processing
  
  # Batch processing functions
  BatchProcessor:
    Type: AWS::Lambda::Function
    Properties:
      Timeout: 900  # 15 minutes maximum
  ```
- **Validation**: Timeout analysis and performance optimization reporting

#### LRR-002.4 Memory Sizing & Cost Optimization
- **Requirement**: Lambda memory allocation SHALL be optimized for performance and cost
- **Implementation**:
  - Memory sizing based on AWS Lambda Power Tuning analysis
  - Minimum 512 MB for production functions (better price/performance ratio)
  - CPU allocation scales linearly with memory (1769 MB = 1 vCPU)
  - Regular memory optimization reviews (quarterly)
- **Memory Optimization Process**:
  ```python
  # Example memory optimization analysis
  memory_configs = [512, 1024, 1536, 2048, 3008]
  for memory in memory_configs:
      # Test execution time and cost
      duration = run_performance_test(memory)
      cost = calculate_cost(memory, duration, invocations_per_month)
      print(f"Memory: {memory}MB, Duration: {duration}ms, Cost: ${cost}")
  ```
- **Validation**: Cost per invocation analysis and performance benchmarking

### LRR-003: Error Handling & Resilience Patterns

#### LRR-003.1 Idempotency Implementation
- **Requirement**: Lambda functions SHALL implement idempotency for safe retries
- **Implementation**:
  - Idempotency keys for duplicate request detection
  - DynamoDB table for idempotency token storage (TTL enabled)
  - Consistent response for duplicate requests
  - Idempotency timeout: 24 hours for financial transactions
- **Idempotency Pattern**:
  ```python
  import boto3
  import hashlib
  import json
  from datetime import datetime, timedelta
  
  def lambda_handler(event, context):
      # Generate idempotency key from request
      idempotency_key = hashlib.sha256(
          json.dumps(event, sort_keys=True).encode()
      ).hexdigest()
      
      dynamodb = boto3.resource('dynamodb')
      table = dynamodb.Table('idempotency-store')
      
      try:
          # Check if request already processed
          response = table.get_item(Key={'idempotency_key': idempotency_key})
          if 'Item' in response:
              return json.loads(response['Item']['response'])
          
          # Process request
          result = process_request(event)
          
          # Store result with TTL
          table.put_item(
              Item={
                  'idempotency_key': idempotency_key,
                  'response': json.dumps(result),
                  'ttl': int((datetime.now() + timedelta(hours=24)).timestamp())
              }
          )
          
          return result
      except Exception as e:
          # Handle errors appropriately
          raise e
  ```
- **Validation**: Duplicate request testing and idempotency verification

#### LRR-003.2 Dead Letter Queue (DLQ) Configuration
- **Requirement**: Asynchronous Lambda functions SHALL have Dead Letter Queues configured
- **Implementation**:
  - SQS DLQ for failed asynchronous invocations
  - Maximum retry attempts: 3 (configurable based on function type)
  - DLQ message retention: 14 days
  - DLQ monitoring and alerting for failed messages
- **DLQ Configuration**:
  ```yaml
  DeadLetterQueue:
    Type: AWS::SQS::Queue
    Properties:
      QueueName: !Sub "${FunctionName}-dlq"
      MessageRetentionPeriod: 1209600  # 14 days
      KmsMasterKeyId: !Ref KMSKey
  
  LambdaFunction:
    Type: AWS::Lambda::Function
    Properties:
      DeadLetterConfig:
        TargetArn: !GetAtt DeadLetterQueue.Arn
      ReservedConcurrencyLimit: 100
  ```
- **DLQ Processing Function**:
  ```python
  def dlq_processor(event, context):
      """Process messages from DLQ for analysis and potential replay"""
      for record in event['Records']:
          message = json.loads(record['body'])
          
          # Log failure details
          logger.error(f"DLQ Message: {message}")
          
          # Analyze failure reason
          failure_reason = analyze_failure(message)
          
          # Send to monitoring system
          send_to_monitoring(message, failure_reason)
          
          # Optionally replay if transient error
          if is_transient_error(failure_reason):
              replay_message(message)
  ```
- **Validation**: DLQ message processing and failure analysis

#### LRR-003.3 Failure Destinations & Event Routing
- **Requirement**: Lambda functions SHALL use destinations for success and failure routing
- **Implementation**:
  - Success destination: SNS topic or SQS queue for downstream processing
  - Failure destination: SQS DLQ or SNS topic for error handling
  - Event filtering based on success/failure status
  - Destination-specific message transformation
- **Destination Configuration**:
  ```yaml
  SuccessDestination:
    Type: AWS::SNS::Topic
    Properties:
      TopicName: !Sub "${FunctionName}-success"
      KmsMasterKeyId: !Ref KMSKey
  
  FailureDestination:
    Type: AWS::SQS::Queue
    Properties:
      QueueName: !Sub "${FunctionName}-failure"
      MessageRetentionPeriod: 1209600
  
  EventInvokeConfig:
    Type: AWS::Lambda::EventInvokeConfig
    Properties:
      FunctionName: !Ref LambdaFunction
      Qualifier: !Ref ProductionAlias
      MaximumRetryAttempts: 2
      DestinationConfig:
        OnSuccess:
          Destination: !Ref SuccessDestination
        OnFailure:
          Destination: !Ref FailureDestination
  ```
- **Validation**: Destination routing testing and message flow verification

#### LRR-003.4 Retry Configuration & Exponential Backoff
- **Requirement**: Lambda retry logic SHALL implement exponential backoff with jitter
- **Implementation**:
  - Maximum retry attempts: 3 for synchronous, 2 for asynchronous
  - Exponential backoff: 2^attempt seconds with jitter
  - Circuit breaker pattern for downstream service failures
  - Retry only on transient errors (5XX, timeouts, throttling)
- **Retry Implementation**:
  ```python
  import time
  import random
  from functools import wraps
  
  def retry_with_backoff(max_retries=3, base_delay=1):
      def decorator(func):
          @wraps(func)
          def wrapper(*args, **kwargs):
              for attempt in range(max_retries + 1):
                  try:
                      return func(*args, **kwargs)
                  except Exception as e:
                      if attempt == max_retries:
                          raise e
                      
                      if not is_retryable_error(e):
                          raise e
                      
                      # Exponential backoff with jitter
                      delay = base_delay * (2 ** attempt)
                      jitter = random.uniform(0, delay * 0.1)
                      time.sleep(delay + jitter)
              
              return wrapper
          return decorator
  
  def is_retryable_error(error):
      """Determine if error is retryable"""
      retryable_errors = [
          'ThrottlingException',
          'ServiceUnavailableException',
          'InternalServerErrorException'
      ]
      return any(err in str(error) for err in retryable_errors)
  ```
- **Validation**: Retry behavior testing and error handling verification

### LRR-004: Performance Monitoring & Optimization

#### LRR-004.1 Cold Start Monitoring & Optimization
- **Requirement**: Cold start performance SHALL be monitored and optimized
- **Implementation**:
  - CloudWatch custom metrics for cold start detection
  - Init duration tracking and analysis
  - Runtime optimization (connection pooling, SDK reuse)
  - Provisioned concurrency for latency-critical functions
- **Cold Start Detection**:
  ```python
  import time
  import os
  
  # Global variables for connection reuse
  db_connection = None
  
  def lambda_handler(event, context):
      start_time = time.time()
      
      # Detect cold start
      is_cold_start = not hasattr(lambda_handler, 'initialized')
      
      if is_cold_start:
          # Initialize connections and resources
          global db_connection
          db_connection = create_db_connection()
          lambda_handler.initialized = True
          
          # Log cold start metrics
          init_duration = time.time() - start_time
          put_custom_metric('ColdStart', 1)
          put_custom_metric('InitDuration', init_duration * 1000)
      
      # Process request using cached connections
      return process_request(event, db_connection)
  ```
- **Validation**: Cold start frequency analysis and optimization impact measurement

#### LRR-004.2 Memory and CPU Utilization Monitoring
- **Requirement**: Lambda resource utilization SHALL be monitored for optimization
- **Implementation**:
  - CloudWatch Insights queries for memory usage analysis
  - CPU utilization tracking through duration metrics
  - Memory leak detection and prevention
  - Right-sizing recommendations based on utilization data
- **Memory Monitoring**:
  ```python
  import psutil
  import os
  
  def monitor_resources():
      """Monitor memory and CPU usage during execution"""
      process = psutil.Process(os.getpid())
      memory_info = process.memory_info()
      
      # Log resource usage
      put_custom_metric('MemoryUsed', memory_info.rss / 1024 / 1024)  # MB
      put_custom_metric('MemoryPercent', process.memory_percent())
      
      return {
          'memory_used_mb': memory_info.rss / 1024 / 1024,
          'memory_percent': process.memory_percent()
      }
  ```
- **Validation**: Resource utilization analysis and cost optimization recommendations

---

*This section establishes the Lambda runtime and reliability requirements that ensure robust, scalable, and cost-effective serverless operations. The following sections detail specific implementation requirements for event sources, observability, and operational procedures.*

## Event Sources & API Configuration

### ESA-001: API Gateway Integration Requirements

#### ESA-001.1 REST API vs HTTP API Selection
- **Requirement**: API Gateway integration SHALL use appropriate API type based on feature requirements
- **Implementation**:
  - REST API for complex authorization, request/response transformation, SDK generation
  - HTTP API for simple proxy integrations with better performance and lower cost
  - WebSocket API for real-time bidirectional communication requirements
  - Private APIs for internal service-to-service communication within VPC
- **Selection Criteria**:
  ```yaml
  # REST API - Feature-rich but higher latency/cost
  RestApi:
    Type: AWS::ApiGateway::RestApi
    Properties:
      Name: !Sub "${ApplicationName}-rest-api"
      Description: "REST API with advanced features"
      EndpointConfiguration:
        Types: [REGIONAL]
      Policy: !Ref ApiGatewayResourcePolicy
  
  # HTTP API - Lower latency and cost, simpler features
  HttpApi:
    Type: AWS::ApiGatewayV2::Api
    Properties:
      Name: !Sub "${ApplicationName}-http-api"
      Description: "HTTP API for simple proxy integration"
      ProtocolType: HTTP
      CorsConfiguration:
        AllowOrigins: ["https://example.com"]
        AllowMethods: [GET, POST, PUT, DELETE]
        AllowHeaders: [Content-Type, Authorization]
  ```
- **Validation**: API type justification documentation and performance comparison

#### ESA-001.2 API Gateway Throttling Configuration
- **Requirement**: API Gateway SHALL implement throttling to protect backend Lambda functions
- **Implementation**:
  - Account-level throttling: 10,000 requests per second default limit
  - Stage-level throttling: Based on capacity planning and load testing
  - Method-level throttling: Granular control for resource-intensive operations
  - Burst capacity: 5,000 requests above steady-state rate
- **Throttling Configuration**:
  ```yaml
  # Stage-level throttling
  ApiGatewayStage:
    Type: AWS::ApiGateway::Stage
    Properties:
      RestApiId: !Ref RestApi
      StageName: prod
      ThrottleSettings:
        RateLimit: 1000    # Requests per second
        BurstLimit: 2000   # Burst capacity
      MethodSettings:
        - ResourcePath: "/orders"
          HttpMethod: POST
          ThrottlingRateLimit: 100
          ThrottlingBurstLimit: 200
  
  # Usage plan for API key management
  UsagePlan:
    Type: AWS::ApiGateway::UsagePlan
    Properties:
      UsagePlanName: !Sub "${ApplicationName}-usage-plan"
      Description: "Production usage plan with throttling"
      Throttle:
        RateLimit: 1000
        BurstLimit: 2000
      Quota:
        Limit: 1000000
        Period: MONTH
      ApiStages:
        - ApiId: !Ref RestApi
          Stage: !Ref ApiGatewayStage
  ```
- **Validation**: Load testing with throttling verification and 429 error handling

#### ESA-001.3 Usage Plans and API Key Management
- **Requirement**: API Gateway SHALL use usage plans for partner and client access control
- **Implementation**:
  - Tiered usage plans (Basic, Standard, Premium) with different rate limits
  - API key rotation policy: 90 days for production keys
  - Usage tracking and billing integration
  - Automated key provisioning through CI/CD or self-service portal
- **Usage Plan Structure**:
  ```yaml
  BasicUsagePlan:
    Type: AWS::ApiGateway::UsagePlan
    Properties:
      UsagePlanName: "Basic-Plan"
      Throttle:
        RateLimit: 100
        BurstLimit: 200
      Quota:
        Limit: 100000
        Period: MONTH
  
  PremiumUsagePlan:
    Type: AWS::ApiGateway::UsagePlan
    Properties:
      UsagePlanName: "Premium-Plan"
      Throttle:
        RateLimit: 1000
        BurstLimit: 2000
      Quota:
        Limit: 10000000
        Period: MONTH
  
  # API Key with automatic rotation
  ApiKey:
    Type: AWS::ApiGateway::ApiKey
    Properties:
      Name: !Sub "${ClientName}-api-key"
      Description: !Sub "API key for ${ClientName}"
      Enabled: true
      StageKeys:
        - RestApiId: !Ref RestApi
          StageName: !Ref ApiGatewayStage
  ```
- **Validation**: Usage plan enforcement testing and key rotation procedures

#### ESA-001.4 Request and Response Validation
- **Requirement**: API Gateway SHALL validate requests and responses against defined schemas
- **Implementation**:
  - JSON Schema validation for request bodies
  - Query parameter and header validation
  - Response model validation for consistent API contracts
  - Error response standardization (RFC 7807 Problem Details)
- **Validation Configuration**:
  ```yaml
  # Request model for validation
  RequestModel:
    Type: AWS::ApiGateway::Model
    Properties:
      RestApiId: !Ref RestApi
      ContentType: "application/json"
      Name: "CreateOrderRequest"
      Schema:
        $schema: "http://json-schema.org/draft-04/schema#"
        type: "object"
        properties:
          orderId:
            type: "string"
            pattern: "^[A-Z0-9]{8}$"
          amount:
            type: "number"
            minimum: 0.01
            maximum: 10000
          currency:
            type: "string"
            enum: ["USD", "EUR", "GBP"]
        required: ["orderId", "amount", "currency"]
  
  # Method with validation
  ApiMethod:
    Type: AWS::ApiGateway::Method
    Properties:
      RestApiId: !Ref RestApi
      ResourceId: !Ref ApiResource
      HttpMethod: POST
      RequestValidatorId: !Ref RequestValidator
      RequestModels:
        "application/json": !Ref RequestModel
      MethodResponses:
        - StatusCode: 200
          ResponseModels:
            "application/json": !Ref ResponseModel
        - StatusCode: 400
          ResponseModels:
            "application/json": !Ref ErrorModel
  ```
- **Validation**: Schema validation testing and error response verification

### ESA-002: EventBridge Integration Requirements

#### ESA-002.1 EventBridge Rules and Pattern Matching
- **Requirement**: EventBridge rules SHALL use specific event patterns for reliable event routing
- **Implementation**:
  - Event pattern specificity to avoid unintended matches
  - Source and detail-type filtering for event categorization
  - Content-based routing using event detail fields
  - Rule naming convention: `{service}-{environment}-{event-type}-rule`
- **Event Rule Configuration**:
  ```yaml
  OrderProcessingRule:
    Type: AWS::Events::Rule
    Properties:
      Name: !Sub "${ApplicationName}-${Environment}-order-created-rule"
      Description: "Route order created events to processing Lambda"
      EventBusName: !Ref CustomEventBus
      EventPattern:
        source: ["order-service"]
        detail-type: ["Order Created"]
        detail:
          status: ["PENDING"]
          amount:
            numeric: [">", 0]
      State: ENABLED
      Targets:
        - Arn: !GetAtt OrderProcessingFunction.Arn
          Id: "OrderProcessingTarget"
          DeadLetterConfig:
            Arn: !GetAtt EventBridgeDLQ.Arn
          RetryPolicy:
            MaximumRetryAttempts: 3
            MaximumEventAge: 3600
  ```
- **Event Pattern Best Practices**:
  ```json
  {
    "source": ["myapp.orders"],
    "detail-type": ["Order State Change"],
    "detail": {
      "state": ["CREATED", "UPDATED"],
      "priority": ["HIGH"],
      "region": [{"exists": true}]
    }
  }
  ```
- **Validation**: Event pattern testing and rule activation verification

#### ESA-002.2 Custom Event Bus Configuration
- **Requirement**: Production workloads SHALL use custom event buses for event isolation
- **Implementation**:
  - Dedicated event bus per application or domain
  - Cross-account event sharing through resource-based policies
  - Event bus encryption with customer-managed KMS keys
  - Archive and replay capabilities for event recovery
- **Custom Event Bus Setup**:
  ```yaml
  CustomEventBus:
    Type: AWS::Events::EventBus
    Properties:
      Name: !Sub "${ApplicationName}-${Environment}-event-bus"
      Description: !Sub "Custom event bus for ${ApplicationName}"
      KmsKeyId: !Ref EventBusKMSKey
      EventSourceName: !Sub "${ApplicationName}.events"
  
  # Cross-account access policy
  EventBusPolicy:
    Type: AWS::Events::EventBusPolicy
    Properties:
      EventBusName: !Ref CustomEventBus
      StatementId: "CrossAccountAccess"
      Statement:
        Effect: "Allow"
        Principal:
          AWS: !Sub "arn:aws:iam::${TrustedAccountId}:root"
        Action: "events:PutEvents"
        Resource: !GetAtt CustomEventBus.Arn
  
  # Event archive for replay capability
  EventArchive:
    Type: AWS::Events::Archive
    Properties:
      ArchiveName: !Sub "${ApplicationName}-event-archive"
      EventSourceArn: !GetAtt CustomEventBus.Arn
      Description: "Archive for event replay and audit"
      RetentionDays: 365
      EventPattern:
        source: [!Sub "${ApplicationName}.orders"]
  ```
- **Validation**: Event bus isolation testing and cross-account access verification

#### ESA-002.3 EventBridge Dead Letter Queue Configuration
- **Requirement**: EventBridge rules SHALL have Dead Letter Queues for failed event processing
- **Implementation**:
  - SQS DLQ for each EventBridge rule target
  - DLQ message retention: 14 days
  - DLQ monitoring and alerting for failed events
  - Automated DLQ processing for event replay and analysis
- **DLQ Configuration**:
  ```yaml
  EventBridgeDLQ:
    Type: AWS::SQS::Queue
    Properties:
      QueueName: !Sub "${ApplicationName}-eventbridge-dlq"
      MessageRetentionPeriod: 1209600  # 14 days
      KmsMasterKeyId: !Ref KMSKey
      VisibilityTimeoutSeconds: 300
      ReceiveMessageWaitTimeSeconds: 20
  
  # DLQ processing Lambda
  DLQProcessor:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub "${ApplicationName}-dlq-processor"
      Runtime: python3.11
      Handler: dlq_processor.handler
      Code:
        ZipFile: |
          import json
          import boto3
          import logging
          
          logger = logging.getLogger()
          logger.setLevel(logging.INFO)
          
          def handler(event, context):
              for record in event['Records']:
                  try:
                      # Parse the failed EventBridge event
                      message_body = json.loads(record['body'])
                      
                      # Log failure details
                      logger.error(f"Failed EventBridge event: {message_body}")
                      
                      # Analyze failure and potentially replay
                      analyze_and_replay(message_body)
                      
                  except Exception as e:
                      logger.error(f"Error processing DLQ message: {str(e)}")
                      raise e
          
          def analyze_and_replay(failed_event):
              # Implementation for event analysis and replay logic
              pass
      Environment:
        Variables:
          EVENT_BUS_NAME: !Ref CustomEventBus
  ```
- **Validation**: DLQ message processing and event replay testing

### ESA-003: SQS Integration and Redrive Policies

#### ESA-003.1 SQS Queue Configuration for Lambda Event Sources
- **Requirement**: SQS queues used as Lambda event sources SHALL be configured for reliability and performance
- **Implementation**:
  - Standard queues for high throughput, FIFO queues for ordering requirements
  - Visibility timeout: 6x Lambda function timeout (minimum 30 seconds)
  - Message retention: 14 days maximum
  - Batch size optimization based on message processing time
- **SQS Queue Configuration**:
  ```yaml
  # Standard queue for high throughput
  ProcessingQueue:
    Type: AWS::SQS::Queue
    Properties:
      QueueName: !Sub "${ApplicationName}-processing-queue"
      VisibilityTimeoutSeconds: 300  # 6x Lambda timeout (50s)
      MessageRetentionPeriod: 1209600  # 14 days
      ReceiveMessageWaitTimeSeconds: 20  # Long polling
      KmsMasterKeyId: !Ref KMSKey
      RedrivePolicy:
        deadLetterTargetArn: !GetAtt ProcessingDLQ.Arn
        maxReceiveCount: 3
  
  # FIFO queue for ordered processing
  OrderedProcessingQueue:
    Type: AWS::SQS::Queue
    Properties:
      QueueName: !Sub "${ApplicationName}-ordered-processing.fifo"
      FifoQueue: true
      ContentBasedDeduplication: true
      VisibilityTimeoutSeconds: 300
      MessageRetentionPeriod: 1209600
      KmsMasterKeyId: !Ref KMSKey
      RedrivePolicy:
        deadLetterTargetArn: !GetAtt OrderedProcessingDLQ.Arn
        maxReceiveCount: 3
  
  # Lambda event source mapping
  SQSEventSourceMapping:
    Type: AWS::Lambda::EventSourceMapping
    Properties:
      EventSourceArn: !GetAtt ProcessingQueue.Arn
      FunctionName: !Ref ProcessingFunction
      BatchSize: 10
      MaximumBatchingWindowInSeconds: 5
      ReportBatchItemFailures: true
      ScalingConfig:
        MaximumConcurrency: 100
  ```
- **Validation**: Queue configuration testing and message processing verification

#### ESA-003.2 SQS Redrive Policies and Dead Letter Queues
- **Requirement**: SQS queues SHALL implement redrive policies with appropriate DLQ configuration
- **Implementation**:
  - Maximum receive count: 3 attempts for transient errors
  - DLQ message retention: 14 days for analysis and replay
  - DLQ monitoring and alerting for poison messages
  - Automated DLQ processing for message analysis and potential replay
- **Redrive Policy Configuration**:
  ```yaml
  ProcessingDLQ:
    Type: AWS::SQS::Queue
    Properties:
      QueueName: !Sub "${ApplicationName}-processing-dlq"
      MessageRetentionPeriod: 1209600  # 14 days
      KmsMasterKeyId: !Ref KMSKey
  
  ProcessingQueue:
    Type: AWS::SQS::Queue
    Properties:
      QueueName: !Sub "${ApplicationName}-processing-queue"
      RedrivePolicy:
        deadLetterTargetArn: !GetAtt ProcessingDLQ.Arn
        maxReceiveCount: 3
      RedriveAllowPolicy:
        redrivePermission: "allowAll"
        sourceQueueArns:
          - !GetAtt ProcessingDLQ.Arn
  
  # DLQ monitoring alarm
  DLQMessageAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub "${ApplicationName}-dlq-messages"
      AlarmDescription: "Alert when messages appear in DLQ"
      MetricName: ApproximateNumberOfVisibleMessages
      Namespace: AWS/SQS
      Statistic: Sum
      Period: 300
      EvaluationPeriods: 1
      Threshold: 1
      ComparisonOperator: GreaterThanOrEqualToThreshold
      Dimensions:
        - Name: QueueName
          Value: !GetAtt ProcessingDLQ.QueueName
      AlarmActions:
        - !Ref SNSAlarmTopic
  ```
- **Validation**: Redrive policy testing and DLQ message handling verification

#### ESA-003.3 SQS Batch Processing and Partial Failures
- **Requirement**: Lambda functions processing SQS batches SHALL handle partial batch failures
- **Implementation**:
  - ReportBatchItemFailures enabled for granular error handling
  - Individual message processing with error isolation
  - Failed message identification and selective retry
  - Batch size optimization based on processing time and error rates
- **Batch Processing Implementation**:
  ```python
  import json
  import logging
  from typing import Dict, List, Any
  
  logger = logging.getLogger()
  logger.setLevel(logging.INFO)
  
  def lambda_handler(event: Dict[str, Any], context) -> Dict[str, List[Dict[str, str]]]:
      """
      Process SQS batch with partial failure handling
      """
      batch_item_failures = []
      
      for record in event['Records']:
          try:
              # Process individual message
              process_message(record)
              logger.info(f"Successfully processed message: {record['messageId']}")
              
          except Exception as e:
              logger.error(f"Failed to process message {record['messageId']}: {str(e)}")
              
              # Add to batch item failures for retry
              batch_item_failures.append({
                  "itemIdentifier": record['messageId']
              })
      
      # Return failed message IDs for selective retry
      return {
          "batchItemFailures": batch_item_failures
      }
  
  def process_message(record: Dict[str, Any]) -> None:
      """Process individual SQS message"""
      try:
          message_body = json.loads(record['body'])
          
          # Validate message structure
          validate_message(message_body)
          
          # Process business logic
          result = process_business_logic(message_body)
          
          # Store result or trigger downstream processing
          store_result(result)
          
      except ValidationError as e:
          # Don't retry validation errors - send to DLQ
          logger.error(f"Validation error: {str(e)}")
          raise e
      except TransientError as e:
          # Retry transient errors
          logger.warning(f"Transient error: {str(e)}")
          raise e
  ```
- **Validation**: Partial batch failure testing and selective retry verification

### ESA-004: SNS Integration and Subscription Policies

#### ESA-004.1 SNS Topic Configuration and Access Control
- **Requirement**: SNS topics SHALL be configured with appropriate access policies and encryption
- **Implementation**:
  - Customer-managed KMS encryption for message content
  - Resource-based policies for cross-account access
  - Topic naming convention: `{application}-{environment}-{purpose}-topic`
  - Message filtering for subscription-specific delivery
- **SNS Topic Configuration**:
  ```yaml
  NotificationTopic:
    Type: AWS::SNS::Topic
    Properties:
      TopicName: !Sub "${ApplicationName}-${Environment}-notifications"
      DisplayName: !Sub "${ApplicationName} Notifications"
      KmsMasterKeyId: !Ref SNSKMSKey
      DeliveryStatusLogging:
        - Protocol: lambda
          SuccessFeedbackRoleArn: !GetAtt SNSLoggingRole.Arn
          FailureFeedbackRoleArn: !GetAtt SNSLoggingRole.Arn
          SuccessFeedbackSampleRate: 100
  
  # Topic access policy
  TopicPolicy:
    Type: AWS::SNS::TopicPolicy
    Properties:
      Topics:
        - !Ref NotificationTopic
      PolicyDocument:
        Statement:
          - Effect: Allow
            Principal:
              Service: events.amazonaws.com
            Action: sns:Publish
            Resource: !Ref NotificationTopic
          - Effect: Allow
            Principal:
              AWS: !Sub "arn:aws:iam::${AWS::AccountId}:root"
            Action:
              - sns:Subscribe
              - sns:Receive
            Resource: !Ref NotificationTopic
            Condition:
              StringEquals:
                "sns:Protocol": ["lambda", "sqs"]
  ```
- **Validation**: Topic access policy testing and encryption verification

#### ESA-004.2 SNS Subscription Policies and Filtering
- **Requirement**: SNS subscriptions SHALL use message filtering for targeted delivery
- **Implementation**:
  - Message attribute filtering for subscription targeting
  - Subscription confirmation for security (ConfirmSubscription required)
  - Delivery retry policies with exponential backoff
  - Dead letter queues for failed deliveries
- **Subscription Configuration**:
  ```yaml
  # Lambda subscription with filtering
  LambdaSubscription:
    Type: AWS::SNS::Subscription
    Properties:
      TopicArn: !Ref NotificationTopic
      Protocol: lambda
      Endpoint: !GetAtt NotificationProcessor.Arn
      FilterPolicy:
        eventType: ["order.created", "order.updated"]
        priority: ["HIGH", "CRITICAL"]
        region: [!Ref "AWS::Region"]
      RedrivePolicy:
        deadLetterTargetArn: !GetAtt SNSSubscriptionDLQ.Arn
  
  # SQS subscription with different filter
  SQSSubscription:
    Type: AWS::SNS::Subscription
    Properties:
      TopicArn: !Ref NotificationTopic
      Protocol: sqs
      Endpoint: !GetAtt AuditQueue.Arn
      FilterPolicy:
        eventType: ["order.created", "payment.processed"]
        auditRequired: ["true"]
      RedrivePolicy:
        deadLetterTargetArn: !GetAtt SNSSubscriptionDLQ.Arn
  
  # Subscription DLQ
  SNSSubscriptionDLQ:
    Type: AWS::SQS::Queue
    Properties:
      QueueName: !Sub "${ApplicationName}-sns-subscription-dlq"
      MessageRetentionPeriod: 1209600
      KmsMasterKeyId: !Ref KMSKey
  ```
- **Message Publishing with Attributes**:
  ```python
  import boto3
  import json
  
  def publish_notification(topic_arn: str, message: dict, attributes: dict):
      """Publish message to SNS with filtering attributes"""
      sns = boto3.client('sns')
      
      response = sns.publish(
          TopicArn=topic_arn,
          Message=json.dumps(message),
          MessageAttributes={
              'eventType': {
                  'DataType': 'String',
                  'StringValue': attributes.get('eventType', 'unknown')
              },
              'priority': {
                  'DataType': 'String', 
                  'StringValue': attributes.get('priority', 'NORMAL')
              },
              'region': {
                  'DataType': 'String',
                  'StringValue': attributes.get('region', 'us-east-1')
              }
          }
      )
      
      return response['MessageId']
  ```
- **Validation**: Message filtering testing and subscription delivery verification

#### ESA-004.3 SNS Delivery Status Logging and Monitoring
- **Requirement**: SNS topics SHALL have delivery status logging enabled for monitoring
- **Implementation**:
  - CloudWatch Logs integration for delivery success/failure tracking
  - Delivery status logging for Lambda and SQS endpoints
  - CloudWatch metrics and alarms for delivery failures
  - Automated alerting for subscription health monitoring
- **Delivery Status Configuration**:
  ```yaml
  # SNS delivery status logging role
  SNSLoggingRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Statement:
          - Effect: Allow
            Principal:
              Service: sns.amazonaws.com
            Action: sts:AssumeRole
      Policies:
        - PolicyName: SNSLogsDeliveryRolePolicy
          PolicyDocument:
            Statement:
              - Effect: Allow
                Action:
                  - logs:CreateLogGroup
                  - logs:CreateLogStream
                  - logs:PutLogEvents
                Resource: !Sub "arn:aws:logs:${AWS::Region}:${AWS::AccountId}:*"
  
  # CloudWatch alarm for delivery failures
  SNSDeliveryFailureAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub "${ApplicationName}-sns-delivery-failures"
      AlarmDescription: "Alert on SNS delivery failures"
      MetricName: NumberOfNotificationsFailed
      Namespace: AWS/SNS
      Statistic: Sum
      Period: 300
      EvaluationPeriods: 2
      Threshold: 5
      ComparisonOperator: GreaterThanThreshold
      Dimensions:
        - Name: TopicName
          Value: !GetAtt NotificationTopic.TopicName
      AlarmActions:
        - !Ref AlertingTopic
  ```
- **Validation**: Delivery status monitoring and failure alerting verification

### ESA-005: S3 Event Configuration Requirements

#### ESA-005.1 S3 Event Notification Configuration
- **Requirement**: S3 buckets SHALL configure event notifications for Lambda processing with appropriate filtering
- **Implementation**:
  - Event type filtering (ObjectCreated, ObjectRemoved, etc.)
  - Prefix and suffix filtering for targeted processing
  - Multiple destinations (Lambda, SQS, SNS) based on event type
  - Cross-region replication event handling
- **S3 Event Configuration**:
  ```yaml
  # S3 bucket with event notifications
  ProcessingBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub "${ApplicationName}-${Environment}-processing"
      VersioningConfiguration:
        Status: Enabled
      NotificationConfiguration:
        LambdaConfigurations:
          - Event: s3:ObjectCreated:*
            Function: !GetAtt FileProcessorFunction.Arn
            Filter:
              S3Key:
                Rules:
                  - Name: prefix
                    Value: "incoming/"
                  - Name: suffix
                    Value: ".json"
          - Event: s3:ObjectRemoved:*
            Function: !GetAtt CleanupFunction.Arn
            Filter:
              S3Key:
                Rules:
                  - Name: prefix
                    Value: "temp/"
        QueueConfigurations:
          - Event: s3:ObjectCreated:*
            Queue: !GetAtt AuditQueue.Arn
            Filter:
              S3Key:
                Rules:
                  - Name: prefix
                    Value: "audit/"
  
  # Lambda permission for S3 invocation
  S3InvokePermission:
    Type: AWS::Lambda::Permission
    Properties:
      FunctionName: !Ref FileProcessorFunction
      Action: lambda:InvokeFunction
      Principal: s3.amazonaws.com
      SourceArn: !Sub "${ProcessingBucket}/*"
      SourceAccount: !Ref AWS::AccountId
  ```
- **Validation**: S3 event filtering and Lambda invocation testing

#### ESA-005.2 S3 Event Processing Patterns
- **Requirement**: Lambda functions processing S3 events SHALL implement appropriate processing patterns
- **Implementation**:
  - Batch processing for multiple objects in single invocation
  - Idempotency handling for duplicate S3 events
  - Error handling with S3 object tagging for failed processing
  - Large file processing with S3 Select or streaming patterns
- **S3 Event Processing Implementation**:
  ```python
  import boto3
  import json
  import logging
  from urllib.parse import unquote_plus
  
  logger = logging.getLogger()
  logger.setLevel(logging.INFO)
  
  s3_client = boto3.client('s3')
  
  def lambda_handler(event, context):
      """Process S3 events with error handling and idempotency"""
      
      for record in event['Records']:
          try:
              # Extract S3 event details
              bucket = record['s3']['bucket']['name']
              key = unquote_plus(record['s3']['object']['key'])
              event_name = record['eventName']
              
              logger.info(f"Processing {event_name} for s3://{bucket}/{key}")
              
              # Check if already processed (idempotency)
              if is_already_processed(bucket, key):
                  logger.info(f"Object {key} already processed, skipping")
                  continue
              
              # Process based on event type
              if event_name.startswith('ObjectCreated'):
                  process_created_object(bucket, key)
              elif event_name.startswith('ObjectRemoved'):
                  process_removed_object(bucket, key)
              
              # Mark as processed
              mark_as_processed(bucket, key)
              
          except Exception as e:
              logger.error(f"Error processing S3 event: {str(e)}")
              
              # Tag object with error for retry/analysis
              tag_object_with_error(bucket, key, str(e))
              raise e
  
  def process_created_object(bucket: str, key: str):
      """Process newly created S3 object"""
      try:
          # Get object metadata
          response = s3_client.head_object(Bucket=bucket, Key=key)
          content_type = response.get('ContentType', '')
          
          # Process based on content type
          if content_type == 'application/json':
              process_json_file(bucket, key)
          elif content_type.startswith('image/'):
              process_image_file(bucket, key)
          else:
              logger.warning(f"Unsupported content type: {content_type}")
              
      except Exception as e:
          logger.error(f"Error processing created object: {str(e)}")
          raise e
  
  def process_json_file(bucket: str, key: str):
      """Process JSON file with streaming for large files"""
      try:
          # Use S3 Select for large JSON files
          if get_object_size(bucket, key) > 100 * 1024 * 1024:  # 100MB
              process_large_json_with_select(bucket, key)
          else:
              # Standard processing for smaller files
              response = s3_client.get_object(Bucket=bucket, Key=key)
              data = json.loads(response['Body'].read())
              
              # Process JSON data
              process_json_data(data)
              
      except Exception as e:
          logger.error(f"Error processing JSON file: {str(e)}")
          raise e
  
  def is_already_processed(bucket: str, key: str) -> bool:
      """Check if object was already processed using tags"""
      try:
          response = s3_client.get_object_tagging(Bucket=bucket, Key=key)
          tags = {tag['Key']: tag['Value'] for tag in response['TagSet']}
          return tags.get('ProcessingStatus') == 'COMPLETED'
      except s3_client.exceptions.NoSuchKey:
          return False
      except Exception:
          return False
  
  def mark_as_processed(bucket: str, key: str):
      """Mark object as processed using tags"""
      s3_client.put_object_tagging(
          Bucket=bucket,
          Key=key,
          Tagging={
              'TagSet': [
                  {'Key': 'ProcessingStatus', 'Value': 'COMPLETED'},
                  {'Key': 'ProcessedAt', 'Value': str(int(time.time()))}
              ]
          }
      )
  ```
- **Validation**: S3 event processing testing and error handling verification

#### ESA-005.3 S3 Cross-Region Replication Event Handling
- **Requirement**: S3 buckets with cross-region replication SHALL handle replication events appropriately
- **Implementation**:
  - Separate event handling for source and destination buckets
  - Replication status monitoring and failure handling
  - Avoid processing loops in multi-region setups
  - Replication metrics and alerting for data consistency
- **Cross-Region Event Configuration**:
  ```yaml
  # Source bucket with replication
  SourceBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub "${ApplicationName}-${Environment}-source"
      ReplicationConfiguration:
        Role: !GetAtt ReplicationRole.Arn
        Rules:
          - Id: ReplicateToSecondaryRegion
            Status: Enabled
            Prefix: "data/"
            Destination:
              Bucket: !Sub "arn:aws:s3:::${ApplicationName}-${Environment}-replica"
              StorageClass: STANDARD_IA
      NotificationConfiguration:
        LambdaConfigurations:
          - Event: s3:ObjectCreated:*
            Function: !GetAtt SourceProcessorFunction.Arn
            Filter:
              S3Key:
                Rules:
                  - Name: prefix
                    Value: "data/"
  
  # Destination bucket (in different region)
  ReplicaBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub "${ApplicationName}-${Environment}-replica"
      NotificationConfiguration:
        LambdaConfigurations:
          - Event: s3:Replication:*
            Function: !GetAtt ReplicationProcessorFunction.Arn
  ```
- **Validation**: Cross-region replication event handling and consistency verification

---

*This section establishes the event sources and API configuration requirements that ensure reliable, scalable, and secure integration between Lambda functions and various AWS services. The following sections detail specific implementation requirements for observability, data protection, and operational procedures.*
##
 Observability & Operations

### OBS-001: AWS Lambda Powertools Integration

#### OBS-001.1 Lambda Powertools Core Components
- **Requirement**: All Lambda functions SHALL integrate AWS Lambda Powertools for standardized observability
- **Implementation**:
  - Logger for structured JSON logging with correlation IDs
  - Tracer for AWS X-Ray integration and distributed tracing
  - Metrics for custom CloudWatch metrics with EMF (Embedded Metric Format)
  - Event handler decorators for common patterns (API Gateway, EventBridge, SQS)
- **Powertools Integration Example**:
  ```python
  from aws_lambda_powertools import Logger, Tracer, Metrics
  from aws_lambda_powertools.logging import correlation_paths
  from aws_lambda_powertools.metrics import MetricUnit
  from aws_lambda_powertools.event_handler import APIGatewayRestResolver
  
  # Initialize Powertools
  logger = Logger(service="payment-processor")
  tracer = Tracer(service="payment-processor")
  metrics = Metrics(namespace="FinancialServices", service="payment-processor")
  
  app = APIGatewayRestResolver()
  
  @logger.inject_lambda_context(correlation_id_path=correlation_paths.API_GATEWAY_REST)
  @tracer.capture_lambda_handler
  @metrics.log_metrics(capture_cold_start_metric=True)
  def lambda_handler(event, context):
      logger.info("Processing payment request", extra={"request_id": event.get("requestId")})
      
      with tracer.provider.get_tracer().start_as_current_span("payment_validation"):
          result = validate_payment(event)
          
      metrics.add_metric(name="PaymentProcessed", unit=MetricUnit.Count, value=1)
      metrics.add_metadata(key="payment_method", value=event.get("paymentMethod"))
      
      return result
  ```
- **Environment Variables**:
  ```yaml
  Environment:
    Variables:
      POWERTOOLS_SERVICE_NAME: payment-processor
      POWERTOOLS_METRICS_NAMESPACE: FinancialServices
      POWERTOOLS_LOG_LEVEL: INFO
      POWERTOOLS_LOGGER_SAMPLE_RATE: 0.1
      POWERTOOLS_LOGGER_LOG_EVENT: false
      POWERTOOLS_TRACE_MIDDLEWARES: true
  ```
- **Validation**: Powertools integration testing and observability data verification

#### OBS-001.2 Structured JSON Logging Standards
- **Requirement**: All application logs SHALL use structured JSON format with mandatory fields
- **Implementation**:
  - Consistent log schema across all Lambda functions
  - Correlation IDs for request tracing across services
  - Log level standardization (ERROR, WARN, INFO, DEBUG)
  - PII redaction and sensitive data masking
- **Log Schema Requirements**:
  ```json
  {
    "timestamp": "2024-01-15T10:30:00.000Z",
    "level": "INFO",
    "service": "payment-processor",
    "correlation_id": "550e8400-e29b-41d4-a716-446655440000",
    "request_id": "c6af9ac6-7b61-11e6-9a41-93e8deadbeef",
    "function_name": "payment-processor-prod",
    "function_version": "1.2.3",
    "cold_start": false,
    "message": "Payment validation completed",
    "context": {
      "user_id": "user123",
      "transaction_id": "txn456",
      "amount": 100.00,
      "currency": "USD"
    },
    "duration_ms": 150,
    "memory_used_mb": 128
  }
  ```
- **Log Sampling Configuration**:
  ```python
  # Sample 10% of INFO logs, 100% of WARN/ERROR
  logger = Logger(
      service="payment-processor",
      level="INFO",
      sample_rate=0.1,
      log_uncaught_exceptions=True
  )
  
  # Always log errors and warnings
  @logger.inject_lambda_context(log_event=True)
  def lambda_handler(event, context):
      try:
          # Business logic
          result = process_payment(event)
          logger.info("Payment processed successfully", extra={"result": result})
          return result
      except ValidationError as e:
          logger.warning("Payment validation failed", extra={"error": str(e)})
          raise
      except Exception as e:
          logger.error("Unexpected error processing payment", extra={"error": str(e)})
          raise
  ```
- **Validation**: Log format compliance and correlation ID tracking verification

#### OBS-001.3 Correlation ID Management
- **Requirement**: All requests SHALL have correlation IDs for end-to-end tracing
- **Implementation**:
  - Generate correlation ID at API Gateway entry point
  - Propagate correlation ID through all downstream service calls
  - Include correlation ID in all log entries and custom metrics
  - Store correlation ID in Lambda context for cross-service calls
- **Correlation ID Implementation**:
  ```python
  import uuid
  from aws_lambda_powertools import Logger
  from aws_lambda_powertools.logging import correlation_paths
  
  logger = Logger(service="payment-processor")
  
  def generate_correlation_id():
      """Generate UUID4 correlation ID if not present"""
      return str(uuid.uuid4())
  
  @logger.inject_lambda_context(
      correlation_id_path=correlation_paths.API_GATEWAY_REST,
      log_event=False
  )
  def lambda_handler(event, context):
      # Extract or generate correlation ID
      correlation_id = (
          event.get("headers", {}).get("x-correlation-id") or
          event.get("requestContext", {}).get("requestId") or
          generate_correlation_id()
      )
      
      # Set correlation ID in logger context
      logger.set_correlation_id(correlation_id)
      
      # Propagate to downstream services
      downstream_headers = {
          "x-correlation-id": correlation_id,
          "x-request-id": context.aws_request_id
      }
      
      logger.info("Processing request", extra={
          "correlation_id": correlation_id,
          "request_path": event.get("path"),
          "http_method": event.get("httpMethod")
      })
      
      return process_with_correlation(event, downstream_headers)
  ```
- **Validation**: Correlation ID propagation testing and trace continuity verification

### OBS-002: AWS X-Ray Distributed Tracing

#### OBS-002.1 X-Ray Tracing Configuration
- **Requirement**: All Lambda functions SHALL have AWS X-Ray tracing enabled
- **Implementation**:
  - Active tracing enabled on all Lambda functions
  - X-Ray service map for dependency visualization
  - Custom subsegments for external service calls
  - Trace sampling rules for cost optimization
- **X-Ray Configuration**:
  ```yaml
  LambdaFunction:
    Type: AWS::Lambda::Function
    Properties:
      TracingConfig:
        Mode: Active
      Environment:
        Variables:
          _X_AMZN_TRACE_ID: !Ref AWS::NoValue
          AWS_XRAY_TRACING_NAME: payment-processor
          AWS_XRAY_CONTEXT_MISSING: LOG_ERROR
  
  # X-Ray sampling rule for cost optimization
  XRaySamplingRule:
    Type: AWS::XRay::SamplingRule
    Properties:
      SamplingRule:
        RuleName: LambdaProductionSampling
        Priority: 9000
        FixedRate: 0.1
        ReservoirSize: 1
        ServiceName: payment-processor
        ServiceType: AWS::Lambda::Function
        Host: "*"
        HTTPMethod: "*"
        URLPath: "*"
        Version: 1
  ```
- **Powertools X-Ray Integration**:
  ```python
  from aws_lambda_powertools import Tracer
  import boto3
  
  tracer = Tracer(service="payment-processor")
  
  # Automatically trace AWS SDK calls
  tracer.patch(["boto3"])
  
  @tracer.capture_lambda_handler
  def lambda_handler(event, context):
      # Custom subsegment for business logic
      with tracer.provider.get_tracer().start_as_current_span("payment_validation") as subsegment:
          subsegment.set_attribute("payment.amount", event.get("amount"))
          subsegment.set_attribute("payment.currency", event.get("currency"))
          
          result = validate_payment(event)
          
          subsegment.set_attribute("validation.result", result["status"])
          
      # Trace external API calls
      with tracer.provider.get_tracer().start_as_current_span("external_fraud_check") as subsegment:
          fraud_result = call_fraud_detection_api(event)
          subsegment.set_attribute("fraud.risk_score", fraud_result["risk_score"])
      
      return result
  
  @tracer.capture_method
  def validate_payment(payment_data):
      # Method automatically traced
      return {"status": "valid", "transaction_id": "txn123"}
  ```
- **Validation**: X-Ray trace completeness and service map accuracy verification

#### OBS-002.2 Custom Trace Annotations and Metadata
- **Requirement**: X-Ray traces SHALL include custom annotations for filtering and metadata for context
- **Implementation**:
  - Annotations for searchable trace attributes (user_id, transaction_type, error_code)
  - Metadata for detailed context information (request payload, response data)
  - Error capture with stack traces and error details
  - Performance annotations for latency analysis
- **Custom Annotations Implementation**:
  ```python
  from aws_lambda_powertools import Tracer
  from aws_xray_sdk.core import xray_recorder
  
  tracer = Tracer(service="payment-processor")
  
  @tracer.capture_lambda_handler
  def lambda_handler(event, context):
      # Add searchable annotations
      tracer.put_annotation("user_id", event.get("user_id"))
      tracer.put_annotation("payment_method", event.get("payment_method"))
      tracer.put_annotation("transaction_type", event.get("transaction_type"))
      tracer.put_annotation("environment", "production")
      
      # Add detailed metadata
      tracer.put_metadata("request", {
          "amount": event.get("amount"),
          "currency": event.get("currency"),
          "merchant_id": event.get("merchant_id")
      })
      
      try:
          result = process_payment(event)
          
          # Add success metadata
          tracer.put_metadata("response", {
              "transaction_id": result["transaction_id"],
              "status": result["status"],
              "processing_time_ms": result["processing_time"]
          })
          
          tracer.put_annotation("status", "success")
          return result
          
      except Exception as e:
          # Add error annotations and metadata
          tracer.put_annotation("status", "error")
          tracer.put_annotation("error_type", type(e).__name__)
          
          tracer.put_metadata("error", {
              "message": str(e),
              "stack_trace": traceback.format_exc(),
              "error_code": getattr(e, 'error_code', 'UNKNOWN')
          })
          
          raise
  ```
- **Trace Query Examples**:
  ```
  # Find all failed payment transactions
  annotation.status = "error" AND annotation.transaction_type = "payment"
  
  # Find slow transactions for specific user
  annotation.user_id = "user123" AND responsetime > 2
  
  # Find all transactions with specific payment method
  annotation.payment_method = "credit_card" AND service("payment-processor")
  ```
- **Validation**: Annotation searchability and metadata completeness verification

#### OBS-002.3 X-Ray Service Map and Dependency Analysis
- **Requirement**: X-Ray service maps SHALL provide clear visualization of service dependencies
- **Implementation**:
  - Service naming conventions for clear identification
  - Dependency health monitoring and alerting
  - Performance bottleneck identification through service map analysis
  - Integration with CloudWatch dashboards for operational visibility
- **Service Map Configuration**:
  ```python
  # Configure service names for clear service map visualization
  tracer = Tracer(
      service="payment-processor",
      auto_patch=True,  # Automatically patch AWS SDK calls
      patch_modules=["boto3", "requests", "urllib3"]
  )
  
  # Custom service names for external dependencies
  @tracer.capture_method
  def call_external_service(endpoint, payload):
      with tracer.provider.get_tracer().start_as_current_span(
          "external_api_call",
          attributes={
              "service.name": "fraud-detection-api",
              "http.url": endpoint,
              "http.method": "POST"
          }
      ) as span:
          response = requests.post(endpoint, json=payload)
          span.set_attribute("http.status_code", response.status_code)
          span.set_attribute("response.size", len(response.content))
          return response.json()
  ```
- **Validation**: Service map accuracy and dependency relationship verification

### OBS-003: CloudWatch Metrics and Alarms

#### OBS-003.1 Custom CloudWatch Metrics
- **Requirement**: Lambda functions SHALL emit custom business and operational metrics
- **Implementation**:
  - EMF (Embedded Metric Format) for high-cardinality metrics
  - Business metrics (transaction count, revenue, error rates by type)
  - Operational metrics (processing time, queue depth, retry counts)
  - Cost optimization metrics (memory utilization, cold start frequency)
- **Custom Metrics Implementation**:
  ```python
  from aws_lambda_powertools import Metrics
  from aws_lambda_powertools.metrics import MetricUnit
  
  metrics = Metrics(namespace="FinancialServices/PaymentProcessor")
  
  @metrics.log_metrics(capture_cold_start_metric=True)
  def lambda_handler(event, context):
      # Business metrics
      metrics.add_metric(name="PaymentRequests", unit=MetricUnit.Count, value=1)
      metrics.add_metric(name="PaymentAmount", unit=MetricUnit.None, value=event.get("amount", 0))
      
      # Add dimensions for filtering
      metrics.add_metadata(key="payment_method", value=event.get("payment_method"))
      metrics.add_metadata(key="currency", value=event.get("currency"))
      metrics.add_metadata(key="merchant_category", value=event.get("merchant_category"))
      
      start_time = time.time()
      
      try:
          result = process_payment(event)
          
          # Success metrics
          processing_time = (time.time() - start_time) * 1000
          metrics.add_metric(name="PaymentProcessingTime", unit=MetricUnit.Milliseconds, value=processing_time)
          metrics.add_metric(name="PaymentSuccess", unit=MetricUnit.Count, value=1)
          
          return result
          
      except ValidationError as e:
          metrics.add_metric(name="PaymentValidationError", unit=MetricUnit.Count, value=1)
          metrics.add_metadata(key="error_code", value=e.error_code)
          raise
          
      except Exception as e:
          metrics.add_metric(name="PaymentProcessingError", unit=MetricUnit.Count, value=1)
          metrics.add_metadata(key="error_type", value=type(e).__name__)
          raise
  ```
- **EMF Log Format**:
  ```json
  {
    "_aws": {
      "Timestamp": 1640995200000,
      "CloudWatchMetrics": [
        {
          "Namespace": "FinancialServices/PaymentProcessor",
          "Dimensions": [["payment_method"], ["currency", "payment_method"]],
          "Metrics": [
            {"Name": "PaymentRequests", "Unit": "Count"},
            {"Name": "PaymentAmount", "Unit": "None"},
            {"Name": "PaymentProcessingTime", "Unit": "Milliseconds"}
          ]
        }
      ]
    },
    "payment_method": "credit_card",
    "currency": "USD",
    "PaymentRequests": 1,
    "PaymentAmount": 100.50,
    "PaymentProcessingTime": 150.5
  }
  ```
- **Validation**: Custom metrics emission and CloudWatch dashboard integration verification

#### OBS-003.2 CloudWatch Alarms Configuration
- **Requirement**: Critical Lambda functions SHALL have comprehensive CloudWatch alarms
- **Implementation**:
  - Error rate alarms (>1% error rate for 2 consecutive periods)
  - Duration alarms (P99 latency >2x baseline for 3 consecutive periods)
  - Throttle alarms (any throttling events)
  - Dead letter queue alarms (any messages in DLQ)
- **Alarm Configuration**:
  ```yaml
  # Error Rate Alarm
  ErrorRateAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub "${FunctionName}-ErrorRate"
      AlarmDescription: "Lambda function error rate exceeds threshold"
      MetricName: Errors
      Namespace: AWS/Lambda
      Statistic: Sum
      Period: 300
      EvaluationPeriods: 2
      Threshold: 5
      ComparisonOperator: GreaterThanThreshold
      Dimensions:
        - Name: FunctionName
          Value: !Ref LambdaFunction
      AlarmActions:
        - !Ref AlertingTopic
      TreatMissingData: notBreaching
  
  # Duration Alarm (P99 latency)
  DurationAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub "${FunctionName}-Duration"
      AlarmDescription: "Lambda function duration exceeds threshold"
      MetricName: Duration
      Namespace: AWS/Lambda
      ExtendedStatistic: p99
      Period: 300
      EvaluationPeriods: 3
      Threshold: 5000  # 5 seconds
      ComparisonOperator: GreaterThanThreshold
      Dimensions:
        - Name: FunctionName
          Value: !Ref LambdaFunction
      AlarmActions:
        - !Ref AlertingTopic
  
  # Throttle Alarm
  ThrottleAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub "${FunctionName}-Throttles"
      AlarmDescription: "Lambda function is being throttled"
      MetricName: Throttles
      Namespace: AWS/Lambda
      Statistic: Sum
      Period: 300
      EvaluationPeriods: 1
      Threshold: 0
      ComparisonOperator: GreaterThanThreshold
      Dimensions:
        - Name: FunctionName
          Value: !Ref LambdaFunction
      AlarmActions:
        - !Ref AlertingTopic
  
  # Dead Letter Queue Alarm
  DLQAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub "${FunctionName}-DLQ"
      AlarmDescription: "Messages in Dead Letter Queue"
      MetricName: ApproximateNumberOfVisibleMessages
      Namespace: AWS/SQS
      Statistic: Maximum
      Period: 300
      EvaluationPeriods: 1
      Threshold: 0
      ComparisonOperator: GreaterThanThreshold
      Dimensions:
        - Name: QueueName
          Value: !GetAtt DeadLetterQueue.QueueName
      AlarmActions:
        - !Ref AlertingTopic
  
  # Custom Business Metric Alarm
  PaymentErrorRateAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub "${FunctionName}-PaymentErrorRate"
      AlarmDescription: "Payment processing error rate exceeds threshold"
      MetricName: PaymentProcessingError
      Namespace: FinancialServices/PaymentProcessor
      Statistic: Sum
      Period: 300
      EvaluationPeriods: 2
      Threshold: 10
      ComparisonOperator: GreaterThanThreshold
      AlarmActions:
        - !Ref AlertingTopic
  ```
- **Composite Alarms for Complex Scenarios**:
  ```yaml
  ServiceHealthAlarm:
    Type: AWS::CloudWatch::CompositeAlarm
    Properties:
      AlarmName: !Sub "${FunctionName}-ServiceHealth"
      AlarmDescription: "Overall service health based on multiple metrics"
      AlarmRule: !Sub |
        (ALARM("${ErrorRateAlarm}") OR 
         ALARM("${DurationAlarm}") OR 
         ALARM("${ThrottleAlarm}"))
      ActionsEnabled: true
      AlarmActions:
        - !Ref CriticalAlertingTopic
  ```
- **Validation**: Alarm triggering and notification delivery verification

#### OBS-003.3 CloudWatch Dashboards
- **Requirement**: Lambda functions SHALL have operational dashboards for monitoring
- **Implementation**:
  - Function-level dashboards with key metrics
  - Service-level dashboards for business metrics
  - Real-time monitoring with auto-refresh
  - Integration with X-Ray service maps and logs
- **Dashboard Configuration**:
  ```yaml
  LambdaDashboard:
    Type: AWS::CloudWatch::Dashboard
    Properties:
      DashboardName: !Sub "${FunctionName}-Operations"
      DashboardBody: !Sub |
        {
          "widgets": [
            {
              "type": "metric",
              "x": 0, "y": 0, "width": 12, "height": 6,
              "properties": {
                "metrics": [
                  ["AWS/Lambda", "Invocations", "FunctionName", "${LambdaFunction}"],
                  [".", "Errors", ".", "."],
                  [".", "Duration", ".", "."],
                  [".", "Throttles", ".", "."]
                ],
                "period": 300,
                "stat": "Sum",
                "region": "${AWS::Region}",
                "title": "Lambda Function Metrics"
              }
            },
            {
              "type": "metric",
              "x": 12, "y": 0, "width": 12, "height": 6,
              "properties": {
                "metrics": [
                  ["FinancialServices/PaymentProcessor", "PaymentRequests"],
                  [".", "PaymentSuccess"],
                  [".", "PaymentProcessingError"],
                  [".", "PaymentValidationError"]
                ],
                "period": 300,
                "stat": "Sum",
                "region": "${AWS::Region}",
                "title": "Business Metrics"
              }
            },
            {
              "type": "log",
              "x": 0, "y": 6, "width": 24, "height": 6,
              "properties": {
                "query": "SOURCE '/aws/lambda/${LambdaFunction}'\n| fields @timestamp, level, message, correlation_id\n| filter level = \"ERROR\"\n| sort @timestamp desc\n| limit 100",
                "region": "${AWS::Region}",
                "title": "Recent Errors",
                "view": "table"
              }
            }
          ]
        }
  ```
- **Validation**: Dashboard functionality and metric visualization verification

### OBS-004: Log Management and Retention

#### OBS-004.1 CloudWatch Logs Configuration
- **Requirement**: Lambda function logs SHALL be properly configured with retention and encryption
- **Implementation**:
  - Log group creation with KMS encryption
  - Retention period based on data classification (90 days for application logs)
  - Log streaming to centralized logging system for long-term storage
  - Log group tagging for cost allocation and management
- **Log Group Configuration**:
  ```yaml
  LambdaLogGroup:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: !Sub "/aws/lambda/${LambdaFunction}"
      RetentionInDays: 90
      KmsKeyId: !Ref LogsKMSKey
      Tags:
        - Key: Environment
          Value: !Ref Environment
        - Key: Application
          Value: !Ref ApplicationName
        - Key: CostCenter
          Value: !Ref CostCenter
  
  # KMS Key for log encryption
  LogsKMSKey:
    Type: AWS::KMS::Key
    Properties:
      Description: "KMS Key for CloudWatch Logs encryption"
      KeyPolicy:
        Version: '2012-10-17'
        Statement:
          - Sid: Enable CloudWatch Logs
            Effect: Allow
            Principal:
              Service: !Sub "logs.${AWS::Region}.amazonaws.com"
            Action:
              - kms:Encrypt
              - kms:Decrypt
              - kms:ReEncrypt*
              - kms:GenerateDataKey*
              - kms:DescribeKey
            Resource: "*"
            Condition:
              ArnEquals:
                "kms:EncryptionContext:aws:logs:arn": !Sub "arn:aws:logs:${AWS::Region}:${AWS::AccountId}:log-group:/aws/lambda/${LambdaFunction}"
  ```
- **Log Retention Policies**:
  ```yaml
  # Different retention periods based on log type
  ApplicationLogs:
    RetentionInDays: 90  # 3 months for application logs
  
  AuditLogs:
    RetentionInDays: 2557  # 7 years for audit logs
  
  PerformanceLogs:
    RetentionInDays: 456   # 15 months for performance logs
  
  DebugLogs:
    RetentionInDays: 30    # 1 month for debug logs
  ```
- **Validation**: Log retention enforcement and encryption verification

#### OBS-004.2 Log Aggregation and Analysis
- **Requirement**: Logs SHALL be aggregated for centralized analysis and alerting
- **Implementation**:
  - CloudWatch Logs Insights for log analysis and querying
  - Log subscription filters for real-time processing
  - Integration with external SIEM systems for security analysis
  - Automated log parsing and alerting for critical events
- **Log Subscription Filter**:
  ```yaml
  ErrorLogFilter:
    Type: AWS::Logs::SubscriptionFilter
    Properties:
      LogGroupName: !Ref LambdaLogGroup
      FilterPattern: '{ $.level = "ERROR" }'
      DestinationArn: !GetAtt ErrorProcessingFunction.Arn
  
  SecurityLogFilter:
    Type: AWS::Logs::SubscriptionFilter
    Properties:
      LogGroupName: !Ref LambdaLogGroup
      FilterPattern: '{ $.message = "*SECURITY*" || $.message = "*FRAUD*" }'
      DestinationArn: !GetAtt SecurityAnalysisStream.Arn
  ```
- **Log Analysis Queries**:
  ```sql
  -- Find all errors in the last hour
  fields @timestamp, level, message, correlation_id, context.user_id
  | filter level = "ERROR"
  | filter @timestamp > @timestamp - 1h
  | sort @timestamp desc
  
  -- Analyze payment processing performance
  fields @timestamp, duration_ms, context.amount, context.payment_method
  | filter message like /Payment processed/
  | stats avg(duration_ms), max(duration_ms), count() by context.payment_method
  
  -- Security event analysis
  fields @timestamp, message, correlation_id, context
  | filter message like /SECURITY/ or message like /FRAUD/
  | sort @timestamp desc
  ```
- **Validation**: Log aggregation functionality and query performance verification

#### OBS-004.3 Log-based Alerting
- **Requirement**: Critical log events SHALL trigger automated alerts
- **Implementation**:
  - CloudWatch Logs metric filters for error pattern detection
  - Real-time alerting for security events and system failures
  - Alert suppression and deduplication to prevent alert fatigue
  - Integration with incident management systems
- **Metric Filter Configuration**:
  ```yaml
  ErrorMetricFilter:
    Type: AWS::Logs::MetricFilter
    Properties:
      LogGroupName: !Ref LambdaLogGroup
      FilterPattern: '{ $.level = "ERROR" }'
      MetricTransformations:
        - MetricNamespace: "Lambda/Errors"
          MetricName: "ErrorCount"
          MetricValue: "1"
          DefaultValue: 0
  
  SecurityEventFilter:
    Type: AWS::Logs::MetricFilter
    Properties:
      LogGroupName: !Ref LambdaLogGroup
      FilterPattern: '{ $.message = "*SECURITY_VIOLATION*" }'
      MetricTransformations:
        - MetricNamespace: "Security/Events"
          MetricName: "SecurityViolations"
          MetricValue: "1"
          DefaultValue: 0
  
  # Alarm based on metric filter
  SecurityAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub "${FunctionName}-SecurityViolation"
      AlarmDescription: "Security violation detected in logs"
      MetricName: SecurityViolations
      Namespace: Security/Events
      Statistic: Sum
      Period: 300
      EvaluationPeriods: 1
      Threshold: 0
      ComparisonOperator: GreaterThanThreshold
      AlarmActions:
        - !Ref SecurityAlertingTopic
  ```
- **Validation**: Alert triggering and incident response workflow verification

### OBS-005: Operational Runbooks and Procedures

#### OBS-005.1 Incident Response Runbooks
- **Requirement**: Lambda functions SHALL have documented incident response procedures
- **Implementation**:
  - Step-by-step troubleshooting guides for common issues
  - Escalation procedures with contact information and timelines
  - Automated diagnostic scripts and health checks
  - Integration with incident management tools (PagerDuty, ServiceNow)
- **Runbook Structure**:
  ```markdown
  # Lambda Function Incident Response Runbook
  
  ## Incident Types and Response Procedures
  
  ### 1. High Error Rate (>5% errors for 10 minutes)
  
  #### Immediate Actions (0-5 minutes)
  1. Check CloudWatch dashboard for error patterns
  2. Review recent deployments in CodeDeploy console
  3. Check X-Ray service map for downstream service issues
  4. Verify API Gateway and Lambda function health
  
  #### Investigation Steps (5-15 minutes)
  1. Query CloudWatch Logs for error details:
     ```
     fields @timestamp, level, message, correlation_id, context
     | filter level = "ERROR"
     | filter @timestamp > @timestamp - 15m
     | sort @timestamp desc
     ```
  2. Check X-Ray traces for failed requests
  3. Verify downstream service availability
  4. Review recent configuration changes
  
  #### Resolution Actions
  - If deployment-related: Initiate rollback via CodeDeploy
  - If downstream service issue: Engage service owner team
  - If configuration issue: Revert configuration changes
  - If capacity issue: Increase reserved concurrency
  
  #### Escalation
  - 15 minutes: Escalate to Senior Engineer
  - 30 minutes: Escalate to Engineering Manager
  - 60 minutes: Escalate to Director of Engineering
  ```
- **Automated Diagnostic Scripts**:
  ```python
  #!/usr/bin/env python3
  """
  Lambda Function Health Check Script
  """
  import boto3
  import json
  from datetime import datetime, timedelta
  
  def check_lambda_health(function_name):
      """Comprehensive Lambda function health check"""
      cloudwatch = boto3.client('cloudwatch')
      lambda_client = boto3.client('lambda')
      
      # Get function configuration
      function_config = lambda_client.get_function(FunctionName=function_name)
      
      # Check recent metrics
      end_time = datetime.utcnow()
      start_time = end_time - timedelta(minutes=15)
      
      metrics = cloudwatch.get_metric_statistics(
          Namespace='AWS/Lambda',
          MetricName='Errors',
          Dimensions=[{'Name': 'FunctionName', 'Value': function_name}],
          StartTime=start_time,
          EndTime=end_time,
          Period=300,
          Statistics=['Sum']
      )
      
      # Analyze results
      total_errors = sum(point['Sum'] for point in metrics['Datapoints'])
      
      health_report = {
          'function_name': function_name,
          'last_modified': function_config['Configuration']['LastModified'],
          'runtime': function_config['Configuration']['Runtime'],
          'memory_size': function_config['Configuration']['MemorySize'],
          'timeout': function_config['Configuration']['Timeout'],
          'recent_errors': total_errors,
          'health_status': 'HEALTHY' if total_errors == 0 else 'DEGRADED'
      }
      
      return health_report
  ```
- **Validation**: Runbook accuracy and incident response time verification

#### OBS-005.2 On-Call Procedures and Escalation
- **Requirement**: Lambda functions SHALL have defined on-call procedures and escalation paths
- **Implementation**:
  - 24/7 on-call rotation for critical functions
  - Escalation matrix with response time SLAs
  - Automated alert routing based on severity and business hours
  - Integration with communication tools (Slack, Microsoft Teams)
- **On-Call Configuration**:
  ```yaml
  # PagerDuty integration for alerting
  PagerDutyIntegration:
    Type: AWS::SNS::Topic
    Properties:
      TopicName: !Sub "${FunctionName}-pagerduty"
      Subscription:
        - Protocol: https
          Endpoint: https://events.pagerduty.com/integration/YOUR_INTEGRATION_KEY/enqueue
  
  # Slack notification for non-critical alerts
  SlackIntegration:
    Type: AWS::SNS::Topic
    Properties:
      TopicName: !Sub "${FunctionName}-slack"
      Subscription:
        - Protocol: https
          Endpoint: https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK
  ```
- **Escalation Matrix**:
  ```yaml
  EscalationProcedures:
    Critical:
      - Level1: "Immediate PagerDuty alert to on-call engineer"
      - Level2: "15 minutes - Escalate to Senior Engineer"
      - Level3: "30 minutes - Escalate to Engineering Manager"
      - Level4: "60 minutes - Escalate to Director"
    
    Warning:
      - Level1: "Slack notification to team channel"
      - Level2: "30 minutes - Email to team lead"
      - Level3: "2 hours - PagerDuty alert if unresolved"
    
    Info:
      - Level1: "Slack notification during business hours only"
  ```
- **Validation**: Escalation procedure testing and response time measurement

#### OBS-005.3 Maintenance and Operational Procedures
- **Requirement**: Lambda functions SHALL have documented maintenance procedures
- **Implementation**:
  - Regular health checks and performance reviews
  - Capacity planning and scaling procedures
  - Security patching and runtime upgrade procedures
  - Cost optimization and resource cleanup procedures
- **Maintenance Procedures**:
  ```markdown
  # Lambda Function Maintenance Procedures
  
  ## Weekly Health Checks
  1. Review CloudWatch metrics for performance trends
  2. Analyze cost reports and optimization opportunities
  3. Check for security vulnerabilities in dependencies
  4. Verify backup and disaster recovery procedures
  
  ## Monthly Reviews
  1. Performance optimization analysis
  2. Capacity planning review
  3. Security configuration audit
  4. Cost allocation and chargeback reporting
  
  ## Quarterly Activities
  1. Runtime version upgrade planning
  2. Dependency security updates
  3. Disaster recovery testing
  4. Compliance audit preparation
  ```
- **Automated Maintenance Scripts**:
  ```python
  def perform_weekly_health_check(function_name):
      """Automated weekly health check for Lambda function"""
      checks = {
          'performance': check_performance_metrics(function_name),
          'security': check_security_configuration(function_name),
          'cost': analyze_cost_trends(function_name),
          'capacity': check_capacity_utilization(function_name)
      }
      
      # Generate health report
      report = generate_health_report(checks)
      
      # Send to operations team
      send_health_report(report)
      
      return report
  ```
- **Validation**: Maintenance procedure execution and effectiveness verification

---

*This section establishes comprehensive observability and operational requirements that ensure Lambda workloads can be effectively monitored, troubleshot, and maintained in production environments. The following sections detail specific implementation requirements for data protection, CI/CD controls, and compliance frameworks.*