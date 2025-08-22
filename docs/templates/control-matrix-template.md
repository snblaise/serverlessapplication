# Control Matrix Template

## Overview
This template provides the structure for mapping Production Readiness Requirements to AWS services, enforcement mechanisms, automated checks, and evidence artifacts.

## Control Matrix Schema

| Column | Description | Required | Format |
|--------|-------------|----------|---------|
| Requirement ID | Reference to specific requirement (e.g., SEC-001.1) | Yes | XXX-###.# |
| Requirement Description | Brief description of the requirement | Yes | Text |
| AWS Service/Feature | Primary AWS service implementing the control | Yes | Service name |
| How Enforced/Configured | Implementation method or configuration | Yes | Text |
| Automated Check/Test | Automated validation method | Yes | Tool/service name |
| Evidence Artifact | Specific evidence location or dashboard | Yes | URL/ARN/Path |
| Compliance Mapping | Regulatory framework mapping | No | ISO 27001, SOC 2, etc. |

## Example Control Matrix Entry

| Requirement ID | Requirement Description | AWS Service/Feature | How Enforced/Configured | Automated Check/Test | Evidence Artifact | Compliance Mapping |
|----------------|------------------------|-------------------|------------------------|-------------------|------------------|-------------------|
| SEC-001.1 | Lambda execution roles must use least privilege | IAM | IAM policy with resource-specific ARNs | IAM Access Analyzer | CloudTrail logs, IAM policy documents | ISO 27001 A.9.2.3 |

## Validation Rules

### Required Fields Validation
- All required columns must be populated
- Requirement ID must follow format: [Category]-[Number].[Subsection]
- AWS Service must be valid AWS service name
- Evidence Artifact must be accessible/verifiable

### Cross-Reference Validation
- Requirement ID must exist in PRR document
- All PRR requirements must be mapped in control matrix
- No duplicate requirement mappings
- Evidence artifacts must be reachable/valid

### Compliance Validation
- Compliance mappings must use standard framework identifiers
- All critical requirements must have compliance mapping
- Evidence must support compliance claims