# Lambda Request Flow Architecture Diagrams

This document contains reference architecture diagrams showing Lambda request flows, security boundaries, encryption points, and monitoring touchpoints for production-ready serverless applications.

## 1. API Gateway + Lambda Request Flow

```mermaid
graph TB
    Client[Client Application]
    
    subgraph "Internet Boundary"
        WAF[AWS WAF<br/>- Rate limiting<br/>- IP filtering<br/>- SQL injection protection]
    end
    
    subgraph "AWS API Gateway"
        APIGW[API Gateway<br/>- TLS termination<br/>- Request validation<br/>- Throttling<br/>- Usage plans]
        Auth[Authorizer<br/>- JWT validation<br/>- IAM auth<br/>- Custom auth]
    end
    
    subgraph "VPC Security Boundary" 
        subgraph "Lambda Execution Environment"
            Lambda[Lambda Function<br/>- Code signing verified<br/>- Environment encryption<br/>- X-Ray tracing enabled]
            PowerTools[Lambda Powertools<br/>- Structured logging<br/>- Correlation IDs<br/>- Metrics]
        end
        
        subgraph "VPC Endpoints"
            VPCE_DDB[VPC Endpoint<br/>DynamoDB]
            VPCE_S3[VPC Endpoint<br/>S3]
            VPCE_SM[VPC Endpoint<br/>Secrets Manager]
        end
    end
    
    subgraph "Backend Services"
        DDB[(DynamoDB<br/>- Encryption at rest<br/>- Point-in-time recovery)]
        S3[(S3 Bucket<br/>- Server-side encryption<br/>- Versioning enabled)]
        SM[Secrets Manager<br/>- KMS encryption<br/>- Auto rotation]
        External[External API<br/>- TLS 1.2+<br/>- API key auth]
    end
    
    subgraph "Error Handling"
        DLQ[SQS Dead Letter Queue<br/>- Message retention<br/>- Redrive policy]
        Dest[Lambda Destinations<br/>- Success/Failure routing]
    end
    
    subgraph "Observability Stack"
        CW[CloudWatch<br/>- Metrics & Alarms<br/>- Log aggregation]
        XRay[X-Ray<br/>- Distributed tracing<br/>- Service map]
        SH[Security Hub<br/>- Security findings<br/>- Compliance status]
    end
    
    %% Request Flow
    Client -->|HTTPS/TLS 1.2+| WAF
    WAF -->|Filtered requests| APIGW
    APIGW --> Auth
    Auth -->|Authorized| Lambda
    
    %% Lambda to Backend Services
    Lambda -->|Encrypted connection| VPCE_DDB
    Lambda -->|Encrypted connection| VPCE_S3  
    Lambda -->|Encrypted connection| VPCE_SM
    Lambda -->|HTTPS/TLS 1.2+| External
    
    VPCE_DDB --> DDB
    VPCE_S3 --> S3
    VPCE_SM --> SM
    
    %% Error Handling
    Lambda -.->|On failure| DLQ
    Lambda -.->|Success/Failure| Dest
    
    %% Monitoring & Observability
    Lambda -->|Logs & Metrics| CW
    Lambda -->|Trace data| XRay
    PowerTools -->|Structured logs| CW
    WAF -->|Security events| SH
    APIGW -->|Access logs| CW
    
    %% Styling
    classDef security fill:#ff9999
    classDef encryption fill:#99ccff
    classDef monitoring fill:#99ff99
    classDef vpc fill:#ffcc99
    
    class WAF,Auth,SH security
    class SM,DDB,S3,VPCE_DDB,VPCE_S3,VPCE_SM encryption
    class CW,XRay,PowerTools monitoring
    class Lambda,VPCE_DDB,VPCE_S3,VPCE_SM vpc
```

## 2. EventBridge + Lambda Event-Driven Flow

```mermaid
graph TB
    subgraph "Event Sources"
        S3Event[S3 Event<br/>- Object created/deleted<br/>- Encrypted notification]
        Schedule[EventBridge Schedule<br/>- Cron expressions<br/>- Rate expressions]
        Custom[Custom Application<br/>- Business events<br/>- API calls]
    end
    
    subgraph "Event Processing"
        EB[EventBridge<br/>- Event filtering<br/>- Content-based routing<br/>- Archive & replay]
        
        subgraph "Event Rules"
            Rule1[Rule: S3 Events<br/>- Pattern matching<br/>- Target routing]
            Rule2[Rule: Scheduled Events<br/>- Time-based triggers]
            Rule3[Rule: Custom Events<br/>- Business logic routing]
        end
    end
    
    subgraph "VPC Lambda Environment"
        Lambda1[Processing Lambda<br/>- Idempotent processing<br/>- X-Ray tracing<br/>- Powertools logging]
        Lambda2[Batch Lambda<br/>- Scheduled processing<br/>- Concurrency limits]
        Lambda3[Workflow Lambda<br/>- State management<br/>- Error handling]
    end
    
    subgraph "Downstream Processing"
        SQS[SQS Queue<br/>- FIFO ordering<br/>- Visibility timeout<br/>- DLQ configured]
        SNS[SNS Topic<br/>- Fan-out pattern<br/>- Encryption in transit]
        SF[Step Functions<br/>- Workflow orchestration<br/>- Error retry logic]
    end
    
    subgraph "Error Handling & DLQ"
        DLQ1[Lambda DLQ<br/>- Failed invocations<br/>- Manual inspection]
        DLQ2[SQS DLQ<br/>- Poison messages<br/>- Redrive policy]
        Alarm[CloudWatch Alarms<br/>- DLQ depth monitoring<br/>- Error rate alerts]
    end
    
    subgraph "Monitoring & Observability"
        CWLogs[CloudWatch Logs<br/>- Structured logging<br/>- Log insights queries]
        CWMetrics[CloudWatch Metrics<br/>- Custom metrics<br/>- Business KPIs]
        XRayTrace[X-Ray Tracing<br/>- End-to-end visibility<br/>- Performance analysis]
    end
    
    %% Event Flow
    S3Event --> EB
    Schedule --> EB
    Custom --> EB
    
    EB --> Rule1
    EB --> Rule2  
    EB --> Rule3
    
    Rule1 --> Lambda1
    Rule2 --> Lambda2
    Rule3 --> Lambda3
    
    %% Downstream Processing
    Lambda1 --> SQS
    Lambda2 --> SNS
    Lambda3 --> SF
    
    %% Error Handling
    Lambda1 -.->|On failure| DLQ1
    SQS -.->|Poison messages| DLQ2
    DLQ1 --> Alarm
    DLQ2 --> Alarm
    
    %% Monitoring
    Lambda1 --> CWLogs
    Lambda2 --> CWLogs
    Lambda3 --> CWLogs
    
    Lambda1 --> CWMetrics
    Lambda2 --> CWMetrics
    Lambda3 --> CWMetrics
    
    Lambda1 --> XRayTrace
    Lambda2 --> XRayTrace
    Lambda3 --> XRayTrace
    
    %% Styling
    classDef eventSource fill:#e1f5fe
    classDef processing fill:#f3e5f5
    classDef errorHandling fill:#ffebee
    classDef monitoring fill:#e8f5e8
    
    class S3Event,Schedule,Custom eventSource
    class EB,Rule1,Rule2,Rule3,Lambda1,Lambda2,Lambda3 processing
    class DLQ1,DLQ2,Alarm errorHandling
    class CWLogs,CWMetrics,XRayTrace monitoring
```

## 3. SQS + Lambda Batch Processing Flow

```mermaid
graph TB
    subgraph "Message Sources"
        Producer1[Application A<br/>- Order processing<br/>- Message attributes]
        Producer2[Application B<br/>- Payment events<br/>- Batch uploads]
        Producer3[Upstream Lambda<br/>- Event forwarding<br/>- Error retry]
    end
    
    subgraph "SQS Configuration"
        SQSMain[SQS Main Queue<br/>- Batch size: 10<br/>- Visibility timeout: 6x handler<br/>- Message retention: 14 days]
        
        subgraph "DLQ Configuration"
            SQSDLQ[SQS Dead Letter Queue<br/>- Max receive count: 3<br/>- Message retention: 14 days<br/>- Redrive policy configured]
        end
    end
    
    subgraph "Lambda Processing Environment"
        subgraph "Concurrency Management"
            Reserved[Reserved Concurrency<br/>- Guaranteed capacity<br/>- Throttle protection]
            Provisioned[Provisioned Concurrency<br/>- Pre-warmed instances<br/>- Reduced cold starts]
        end
        
        Lambda[Batch Processing Lambda<br/>- Partial batch failure handling<br/>- Idempotent processing<br/>- Correlation ID tracking]
        
        subgraph "Error Handling Logic"
            Retry[Retry Logic<br/>- Exponential backoff<br/>- Circuit breaker pattern]
            PartialFail[Partial Batch Failure<br/>- Individual message retry<br/>- Batch item failures]
        end
    end
    
    subgraph "Downstream Systems"
        DB[(Database<br/>- Transactional writes<br/>- Idempotency keys)]
        API[External API<br/>- Rate limiting<br/>- Timeout handling]
        S3Store[(S3 Storage<br/>- Processed data<br/>- Audit trail)]
    end
    
    subgraph "Monitoring & Alerting"
        Metrics[CloudWatch Metrics<br/>- Queue depth<br/>- Processing duration<br/>- Error rates]
        
        Alarms[CloudWatch Alarms<br/>- DLQ depth > 0<br/>- Processing errors > 5%<br/>- Queue age > 5 minutes]
        
        Dashboard[CloudWatch Dashboard<br/>- Real-time metrics<br/>- SLA monitoring<br/>- Operational health]
    end
    
    subgraph "Operational Procedures"
        Runbook[DLQ Runbook<br/>- Message inspection<br/>- Replay procedures<br/>- Root cause analysis]
        
        Replay[Message Replay<br/>- Batch redrive<br/>- Individual message retry<br/>- Data validation]
    end
    
    %% Message Flow
    Producer1 -->|Send messages| SQSMain
    Producer2 -->|Send messages| SQSMain
    Producer3 -->|Send messages| SQSMain
    
    SQSMain -->|Poll batch| Lambda
    SQSMain -.->|Max retries exceeded| SQSDLQ
    
    %% Lambda Processing
    Reserved --> Lambda
    Provisioned --> Lambda
    Lambda --> Retry
    Lambda --> PartialFail
    
    %% Downstream Processing
    Lambda --> DB
    Lambda --> API
    Lambda --> S3Store
    
    %% Error Handling
    Retry -.->|Failed retries| SQSDLQ
    PartialFail -.->|Individual failures| SQSMain
    
    %% Monitoring
    SQSMain --> Metrics
    Lambda --> Metrics
    SQSDLQ --> Metrics
    
    Metrics --> Alarms
    Metrics --> Dashboard
    
    %% Operations
    SQSDLQ --> Runbook
    Runbook --> Replay
    Replay --> SQSMain
    
    %% Styling
    classDef source fill:#e3f2fd
    classDef queue fill:#fff3e0
    classDef processing fill:#f1f8e9
    classDef storage fill:#fce4ec
    classDef monitoring fill:#f3e5f5
    classDef operations fill:#e0f2f1
    
    class Producer1,Producer2,Producer3 source
    class SQSMain,SQSDLQ queue
    class Lambda,Reserved,Provisioned,Retry,PartialFail processing
    class DB,API,S3Store storage
    class Metrics,Alarms,Dashboard monitoring
    class Runbook,Replay operations
```

## Security Boundaries and Encryption Points

### Network Security Boundaries
1. **Internet Boundary**: AWS WAF provides the first line of defense
2. **VPC Boundary**: Lambda functions execute within VPC for private resource access
3. **Subnet Isolation**: Private subnets for Lambda, public subnets for NAT Gateway (if needed)
4. **Security Groups**: Restrictive ingress/egress rules for Lambda ENIs

### Encryption Points
1. **Data in Transit**:
   - TLS 1.2+ for all external communications
   - VPC endpoints for AWS service communication
   - Encrypted connections to external APIs

2. **Data at Rest**:
   - Lambda environment variables encrypted with KMS
   - DynamoDB encryption at rest with customer-managed keys
   - S3 server-side encryption with KMS
   - Secrets Manager automatic encryption

3. **Application Layer**:
   - JWT token encryption for API authentication
   - Message payload encryption for sensitive data
   - Database field-level encryption for PII

### Monitoring Touchpoints
1. **Request Tracing**: X-Ray distributed tracing across all components
2. **Structured Logging**: Lambda Powertools for consistent log format
3. **Metrics Collection**: Custom CloudWatch metrics for business KPIs
4. **Security Monitoring**: Security Hub integration for compliance tracking
5. **Operational Dashboards**: Real-time visibility into system health

## DLQ and Destination Routing Patterns

### Dead Letter Queue Configuration
- **SQS DLQ**: For failed message processing with configurable redrive policy
- **Lambda DLQ**: For failed function invocations with manual inspection capability
- **EventBridge DLQ**: For failed event delivery with replay functionality

### Lambda Destinations
- **Success Destinations**: Route successful invocation results to downstream systems
- **Failure Destinations**: Route failed invocations to error handling systems
- **Asynchronous Processing**: Decouple success/failure handling from main processing logic

### Message Replay Strategies
- **Batch Redrive**: Replay all messages from DLQ to main queue
- **Individual Retry**: Selective message replay based on error analysis
- **Circuit Breaker**: Prevent cascade failures during downstream system issues