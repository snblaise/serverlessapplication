# Production Readiness Checklist

This directory contains the production readiness checklist and validation tools for AWS Lambda workloads in regulated financial services environments.

## Overview

The production readiness checklist ensures that all AWS Lambda functions meet enterprise-grade standards for security, reliability, compliance, and operational excellence before being deployed to production.

## Files

- **`lambda-production-readiness-checklist.md`** - The main checklist document with all validation items
- **`README.md`** - This documentation file

## Validation Scripts

The following scripts in the `scripts/` directory support automated validation:

- **`validate-production-readiness.py`** - Core validation script for AWS configurations
- **`generate-checklist-evidence.py`** - Generates evidence links for checklist items
- **`validate-checklist-compliance.py`** - Comprehensive compliance validation

## Quick Start

### 1. Basic Validation

Validate a Lambda function against production readiness requirements:

```bash
# Basic validation with summary output
python scripts/validate-production-readiness.py my-lambda-function

# Detailed JSON output
python scripts/validate-production-readiness.py my-lambda-function --output json

# Save results to file
python scripts/validate-production-readiness.py my-lambda-function --output-file validation-results.json
```

### 2. Generate Evidence Links

Create a checklist with populated evidence links:

```bash
# Generate checklist with evidence links
python scripts/generate-checklist-evidence.py my-lambda-function --output checklist-my-function.md

# Generate evidence summary
python scripts/generate-checklist-evidence.py my-lambda-function --summary --output evidence-summary.md
```

### 3. Comprehensive Compliance Check

Run full compliance validation against all checklist items:

```bash
# Full compliance check
python scripts/validate-checklist-compliance.py my-lambda-function

# JSON output for integration
python scripts/validate-checklist-compliance.py my-lambda-function --output json --output-file compliance-report.json
```

## Checklist Categories

The production readiness checklist is organized into the following categories:

### 🔐 Identity & Access Management
- **IAM-001**: Least privilege execution roles
- **IAM-002**: Permission boundaries attached
- **IAM-003**: Identity Center federation
- **IAM-004**: OIDC authentication for CI/CD

### 🛡️ Code Integrity & Security
- **SEC-001**: Code signing configuration
- **SEC-002**: Security scanning integration
- **SEC-003**: Dependency vulnerability scanning
- **SEC-004**: Artifact integrity verification

### 🔑 Secrets & Configuration Management
- **CFG-001**: Secrets in AWS Secrets Manager
- **CFG-002**: Parameter Store for non-sensitive config
- **CFG-003**: Environment variable encryption
- **CFG-004**: KMS key rotation enabled

### 🌐 Network Security
- **NET-001**: VPC configuration (if needed)
- **NET-002**: Security groups with least privilege
- **NET-003**: VPC endpoints configured
- **NET-004**: WAF protection for APIs

### 🔌 API & Event Sources
- **API-001**: API Gateway authentication
- **API-002**: HTTPS-only with TLS 1.2+
- **API-003**: Throttling and usage plans
- **EVT-001**: EventBridge rules with filtering
- **SQS-001**: SQS redrive policies

### ⚡ Runtime & Reliability
- **REL-001**: Versioning and aliases
- **REL-002**: CodeDeploy canary deployment
- **REL-003**: Appropriate timeout configuration
- **REL-004**: Optimized memory allocation
- **REL-005**: Concurrency limits configured
- **REL-006**: Dead Letter Queue setup
- **REL-007**: Idempotency implementation

### 📊 Observability & Monitoring
- **OBS-001**: Lambda Powertools integration
- **OBS-002**: X-Ray tracing enabled
- **OBS-003**: CloudWatch alarms configured
- **OBS-004**: Structured logging with correlation IDs
- **OBS-005**: Log retention policies
- **OBS-006**: Operational dashboards

### 🚀 CI/CD & Deployment
- **CICD-001**: GitHub Actions workflow
- **CICD-002**: Code signing in pipeline
- **CICD-003**: Policy validation
- **CICD-004**: Automated rollback

### 🔄 Disaster Recovery
- **DR-001**: Multi-AZ deployment
- **DR-002**: Cross-region backup (if required)
- **DR-003**: RTO/RPO requirements met
- **DR-004**: Runbooks documented

### 💰 Cost Management
- **COST-001**: Cost monitoring configured
- **COST-002**: Resource tagging strategy
- **COST-003**: Performance optimization

### 📋 Compliance & Governance
- **COMP-001**: AWS Config rules deployed
- **COMP-002**: Service Control Policies
- **COMP-003**: Audit logging enabled
- **COMP-004**: Security Hub integration

## Validation Status Meanings

- **✅ PASS** - Requirement is fully met
- **❌ FAIL** - Requirement is not met, blocks production deployment
- **⚠️ WARN** - Requirement partially met or needs attention
- **🔥 ERROR** - Unable to validate due to permissions or configuration issues
- **ℹ️ N/A** - Not applicable to this function or requires manual verification

## Critical Items

The following items are considered critical and must be **PASS** for production deployment:

- **IAM-001**: Least privilege execution roles
- **SEC-001**: Code signing enabled
- **CFG-001**: Secrets in Secrets Manager
- **NET-004**: WAF protection (for internet-facing APIs)
- **REL-002**: Canary deployment configured
- **OBS-003**: CloudWatch alarms configured
- **COMP-001**: AWS Config rules deployed

## Usage Workflows

### Pre-Production Validation

1. **Development Phase**
   ```bash
   # Quick validation during development
   python scripts/validate-production-readiness.py my-function --output summary
   ```

2. **Pre-Deployment**
   ```bash
   # Full compliance check before deployment
   python scripts/validate-checklist-compliance.py my-function --output-file pre-deploy-check.json
   ```

3. **Evidence Collection**
   ```bash
   # Generate checklist with evidence for audit
   python scripts/generate-checklist-evidence.py my-function --output audit-checklist.md
   ```

### Production Readiness Review

1. **Generate Complete Checklist**
   ```bash
   python scripts/generate-checklist-evidence.py my-function --output production-checklist.md
   ```

2. **Run Compliance Validation**
   ```bash
   python scripts/validate-checklist-compliance.py my-function --output summary
   ```

3. **Review and Sign-off**
   - Complete the generated checklist
   - Verify all evidence links
   - Obtain required approvals
   - Archive for audit purposes

### CI/CD Integration

Add validation to your CI/CD pipeline:

```yaml
# GitHub Actions example
- name: Production Readiness Check
  run: |
    python scripts/validate-checklist-compliance.py ${{ env.FUNCTION_NAME }} --output json > compliance-report.json
    
    # Fail if critical items are not met
    if grep -q '"status": "FAIL"' compliance-report.json; then
      echo "❌ Production readiness validation failed"
      exit 1
    fi
```

## Configuration

### AWS Credentials

The validation scripts use standard AWS credential resolution:

1. Environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`)
2. AWS credentials file (`~/.aws/credentials`)
3. IAM roles (for EC2/Lambda execution)
4. AWS CLI profiles

```bash
# Use specific AWS profile
python scripts/validate-production-readiness.py my-function --profile production

# Use specific region
python scripts/validate-production-readiness.py my-function --region us-west-2
```

### Required Permissions

The validation scripts require the following AWS permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "lambda:GetFunction",
        "lambda:ListVersionsByFunction",
        "lambda:ListAliases",
        "lambda:GetFunctionConcurrency",
        "iam:GetRole",
        "iam:ListAttachedRolePolicies",
        "iam:ListRolePolicies",
        "iam:GetPolicy",
        "iam:GetPolicyVersion",
        "iam:GetRolePolicy",
        "iam:ListOpenIDConnectProviders",
        "kms:DescribeKey",
        "kms:GetKeyRotationStatus",
        "secretsmanager:ListSecrets",
        "ssm:DescribeParameters",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeVpcEndpoints",
        "wafv2:ListWebACLs",
        "config:DescribeConfigRules",
        "config:DescribeConformancePacks",
        "cloudwatch:DescribeAlarms",
        "logs:DescribeLogGroups",
        "codedeploy:ListApplications",
        "xray:GetServiceGraph",
        "events:ListRules",
        "sqs:ListQueues",
        "sns:ListTopics"
      ],
      "Resource": "*"
    }
  ]
}
```

## Troubleshooting

### Common Issues

1. **Permission Denied Errors**
   - Verify AWS credentials are configured
   - Check IAM permissions match requirements above
   - Ensure cross-account access if validating resources in different accounts

2. **Function Not Found**
   - Verify function name is correct
   - Check region parameter matches function location
   - Ensure function exists and is accessible

3. **Incomplete Validation Results**
   - Some checks require manual verification (marked as N/A)
   - Cross-service dependencies may not be automatically detectable
   - Review evidence links for manual validation steps

### Debug Mode

Enable verbose logging for troubleshooting:

```bash
# Add debug output (if implemented)
python scripts/validate-production-readiness.py my-function --debug
```

## Integration with Control Matrix

The checklist items directly map to controls in the control matrix (`docs/control-matrix.csv`). Each checklist item includes:

- **Control Reference** - Links to specific control matrix entries
- **Evidence Link** - Direct AWS console links for verification
- **Validation Command** - CLI commands for automated checking
- **Remediation** - Specific steps to address failures

## Compliance Mapping

The checklist supports compliance with:

- **ISO 27001** - Information security management
- **SOC 2** - Service organization controls
- **NIST CSF** - Cybersecurity framework
- **Financial Services** - Regulatory requirements

## Support

For questions or issues with the production readiness checklist:

1. Review this documentation
2. Check the control matrix for detailed requirements
3. Consult the PRR document for comprehensive requirements
4. Contact the Release Management Team for approval processes

---

**Remember**: Production readiness is not just about passing automated checks. It requires careful review of business requirements, risk assessment, and stakeholder approval.