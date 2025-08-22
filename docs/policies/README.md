# Service Control Policies (SCPs) for Lambda Governance

This directory contains Service Control Policies designed to enforce production-grade governance controls for AWS Lambda workloads in regulated environments.

## Policy Files

### scp-lambda-production-governance.json
Comprehensive SCP that combines all Lambda governance controls:
- **Code Signing Enforcement**: Denies Lambda function updates without code signing configuration
- **Regional Restrictions**: Limits Lambda operations to approved regions (us-east-1, us-west-2, eu-west-1)
- **Mandatory Tagging**: Requires Environment, Encryption, and TracingConfig tags
- **API Gateway WAF Protection**: Prevents public API Gateway stages without WAF association

### Individual Policy Files
- `scp-lambda-code-signing.json`: Code signing enforcement only
- `scp-lambda-governance.json`: Regional and tagging restrictions
- `scp-api-gateway-waf.json`: API Gateway WAF requirements

## Implementation

### 1. Attach to Organization Units
```bash
# Attach to production OU
aws organizations attach-policy \
  --policy-id p-xxxxxxxxxx \
  --target-id ou-xxxxxxxxxx \
  --target-type ORGANIZATIONAL_UNIT
```

### 2. Test in Sandbox Environment
Before applying to production, test SCPs in a sandbox account:
```bash
# Create test Lambda without code signing (should fail)
aws lambda create-function \
  --function-name test-function \
  --runtime nodejs18.x \
  --role arn:aws:iam::123456789012:role/test-role \
  --handler index.handler \
  --zip-file fileb://function.zip
```

### 3. Monitor Policy Violations
Use CloudTrail to monitor denied actions:
```json
{
  "eventName": "CreateFunction",
  "errorCode": "AccessDenied",
  "errorMessage": "User is not authorized to perform: lambda:CreateFunction"
}
```

## Policy Controls

| Control | SCP Statement | Enforcement |
|---------|---------------|-------------|
| Code Signing | DenyLambdaUpdateWithoutCodeSigning | Denies lambda:UpdateFunctionCode without CodeSigningConfigArn |
| Regional Restriction | RestrictLambdaToApprovedRegions | Limits Lambda operations to us-east-1, us-west-2, eu-west-1 |
| Mandatory Tags | RequireMandatoryLambdaTags | Requires Environment tag (dev/staging/prod) |
| Encryption Tags | RequireEncryptionConfiguration | Requires Encryption tag on Lambda functions |
| Tracing Tags | RequireTracingConfiguration | Requires TracingConfig tag on Lambda functions |
| WAF Protection | DenyPublicAPIGatewayWithoutWAF | Prevents EDGE API Gateway stages without WAF |

## Compliance Mapping

- **ISO 27001**: A.12.6.1 (Management of technical vulnerabilities)
- **SOC 2**: CC6.1 (Logical and physical access controls)
- **NIST CSF**: PR.AC-4 (Access permissions and authorizations)