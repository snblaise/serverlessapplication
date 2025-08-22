# [Checklist Title] - Production Readiness Validation

## Document Information

| Field | Value |
|-------|-------|
| Document Type | Production Readiness Checklist |
| Version | 1.0 |
| Last Updated | [Date] |
| Owner | [Release Management Team] |
| Approval Required | [Yes/No] |

## Checklist Overview

### Purpose
[Description of what this checklist validates]

### Scope
[What systems/components this applies to]

### Completion Criteria
- [ ] All mandatory items marked as "Yes" or "N/A" with justification
- [ ] All evidence links verified and accessible
- [ ] Sign-off obtained from required stakeholders

## Checklist Categories

### Identity & Access Management
| Item | Requirement | Validation | Evidence Link | Status | Notes |
|------|-------------|------------|---------------|--------|-------|
| IAM-001 | Lambda execution role follows least-privilege principle | Review IAM policy, no wildcard permissions | [Link to IAM policy] | ☐ Yes ☐ No ☐ N/A | |
| IAM-002 | Permission boundaries applied to CI/CD roles | Verify boundary policy attachment | [Link to permission boundary] | ☐ Yes ☐ No ☐ N/A | |
| IAM-003 | OIDC authentication configured (no long-lived keys) | Check GitHub Actions configuration | [Link to OIDC config] | ☐ Yes ☐ No ☐ N/A | |

### Code Integrity & Security
| Item | Requirement | Validation | Evidence Link | Status | Notes |
|------|-------------|------------|---------------|--------|-------|
| SEC-001 | Code signing configuration attached to Lambda | Verify CodeSigningConfig ARN | [Link to Lambda config] | ☐ Yes ☐ No ☐ N/A | |
| SEC-002 | Security scanning integrated in CI/CD | Check SAST, SCA, and policy scans | [Link to pipeline config] | ☐ Yes ☐ No ☐ N/A | |
| SEC-003 | Dependency vulnerability scanning enabled | Verify Dependabot or equivalent | [Link to scan results] | ☐ Yes ☐ No ☐ N/A | |

### Secrets & Configuration Management
| Item | Requirement | Validation | Evidence Link | Status | Notes |
|------|-------------|------------|---------------|--------|-------|
| CFG-001 | Secrets stored in AWS Secrets Manager | No hardcoded secrets in code/env vars | [Link to secrets config] | ☐ Yes ☐ No ☐ N/A | |
| CFG-002 | Environment variables encrypted with CMK | Verify KmsKeyArn configuration | [Link to Lambda encryption] | ☐ Yes ☐ No ☐ N/A | |
| CFG-003 | Secret rotation procedures documented | Review rotation runbook | [Link to rotation procedure] | ☐ Yes ☐ No ☐ N/A | |

### Network Security
| Item | Requirement | Validation | Evidence Link | Status | Notes |
|------|-------------|------------|---------------|--------|-------|
| NET-001 | Lambda deployed in VPC (if accessing private resources) | Check VPC configuration | [Link to VPC config] | ☐ Yes ☐ No ☐ N/A | |
| NET-002 | Security groups follow least-privilege | Review inbound/outbound rules | [Link to security groups] | ☐ Yes ☐ No ☐ N/A | |
| NET-003 | API Gateway protected by AWS WAF | Verify WAF association | [Link to WAF config] | ☐ Yes ☐ No ☐ N/A | |

### Runtime & Reliability
| Item | Requirement | Validation | Evidence Link | Status | Notes |
|------|-------------|------------|---------------|--------|-------|
| REL-001 | Lambda timeout configured appropriately | Based on load testing results | [Link to performance tests] | ☐ Yes ☐ No ☐ N/A | |
| REL-002 | Memory allocation optimized | Based on profiling and cost analysis | [Link to sizing analysis] | ☐ Yes ☐ No ☐ N/A | |
| REL-003 | Dead Letter Queue configured | Verify DLQ setup and monitoring | [Link to DLQ config] | ☐ Yes ☐ No ☐ N/A | |
| REL-004 | Concurrency limits configured | Reserved/provisioned concurrency set | [Link to concurrency config] | ☐ Yes ☐ No ☐ N/A | |

### Observability & Monitoring
| Item | Requirement | Validation | Evidence Link | Status | Notes |
|------|-------------|------------|---------------|--------|-------|
| OBS-001 | AWS Lambda Powertools integrated | Verify logging, metrics, tracing | [Link to Powertools config] | ☐ Yes ☐ No ☐ N/A | |
| OBS-002 | X-Ray tracing enabled | Check tracing configuration | [Link to X-Ray config] | ☐ Yes ☐ No ☐ N/A | |
| OBS-003 | CloudWatch alarms configured | Error rate, duration, throttle alarms | [Link to CloudWatch alarms] | ☐ Yes ☐ No ☐ N/A | |
| OBS-004 | Structured logging implemented | JSON format with correlation IDs | [Link to log samples] | ☐ Yes ☐ No ☐ N/A | |

### CI/CD & Deployment
| Item | Requirement | Validation | Evidence Link | Status | Notes |
|------|-------------|------------|---------------|--------|-------|
| CICD-001 | Canary deployment configured | CodeDeploy canary strategy | [Link to deployment config] | ☐ Yes ☐ No ☐ N/A | |
| CICD-002 | Automated rollback triggers | CloudWatch alarm-based rollback | [Link to rollback config] | ☐ Yes ☐ No ☐ N/A | |
| CICD-003 | Lambda aliases configured | Production traffic routing | [Link to alias config] | ☐ Yes ☐ No ☐ N/A | |
| CICD-004 | Environment promotion process | Staging → Production workflow | [Link to promotion process] | ☐ Yes ☐ No ☐ N/A | |

### Disaster Recovery & Business Continuity
| Item | Requirement | Validation | Evidence Link | Status | Notes |
|------|-------------|------------|---------------|--------|-------|
| DR-001 | Multi-AZ deployment strategy | Lambda inherently multi-AZ | [Link to architecture diagram] | ☐ Yes ☐ No ☐ N/A | |
| DR-002 | Cross-region backup strategy (if required) | Backup Lambda code and config | [Link to backup procedure] | ☐ Yes ☐ No ☐ N/A | |
| DR-003 | Recovery procedures documented | RTO/RPO requirements met | [Link to DR runbook] | ☐ Yes ☐ No ☐ N/A | |

### Cost Management & Optimization
| Item | Requirement | Validation | Evidence Link | Status | Notes |
|------|-------------|------------|---------------|--------|-------|
| COST-001 | Cost monitoring and budgets configured | CloudWatch billing alarms | [Link to cost monitoring] | ☐ Yes ☐ No ☐ N/A | |
| COST-002 | Resource tagging strategy implemented | Consistent cost allocation tags | [Link to tagging policy] | ☐ Yes ☐ No ☐ N/A | |
| COST-003 | Performance vs cost optimization | Right-sizing based on metrics | [Link to optimization analysis] | ☐ Yes ☐ No ☐ N/A | |

### Compliance & Governance
| Item | Requirement | Validation | Evidence Link | Status | Notes |
|------|-------------|------------|---------------|--------|-------|
| COMP-001 | AWS Config rules deployed | Conformance pack active | [Link to Config dashboard] | ☐ Yes ☐ No ☐ N/A | |
| COMP-002 | Service Control Policies enforced | Organization-level guardrails | [Link to SCP policies] | ☐ Yes ☐ No ☐ N/A | |
| COMP-003 | Audit logging enabled | CloudTrail and access logs | [Link to audit configuration] | ☐ Yes ☐ No ☐ N/A | |

## Sign-off Section

### Technical Review
- [ ] **Security Team**: [Name] - [Date] - [Signature]
- [ ] **Operations Team**: [Name] - [Date] - [Signature]
- [ ] **Development Team**: [Name] - [Date] - [Signature]

### Management Approval
- [ ] **Release Manager**: [Name] - [Date] - [Signature]
- [ ] **Security Manager**: [Name] - [Date] - [Signature]

### Final Approval
- [ ] **Production Readiness Approved**: [Name] - [Date] - [Signature]

## Notes and Exceptions

[Document any exceptions, compensating controls, or special considerations]

---

**Checklist Usage Instructions**
1. Complete all applicable items before production deployment
2. Provide evidence links for all "Yes" responses
3. Justify all "N/A" responses with business rationale
4. Obtain all required sign-offs before go-live approval
5. Archive completed checklist for audit purposes