# Lambda Production Readiness Requirements - Table of Contents

## Executive Documentation
- [Executive Summary](EXECUTIVE_SUMMARY.md) - Business overview and value proposition
- [Implementation Guide](IMPLEMENTATION_GUIDE.md) - Step-by-step deployment instructions
- [Table of Contents](TABLE_OF_CONTENTS.md) - This document

## Core Requirements and Design
- [Production Readiness Requirements](prr/lambda-production-readiness-requirements.md) - Comprehensive PRR document
- [Control Matrix](control-matrix.csv) - Requirements to AWS services mapping
- [Generated Control Matrix](control-matrix-generated.csv) - Automated control validation

## Policy Guardrails and Governance

### Service Control Policies (SCPs)
- [Lambda Code Signing SCP](policies/scp-lambda-code-signing.json) - Enforce code signing
- [Lambda Governance SCP](policies/scp-lambda-governance.json) - General Lambda controls
- [Lambda Production Governance SCP](policies/scp-lambda-production-governance.json) - Production-specific controls
- [API Gateway WAF SCP](policies/scp-api-gateway-waf.json) - API Gateway protection

### AWS Config Rules and Conformance
- [Config Conformance Pack](policies/config-conformance-pack-lambda.yaml) - Lambda compliance rules
- [Config Rule Execution Role](policies/config-rule-execution-role.yaml) - IAM role for Config rules
- [Deploy Config Rules Script](policies/deploy-config-rules.sh) - Automated deployment

### Custom Config Rules
- [Lambda CMK Encryption Check](policies/custom-rules/lambda-cmk-encryption-check.py) - Validate KMS encryption
- [Lambda Code Signing Check](policies/custom-rules/lambda-code-signing-check.py) - Verify code signing
- [Lambda Concurrency Validation](policies/custom-rules/lambda-concurrency-validation-check.py) - Check concurrency settings
- [API Gateway WAF Association Check](policies/custom-rules/api-gateway-waf-association-check.py) - Validate WAF protection

### IAM Permission Boundaries
- [CI/CD Permission Boundary](policies/iam-permission-boundary-cicd.json) - CI/CD role restrictions
- [Lambda Execution Permission Boundary](policies/iam-permission-boundary-lambda-execution.json) - Runtime restrictions
- [Permission Boundaries Stack](policies/permission-boundaries-stack.yaml) - CloudFormation template

### CI/CD Policy Validation
- [Checkov Configuration](policies/ci-cd/.checkov.yaml) - IaC security scanning
- [Permission Boundary README](policies/ci-cd/README-permission-boundary.md) - Implementation guide
- [Validate Permission Boundary Script](policies/ci-cd/validate-permission-boundary.sh) - Testing script
- [Test Permission Boundary](policies/ci-cd/test-permission-boundary.py) - Automated tests
- [Validate Policies Script](policies/ci-cd/validate-policies.sh) - Policy validation

### Terraform Compliance Rules
- [Lambda Production Features](policies/ci-cd/terraform-compliance/lambda-production.feature) - Lambda requirements
- [API Gateway Production Features](policies/ci-cd/terraform-compliance/api-gateway-production.feature) - API Gateway requirements

### Custom Policy Checks
- [Lambda Aliases Check](policies/ci-cd/custom-policies/lambda_aliases.py) - Validate alias configuration
- [Lambda Code Signing Check](policies/ci-cd/custom-policies/lambda_code_signing.py) - Verify signing
- [Lambda Tracing Check](policies/ci-cd/custom-policies/lambda_tracing.py) - Validate X-Ray tracing

## Operational Runbooks and Procedures

### Incident Response
- [Lambda Incident Response](runbooks/lambda-incident-response.md) - Primary incident procedures
- [SQS DLQ Troubleshooting](runbooks/sqs-dlq-troubleshooting.md) - Queue management procedures
- [Incident Flow Diagrams](runbooks/incident-flow-diagrams.md) - Visual decision trees

### Maintenance Procedures
- [Secret Rotation and Runtime Upgrade](runbooks/secret-rotation-runtime-upgrade.md) - Maintenance procedures

## Architecture and Diagrams

### System Architecture
- [Lambda Request Flow](diagrams/lambda-request-flow.md) - End-to-end request processing
- [CI/CD Pipeline Flow](diagrams/cicd-pipeline-flow.md) - Deployment automation flow

## Production Readiness Validation

### Checklists and Validation
- [Checklists README](checklists/README.md) - Checklist overview and usage
- [Lambda Production Readiness Checklist](checklists/lambda-production-readiness-checklist.md) - Comprehensive validation checklist

### Deployment and Operations
- [Deployment Guide](deployment-guide.md) - Production deployment procedures

## Automation Scripts and Tools

### Build and Deployment Scripts
- [Build Lambda Package](../scripts/build-lambda-package.sh) - Package creation
- [Sign Lambda Package](../scripts/sign-lambda-package.sh) - Code signing automation
- [Deploy Lambda Canary](../scripts/deploy-lambda-canary.sh) - Canary deployment
- [Rollback Lambda Deployment](../scripts/rollback-lambda-deployment.sh) - Rollback procedures
- [Validate Lambda Package](../scripts/validate-lambda-package.sh) - Package validation

### Documentation Generation
- [Generate Docs](../scripts/generate-docs.py) - Documentation automation
- [Generate Control Matrix](../scripts/generate-control-matrix.py) - Control matrix generation
- [Validate Control Matrix](../scripts/validate-control-matrix.py) - Matrix validation

### Compliance and Validation
- [Validate Production Readiness](../scripts/validate-production-readiness.py) - Overall validation
- [Validate Checklist Compliance](../scripts/validate-checklist-compliance.py) - Checklist automation
- [Generate Checklist Evidence](../scripts/generate-checklist-evidence.py) - Evidence collection
- [Upload Security Findings](../scripts/upload-security-findings.py) - Security Hub integration

## Testing Framework

### Test Organization
- [Master Test Runner](../tests/master_test_runner.py) - Centralized test execution
- [Tests Makefile](../tests/Makefile) - Test automation

### Documentation Compliance Tests
- [Documentation Compliance Makefile](../tests/documentation-compliance/Makefile) - Test automation
- [Test Runner](../tests/documentation-compliance/test_runner.py) - Test orchestration
- [Audit Trail Validation](../tests/documentation-compliance/test_audit_trail_validation.py) - Audit testing
- [Compliance Mapping](../tests/documentation-compliance/test_compliance_mapping.py) - Mapping validation
- [Cross Reference Validation](../tests/documentation-compliance/test_cross_reference_validation.py) - Reference testing
- [Test Configuration](../tests/documentation-compliance/conftest.py) - Test setup

### Policy Guardrails Tests
- [Policy Guardrails Makefile](../tests/policy-guardrails/Makefile) - Test automation
- [Test Runner](../tests/policy-guardrails/test_runner.py) - Test orchestration
- [Config Rules Tests](../tests/policy-guardrails/test_config_rules.py) - Config rule validation
- [Permission Boundaries Tests](../tests/policy-guardrails/test_permission_boundaries.py) - Boundary testing
- [SCP Enforcement Tests](../tests/policy-guardrails/test_scp_enforcement.py) - SCP validation
- [Test Configuration](../tests/policy-guardrails/conftest.py) - Test setup

### Workflow Integration Tests
- [Workflow Integration Makefile](../tests/workflow-integration/Makefile) - Test automation
- [Test Runner](../tests/workflow-integration/test_runner.py) - Test orchestration
- [Canary Deployment Tests](../tests/workflow-integration/test_canary_deployment.py) - Deployment testing
- [CI/CD Pipeline Tests](../tests/workflow-integration/test_cicd_pipeline.py) - Pipeline validation
- [Code Signing Tests](../tests/workflow-integration/test_code_signing.py) - Signing validation
- [Test Configuration](../tests/workflow-integration/conftest.py) - Test setup

## Templates and Scaffolding

### Document Templates
- [Checklist Template](templates/checklist-template.md) - Checklist creation template
- [Control Matrix Template](templates/control-matrix-template.md) - Matrix template
- [Document Template](templates/document-template.md) - General documentation template
- [Runbook Template](templates/runbook-template.md) - Runbook creation template

## Configuration Files

### Project Configuration
- [Package.json](../package.json) - Node.js dependencies and scripts
- [TypeScript Config](../tsconfig.json) - TypeScript compilation settings
- [Jest Config](../jest.config.js) - Testing framework configuration
- [Jest Setup](../jest.setup.js) - Test environment setup
- [ESLint Config](../.eslintrc.js) - Code linting rules
- [Prettier Config](../.prettierrc) - Code formatting rules

### Source Code
- [Lambda Function](../src/index.js) - Example Lambda implementation
- [Lambda Tests](../src/index.test.js) - Unit tests for Lambda function

## Quick Navigation

### By Role

#### **Security Engineers**
- [Security Baseline Requirements](prr/lambda-production-readiness-requirements.md#security-baseline)
- [Service Control Policies](policies/scp-lambda-code-signing.json)
- [Custom Config Rules](policies/custom-rules/)
- [Security Testing](../tests/policy-guardrails/)

#### **DevOps Engineers**
- [CI/CD Implementation](IMPLEMENTATION_GUIDE.md#phase-2-cicd-pipeline-implementation-week-3-4)
- [Deployment Scripts](../scripts/)
- [Pipeline Flow Diagrams](diagrams/cicd-pipeline-flow.md)
- [Workflow Tests](../tests/workflow-integration/)

#### **Operations Teams**
- [Incident Response Runbooks](runbooks/lambda-incident-response.md)
- [Production Readiness Checklist](checklists/lambda-production-readiness-checklist.md)
- [Troubleshooting Procedures](runbooks/sqs-dlq-troubleshooting.md)
- [Deployment Guide](deployment-guide.md)

#### **Compliance Officers**
- [Control Matrix](control-matrix.csv)
- [Compliance Mapping Tests](../tests/documentation-compliance/test_compliance_mapping.py)
- [Audit Trail Validation](../tests/documentation-compliance/test_audit_trail_validation.py)
- [Evidence Collection](../scripts/generate-checklist-evidence.py)

#### **Architects**
- [Production Readiness Requirements](prr/lambda-production-readiness-requirements.md)
- [Architecture Diagrams](diagrams/)
- [Implementation Guide](IMPLEMENTATION_GUIDE.md)
- [Executive Summary](EXECUTIVE_SUMMARY.md)

### By Implementation Phase

#### **Phase 1: Foundation**
- [Policy Guardrails](policies/)
- [Permission Boundaries](policies/iam-permission-boundary-cicd.json)
- [Config Rules](policies/config-conformance-pack-lambda.yaml)

#### **Phase 2: CI/CD**
- [GitHub Actions Setup](IMPLEMENTATION_GUIDE.md#step-21-configure-github-oidc-provider)
- [Code Signing](../scripts/sign-lambda-package.sh)
- [Canary Deployment](../scripts/deploy-lambda-canary.sh)

#### **Phase 3: Operations**
- [Monitoring Setup](IMPLEMENTATION_GUIDE.md#step-31-deploy-cloudwatch-alarms)
- [Runbooks](runbooks/)
- [Incident Response](runbooks/lambda-incident-response.md)

#### **Phase 4: Validation**
- [Testing Framework](../tests/)
- [Compliance Validation](../scripts/validate-checklist-compliance.py)
- [Production Readiness](checklists/lambda-production-readiness-checklist.md)

---

**Document Version**: 1.0  
**Last Updated**: $(date)  
**Maintained By**: Platform Engineering Team  
**Review Cycle**: Quarterly