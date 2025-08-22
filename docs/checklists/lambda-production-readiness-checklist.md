# AWS Lambda Production Readiness Checklist

## Document Information

| Field | Value |
|-------|-------|
| Document Type | Production Readiness Checklist |
| Version | 1.0 |
| Last Updated | 2025-08-22 |
| Owner | Release Management Team |
| Approval Required | Yes |
| Related Documents | [Control Matrix](../control-matrix.csv), [PRR Document](../prr/lambda-production-readiness-requirements.md) |

## Checklist Overview

### Purpose
This checklist validates that all AWS Lambda production readiness requirements are met before go-live approval. Each item corresponds to specific controls in the control matrix and provides evidence links for audit verification.

### Scope
- AWS Lambda functions and related services (API Gateway, EventBridge, SQS, SNS)
- Production and production-like environments
- CI/CD pipelines and deployment automation
- Security, compliance, and operational controls

### Completion Criteria
- [ ] All mandatory items marked as "Yes" or "N/A" with justification
- [ ] All evidence links verified and accessible
- [ ] Sign-off obtained from required stakeholders
- [ ] Control matrix validation completed

---

## Identity & Access Management

| Item | Requirement | Validation Criteria | Evidence Link | Status | Notes |
|------|-------------|-------------------|---------------|--------|-------|
| **IAM-001** | Lambda execution roles use least privilege | ✓ No wildcard (*) permissions<br>✓ Resource-specific ARNs<br>✓ IAM Access Analyzer clean | [IAM Console → Roles](https://console.aws.amazon.com/iam/home#/roles) | ☐ Yes ☐ No ☐ N/A | _Control: SEC-001.1_ |
| **IAM-002** | Permission boundaries attached to execution roles | ✓ Boundary policy attached<br>✓ Boundary prevents privilege escalation | [IAM Console → Permission Boundaries](https://console.aws.amazon.com/iam/home#/policies) | ☐ Yes ☐ No ☐ N/A | _Control: SEC-001.2_ |
| **IAM-003** | Identity Center federation for human access | ✓ No long-lived access keys<br>✓ MFA enforced<br>✓ Session duration ≤ 8 hours | [Identity Center Console](https://console.aws.amazon.com/singlesignon/home) | ☐ Yes ☐ No ☐ N/A | _Control: SEC-001.3_ |
| **IAM-004** | CI/CD uses OIDC authentication | ✓ GitHub OIDC configured<br>✓ No long-lived keys in workflows | [GitHub Actions Settings](https://github.com/settings/secrets/actions) | ☐ Yes ☐ No ☐ N/A | _Control: SEC-001.3_ |

---

## Code Integrity & Security

| Item | Requirement | Validation Criteria | Evidence Link | Status | Notes |
|------|-------------|-------------------|---------------|--------|-------|
| **SEC-001** | Code signing configuration enabled | ✓ CodeSigningConfig ARN attached<br>✓ UntrustedArtifactOnDeployment: Enforce | [Lambda Console → Code Signing](https://console.aws.amazon.com/lambda/home#/functions) | ☐ Yes ☐ No ☐ N/A | _Control: SEC-003.1_ |
| **SEC-002** | Security scanning in CI/CD pipeline | ✓ SAST, SCA, policy scans enabled<br>✓ Results sent to Security Hub<br>✓ HIGH/CRITICAL findings block deployment | [Security Hub Console](https://console.aws.amazon.com/securityhub/home) | ☐ Yes ☐ No ☐ N/A | _Control: SEC-003.2_ |
| **SEC-003** | Dependency vulnerability scanning | ✓ Dependabot or equivalent enabled<br>✓ Automated dependency updates | [GitHub Security Tab](https://github.com/security) | ☐ Yes ☐ No ☐ N/A | _Control: SEC-003.2_ |
| **SEC-004** | Artifact integrity verification | ✓ SHA256 checksums generated<br>✓ S3 versioning with MFA delete | [S3 Console → Bucket Properties](https://console.aws.amazon.com/s3/home) | ☐ Yes ☐ No ☐ N/A | _Control: SEC-003.2_ |

---

## Secrets & Configuration Management

| Item | Requirement | Validation Criteria | Evidence Link | Status | Notes |
|------|-------------|-------------------|---------------|--------|-------|
| **CFG-001** | Secrets stored in AWS Secrets Manager | ✓ No hardcoded secrets in code<br>✓ Automatic rotation enabled<br>✓ KMS encryption with CMK | [Secrets Manager Console](https://console.aws.amazon.com/secretsmanager/home) | ☐ Yes ☐ No ☐ N/A | _Control: SEC-002.1_ |
| **CFG-002** | Parameter Store for non-sensitive config | ✓ SecureString parameters<br>✓ Customer-managed KMS keys<br>✓ Hierarchical organization | [Systems Manager → Parameter Store](https://console.aws.amazon.com/systems-manager/parameters) | ☐ Yes ☐ No ☐ N/A | _Control: SEC-002.2_ |
| **CFG-003** | Lambda environment variables encrypted | ✓ KmsKeyArn configured<br>✓ Customer-managed KMS key | [Lambda Console → Configuration](https://console.aws.amazon.com/lambda/home#/functions) | ☐ Yes ☐ No ☐ N/A | _Control: SEC-002.3_ |
| **CFG-004** | KMS key rotation enabled | ✓ Annual key rotation enabled<br>✓ Key policies restrict access | [KMS Console → Customer Managed Keys](https://console.aws.amazon.com/kms/home#/kms/keys) | ☐ Yes ☐ No ☐ N/A | _Control: SEC-002.3_ |

---

## Network Security

| Item | Requirement | Validation Criteria | Evidence Link | Status | Notes |
|------|-------------|-------------------|---------------|--------|-------|
| **NET-001** | VPC configuration (if accessing private resources) | ✓ Lambda in private subnets<br>✓ Security groups with minimal access<br>✓ VPC endpoints for AWS services | [VPC Console → Subnets](https://console.aws.amazon.com/vpc/home#subnets) | ☐ Yes ☐ No ☐ N/A | _Control: SEC-004.1_ |
| **NET-002** | Security groups follow least privilege | ✓ Minimal inbound/outbound rules<br>✓ No 0.0.0.0/0 unless required | [EC2 Console → Security Groups](https://console.aws.amazon.com/ec2/home#SecurityGroups) | ☐ Yes ☐ No ☐ N/A | _Control: SEC-004.1_ |
| **NET-003** | VPC endpoints configured | ✓ Gateway endpoints for S3/DynamoDB<br>✓ Interface endpoints for other services | [VPC Console → Endpoints](https://console.aws.amazon.com/vpc/home#Endpoints) | ☐ Yes ☐ No ☐ N/A | _Control: SEC-004.2_ |
| **NET-004** | API Gateway WAF protection | ✓ WAF Web ACL associated<br>✓ Rate limiting configured<br>✓ Core rule set enabled | [WAF Console → Web ACLs](https://console.aws.amazon.com/wafv2/homev2/web-acls) | ☐ Yes ☐ No ☐ N/A | _Control: SEC-005.1_ |

---

## API & Event Sources Configuration

| Item | Requirement | Validation Criteria | Evidence Link | Status | Notes |
|------|-------------|-------------------|---------------|--------|-------|
| **API-001** | API Gateway authentication configured | ✓ Cognito/IAM/Lambda authorizer<br>✓ API keys with usage plans | [API Gateway Console → Authorizers](https://console.aws.amazon.com/apigateway/home#/apis) | ☐ Yes ☐ No ☐ N/A | _Control: SEC-005.2_ |
| **API-002** | HTTPS-only with TLS 1.2+ | ✓ SSL certificate from ACM<br>✓ TLS 1.2 minimum<br>✓ Request validation enabled | [API Gateway Console → Stages](https://console.aws.amazon.com/apigateway/home#/apis) | ☐ Yes ☐ No ☐ N/A | _Control: SEC-005.3_ |
| **API-003** | Throttling and usage plans configured | ✓ Rate limits per API key<br>✓ Burst limits configured<br>✓ Usage plan quotas | [API Gateway Console → Usage Plans](https://console.aws.amazon.com/apigateway/home#/usage-plans) | ☐ Yes ☐ No ☐ N/A | _Control: ESA-001.2_ |
| **EVT-001** | EventBridge rules with proper filtering | ✓ Event pattern filtering<br>✓ DLQ configured for failed events | [EventBridge Console → Rules](https://console.aws.amazon.com/events/home#/rules) | ☐ Yes ☐ No ☐ N/A | _Control: ESA-002.1_ |
| **SQS-001** | SQS redrive policies configured | ✓ DLQ with maxReceiveCount<br>✓ Server-side encryption with CMK | [SQS Console → Queues](https://console.aws.amazon.com/sqs/v2/home#/queues) | ☐ Yes ☐ No ☐ N/A | _Control: ESA-003.1_ |

---

## Runtime & Reliability

| Item | Requirement | Validation Criteria | Evidence Link | Status | Notes |
|------|-------------|-------------------|---------------|--------|-------|
| **REL-001** | Lambda versioning and aliases configured | ✓ $LATEST not used in production<br>✓ LIVE alias for production traffic<br>✓ Semantic versioning | [Lambda Console → Versions](https://console.aws.amazon.com/lambda/home#/functions) | ☐ Yes ☐ No ☐ N/A | _Control: LRR-001.1_ |
| **REL-002** | CodeDeploy canary deployment | ✓ CodeDeploy application configured<br>✓ Canary deployment strategy<br>✓ Automatic rollback on alarms | [CodeDeploy Console → Applications](https://console.aws.amazon.com/codesuite/codedeploy/applications) | ☐ Yes ☐ No ☐ N/A | _Control: LRR-001.3_ |
| **REL-003** | Timeout configured appropriately | ✓ Based on P99 duration + 20%<br>✓ ≤ 30s for API functions<br>✓ Performance testing completed | [Lambda Console → Configuration](https://console.aws.amazon.com/lambda/home#/functions) | ☐ Yes ☐ No ☐ N/A | _Control: LRR-002.3_ |
| **REL-004** | Memory allocation optimized | ✓ AWS Lambda Power Tuning analysis<br>✓ Cost vs performance optimized | [Lambda Console → Configuration](https://console.aws.amazon.com/lambda/home#/functions) | ☐ Yes ☐ No ☐ N/A | _Control: LRR-002.4_ |
| **REL-005** | Concurrency limits configured | ✓ Reserved concurrency set<br>✓ Provisioned concurrency (if needed)<br>✓ Based on load testing | [Lambda Console → Configuration](https://console.aws.amazon.com/lambda/home#/functions) | ☐ Yes ☐ No ☐ N/A | _Control: LRR-002.1_ |
| **REL-006** | Dead Letter Queue configured | ✓ DLQ for async functions<br>✓ 14-day message retention<br>✓ DLQ processing function | [SQS Console → Dead Letter Queues](https://console.aws.amazon.com/sqs/v2/home#/queues) | ☐ Yes ☐ No ☐ N/A | _Control: LRR-003.2_ |
| **REL-007** | Idempotency implemented | ✓ Idempotency tokens<br>✓ DynamoDB storage with TTL<br>✓ Duplicate request handling | [DynamoDB Console → Tables](https://console.aws.amazon.com/dynamodb/home#tables) | ☐ Yes ☐ No ☐ N/A | _Control: LRR-003.1_ |

---

## Observability & Monitoring

| Item | Requirement | Validation Criteria | Evidence Link | Status | Notes |
|------|-------------|-------------------|---------------|--------|-------|
| **OBS-001** | AWS Lambda Powertools integrated | ✓ Structured logging<br>✓ Metrics and tracing<br>✓ Correlation IDs | [CloudWatch Logs → Log Groups](https://console.aws.amazon.com/cloudwatch/home#logsV2:log-groups) | ☐ Yes ☐ No ☐ N/A | _Control: OBS-001.1_ |
| **OBS-002** | X-Ray tracing enabled | ✓ Active tracing configured<br>✓ Service map visible<br>✓ Performance insights | [X-Ray Console → Service Map](https://console.aws.amazon.com/xray/home#/service-map) | ☐ Yes ☐ No ☐ N/A | _Control: OBS-001.2_ |
| **OBS-003** | CloudWatch alarms configured | ✓ Error rate alarms<br>✓ Duration alarms<br>✓ Throttle alarms<br>✓ SNS notifications | [CloudWatch Console → Alarms](https://console.aws.amazon.com/cloudwatch/home#alarmsV2) | ☐ Yes ☐ No ☐ N/A | _Control: OBS-002.2_ |
| **OBS-004** | Structured logging with correlation IDs | ✓ JSON log format<br>✓ Correlation ID in all logs<br>✓ PII redaction | [CloudWatch Logs Insights](https://console.aws.amazon.com/cloudwatch/home#logsV2:logs-insights) | ☐ Yes ☐ No ☐ N/A | _Control: OBS-001.3_ |
| **OBS-005** | Log retention policies configured | ✓ 90 days for application logs<br>✓ 7 years for audit logs<br>✓ Lifecycle policies | [CloudWatch Logs → Log Groups](https://console.aws.amazon.com/cloudwatch/home#logsV2:log-groups) | ☐ Yes ☐ No ☐ N/A | _Control: OBS-003.1_ |
| **OBS-006** | Operational dashboards created | ✓ SLO dashboards<br>✓ Business metrics<br>✓ Technical metrics | [CloudWatch Console → Dashboards](https://console.aws.amazon.com/cloudwatch/home#dashboards) | ☐ Yes ☐ No ☐ N/A | _Control: OBS-002.3_ |

---

## CI/CD & Deployment

| Item | Requirement | Validation Criteria | Evidence Link | Status | Notes |
|------|-------------|-------------------|---------------|--------|-------|
| **CICD-001** | GitHub Actions workflow configured | ✓ Lint, test, build, sign, deploy stages<br>✓ OIDC authentication<br>✓ Environment gates | [GitHub Actions Workflows](https://github.com/actions) | ☐ Yes ☐ No ☐ N/A | _Control: Multiple_ |
| **CICD-002** | Code signing in pipeline | ✓ AWS Signer integration<br>✓ Signature verification<br>✓ Unsigned code blocked | [AWS Signer Console](https://console.aws.amazon.com/signer/home) | ☐ Yes ☐ No ☐ N/A | _Control: SEC-003.1_ |
| **CICD-003** | Policy validation in pipeline | ✓ Checkov configuration<br>✓ terraform-compliance rules<br>✓ Policy violations block deployment | [GitHub Actions → Security](https://github.com/security) | ☐ Yes ☐ No ☐ N/A | _Control: Multiple_ |
| **CICD-004** | Automated rollback configured | ✓ CloudWatch alarm triggers<br>✓ CodeDeploy rollback<br>✓ Health check validation | [CodeDeploy Console → Deployments](https://console.aws.amazon.com/codesuite/codedeploy/deployments) | ☐ Yes ☐ No ☐ N/A | _Control: LRR-001.3_ |

---

## Disaster Recovery & Business Continuity

| Item | Requirement | Validation Criteria | Evidence Link | Status | Notes |
|------|-------------|-------------------|---------------|--------|-------|
| **DR-001** | Multi-AZ deployment | ✓ Lambda inherently multi-AZ<br>✓ Dependencies multi-AZ<br>✓ No single points of failure | [Architecture Diagram](../diagrams/) | ☐ Yes ☐ No ☐ N/A | _Control: NFR-001.2_ |
| **DR-002** | Cross-region backup (if required) | ✓ Code artifacts replicated<br>✓ Configuration backed up<br>✓ Recovery procedures tested | [S3 Console → Cross-Region Replication](https://console.aws.amazon.com/s3/home) | ☐ Yes ☐ No ☐ N/A | _Control: NFR-004.3_ |
| **DR-003** | RTO/RPO requirements met | ✓ RTO ≤ 4 hours for critical<br>✓ RPO ≤ 15 minutes for critical<br>✓ DR testing completed | [DR Test Results](../runbooks/) | ☐ Yes ☐ No ☐ N/A | _Control: NFR-004.1_ |
| **DR-004** | Runbooks documented and tested | ✓ Incident response procedures<br>✓ Recovery procedures<br>✓ Escalation paths | [Runbooks Directory](../runbooks/) | ☐ Yes ☐ No ☐ N/A | _Control: OBS-004.1_ |

---

## Cost Management & Optimization

| Item | Requirement | Validation Criteria | Evidence Link | Status | Notes |
|------|-------------|-------------------|---------------|--------|-------|
| **COST-001** | Cost monitoring configured | ✓ CloudWatch billing alarms<br>✓ Cost per transaction tracking<br>✓ Budget alerts | [Cost Explorer Console](https://console.aws.amazon.com/cost-management/home) | ☐ Yes ☐ No ☐ N/A | _Control: NFR-006.1_ |
| **COST-002** | Resource tagging implemented | ✓ Consistent cost allocation tags<br>✓ Business unit allocation<br>✓ Environment tagging | [Resource Groups Console](https://console.aws.amazon.com/resource-groups/home) | ☐ Yes ☐ No ☐ N/A | _Control: NFR-006.1_ |
| **COST-003** | Performance optimization completed | ✓ Memory right-sizing<br>✓ Concurrency optimization<br>✓ Cost vs performance analysis | [Lambda Power Tuning Results](../optimization/) | ☐ Yes ☐ No ☐ N/A | _Control: NFR-006.2_ |

---

## Compliance & Governance

| Item | Requirement | Validation Criteria | Evidence Link | Status | Notes |
|------|-------------|-------------------|---------------|--------|-------|
| **COMP-001** | AWS Config rules deployed | ✓ Conformance pack active<br>✓ Custom rules configured<br>✓ Compliance dashboard | [Config Console → Conformance Packs](https://console.aws.amazon.com/config/home#/conformance-packs) | ☐ Yes ☐ No ☐ N/A | _Control: Multiple_ |
| **COMP-002** | Service Control Policies enforced | ✓ Lambda governance SCPs<br>✓ Code signing enforcement<br>✓ Region restrictions | [Organizations Console → Policies](https://console.aws.amazon.com/organizations/v2/home/policies) | ☐ Yes ☐ No ☐ N/A | _Control: Multiple_ |
| **COMP-003** | Audit logging enabled | ✓ CloudTrail configured<br>✓ API Gateway access logs<br>✓ VPC Flow Logs | [CloudTrail Console](https://console.aws.amazon.com/cloudtrail/home) | ☐ Yes ☐ No ☐ N/A | _Control: Multiple_ |
| **COMP-004** | Security Hub integration | ✓ Security findings aggregated<br>✓ CI/CD scan results integrated<br>✓ Compliance standards enabled | [Security Hub Console](https://console.aws.amazon.com/securityhub/home) | ☐ Yes ☐ No ☐ N/A | _Control: OBS-005.3_ |

---

## Checklist Summary

### Completion Status
- **Total Items**: 47
- **Completed**: ___
- **Not Applicable**: ___
- **Remaining**: ___

### Critical Items (Must be "Yes" for go-live)
- [ ] IAM-001: Least privilege execution roles
- [ ] SEC-001: Code signing enabled
- [ ] CFG-001: Secrets in Secrets Manager
- [ ] NET-004: WAF protection (for internet-facing APIs)
- [ ] REL-002: Canary deployment configured
- [ ] OBS-003: CloudWatch alarms configured
- [ ] COMP-001: AWS Config rules deployed

---

## Sign-off Section

### Technical Review
- [ ] **Security Team**: _________________ - Date: _______ - Signature: _________________
- [ ] **Operations Team**: _________________ - Date: _______ - Signature: _________________
- [ ] **Development Team**: _________________ - Date: _______ - Signature: _________________
- [ ] **DevOps Team**: _________________ - Date: _______ - Signature: _________________

### Management Approval
- [ ] **Release Manager**: _________________ - Date: _______ - Signature: _________________
- [ ] **Security Manager**: _________________ - Date: _______ - Signature: _________________
- [ ] **Compliance Officer**: _________________ - Date: _______ - Signature: _________________

### Final Approval
- [ ] **Production Readiness Approved**: _________________ - Date: _______ - Signature: _________________

---

## Notes and Exceptions

**Document any exceptions, compensating controls, or special considerations:**

_[Space for notes]_

---

## Validation Instructions

1. **Pre-Checklist**: Ensure all development and testing is complete
2. **Evidence Collection**: Gather all evidence links and verify accessibility
3. **Team Review**: Complete technical review with all required teams
4. **Control Validation**: Cross-reference with control matrix for completeness
5. **Management Sign-off**: Obtain all required approvals
6. **Archive**: Store completed checklist for audit purposes

**For questions or clarification, contact the Release Management Team.**