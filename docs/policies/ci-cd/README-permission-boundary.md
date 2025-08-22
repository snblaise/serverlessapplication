# CI/CD IAM Permission Boundary Implementation

## Overview

This document describes the implementation of IAM permission boundaries for CI/CD roles in AWS Lambda serverless workloads. The permission boundary provides defense-in-depth security by limiting the maximum permissions that CI/CD roles can have, even if they are granted broader policies.

## Architecture

The permission boundary implements a "guardrails" approach where:
- CI/CD roles can perform necessary deployment actions
- Dangerous or non-compliant actions are explicitly denied
- Production access is restricted to specific principals
- All actions require proper tagging and regional compliance

## Security Controls Implemented

### 1. Lambda Function Management
- **Allowed Actions**: Standard Lambda lifecycle operations (create, update, delete, alias management, concurrency configuration)
- **Restrictions**: 
  - Must include required tags (`ManagedBy: CI/CD`, `Environment: dev/staging/prod`)
  - Limited to approved regions (`us-east-1`, `us-west-2`, `eu-west-1`)
  - Function URLs are explicitly denied
  - Code signing is mandatory for all deployments

### 2. Code Integrity Controls
- **Unsigned Code Denial**: All `lambda:UpdateFunctionCode` and `lambda:CreateFunction` actions require a valid `CodeSigningConfigArn`
- **Function URL Prohibition**: `lambda:CreateFunctionUrlConfig` and `lambda:UpdateFunctionUrlConfig` are explicitly denied
- **Artifact Integrity**: Only signed code can be deployed to Lambda functions

### 3. IAM Restrictions
- **Wildcard Denial**: IAM actions with wildcards are restricted to specific AWS service principals
- **High Privilege Denial**: User management, policy creation, and organizational actions are denied
- **Role Management**: Limited to Lambda execution and CodeDeploy roles with proper naming conventions
- **Permission Boundary Enforcement**: All created roles must have the Lambda execution permission boundary attached

### 4. Production Access Controls
- **Principal Restrictions**: Production environment access limited to specific GitHub Actions and CodeDeploy principals
- **Resource Deletion Protection**: Production resources cannot be deleted except by deployment managers
- **Environment Segregation**: Clear separation between dev, staging, and production environments

### 5. Compliance and Governance
- **Mandatory Tagging**: All resources must include `Environment` and `ManagedBy` tags
- **Regional Restrictions**: Actions limited to approved AWS regions
- **Encryption in Transit**: All API calls must use HTTPS/TLS
- **Audit Trail**: All actions are logged and traceable

## File Structure

```
docs/policies/ci-cd/
├── iam-permission-boundary-cicd.json      # Main permission boundary policy
├── test-permission-boundary.py            # Automated test suite
├── validate-permission-boundary.sh        # Manual validation script
└── README-permission-boundary.md          # This documentation
```

## Permission Boundary Policy Structure

### Allow Statements
1. **AllowLambdaManagement**: Core Lambda operations with tagging and regional restrictions
2. **AllowCodeDeployForLambda**: CodeDeploy operations for canary deployments
3. **AllowAPIGatewayManagement**: API Gateway operations for Lambda integrations
4. **AllowCloudFormationManagement**: Infrastructure as Code operations with naming restrictions
5. **AllowS3ForArtifacts**: Access to deployment artifact buckets
6. **AllowCloudWatchLogs**: Lambda logging operations
7. **AllowIAMRoleManagement**: Limited IAM role operations for service roles

### Deny Statements
1. **DenyLambdaFunctionUrls**: Prevents creation of public Lambda URLs
2. **DenyUnsignedCodeDeployment**: Enforces code signing for all deployments
3. **RestrictIAMWildcardActions**: Limits IAM wildcard permissions
4. **DenyHighPrivilegeActions**: Blocks dangerous administrative actions
5. **EnforceEncryptionInTransit**: Requires HTTPS for all API calls
6. **RestrictResourceDeletion**: Protects production resources from deletion
7. **RequireMandatoryTags**: Enforces tagging compliance
8. **DenyProductionAccessOutsideWorkflow**: Restricts production access

## Usage Instructions

### 1. Deploy Permission Boundary Policy

```bash
# Create the permission boundary policy
aws iam create-policy \
    --policy-name CICDPermissionBoundary \
    --policy-document file://docs/policies/iam-permission-boundary-cicd.json \
    --description "Permission boundary for CI/CD roles"
```

### 2. Create CI/CD Role with Permission Boundary

```bash
# Create CI/CD role with permission boundary
aws iam create-role \
    --role-name github-actions-cicd-role \
    --assume-role-policy-document file://trust-policy.json \
    --permissions-boundary arn:aws:iam::ACCOUNT-ID:policy/CICDPermissionBoundary \
    --tags Key=ManagedBy,Value=CI/CD Key=Environment,Value=prod
```

### 3. Attach Necessary Policies

```bash
# Attach required policies to the CI/CD role
aws iam attach-role-policy \
    --role-name github-actions-cicd-role \
    --policy-arn arn:aws:iam::aws:policy/AWSLambda_FullAccess

aws iam attach-role-policy \
    --role-name github-actions-cicd-role \
    --policy-arn arn:aws:iam::aws:policy/AWSCodeDeployRoleForLambda
```

## Testing and Validation

### Automated Testing

Run the Python test suite to validate policy logic:

```bash
cd docs/policies/ci-cd
pip install pytest boto3 moto
python -m pytest test-permission-boundary.py -v
```

### Manual Validation

Execute the validation script in a real AWS environment:

```bash
cd docs/policies/ci-cd
./validate-permission-boundary.sh
```

### Test Scenarios Covered

1. **Positive Tests** (should succeed):
   - Lambda function creation with proper tags
   - CodeDeploy operations
   - CloudFormation stack operations with proper naming
   - S3 access to deployment artifact buckets
   - CloudWatch Logs operations

2. **Negative Tests** (should fail):
   - Lambda function URL creation
   - Unsigned code deployment
   - IAM user/policy creation
   - Cross-region access to non-approved regions
   - Resource creation without mandatory tags
   - High-privilege administrative actions

## Compliance Mapping

| Control | Requirement | Implementation |
|---------|-------------|----------------|
| Code Integrity | All code must be signed | `DenyUnsignedCodeDeployment` statement |
| Least Privilege | Minimal necessary permissions | Restrictive allow statements with conditions |
| Environment Segregation | Production access controls | `DenyProductionAccessOutsideWorkflow` statement |
| Audit Trail | All actions logged | Encryption in transit enforcement |
| Regional Compliance | Approved regions only | Regional restrictions in conditions |
| Tagging Governance | Mandatory resource tagging | `RequireMandatoryTags` statements |

## Troubleshooting

### Common Issues

1. **Access Denied Errors**
   - Verify the role has the permission boundary attached
   - Check that required tags are present in requests
   - Ensure actions are performed in approved regions

2. **Code Deployment Failures**
   - Verify code signing configuration is attached to Lambda function
   - Check that deployment artifacts are properly signed

3. **Resource Creation Failures**
   - Ensure all mandatory tags are included
   - Verify resource naming follows approved patterns
   - Check regional restrictions

### Debugging Steps

1. **Check CloudTrail Logs**
   ```bash
   aws logs filter-log-events \
       --log-group-name CloudTrail/IAMEvents \
       --filter-pattern "{ $.errorCode = \"AccessDenied\" }"
   ```

2. **Validate Policy Syntax**
   ```bash
   aws iam simulate-principal-policy \
       --policy-source-arn arn:aws:iam::ACCOUNT:role/ROLE-NAME \
       --action-names lambda:CreateFunction \
       --resource-arns "*"
   ```

3. **Test Permission Boundary**
   ```bash
   # Run validation script with debug output
   AWS_CLI_DEBUG=1 ./validate-permission-boundary.sh
   ```

## Maintenance

### Regular Reviews
- Review permission boundary effectiveness quarterly
- Update allowed regions as business requirements change
- Validate test scenarios against new AWS services
- Update documentation for policy changes

### Policy Updates
1. Test changes in development environment first
2. Run full validation suite before production deployment
3. Update version tags and change documentation
4. Coordinate with security team for approval

### Monitoring
- Set up CloudWatch alarms for permission boundary violations
- Monitor CloudTrail for denied actions
- Regular compliance audits using AWS Config rules
- Security Hub integration for centralized monitoring

## Security Considerations

### Defense in Depth
- Permission boundaries are one layer of security
- Combine with SCPs, resource-based policies, and monitoring
- Regular security assessments and penetration testing

### Incident Response
- Documented procedures for permission boundary violations
- Automated alerting for suspicious activities
- Rollback procedures for emergency access needs

### Access Reviews
- Quarterly review of CI/CD role permissions
- Annual audit of permission boundary effectiveness
- Regular validation of compliance controls