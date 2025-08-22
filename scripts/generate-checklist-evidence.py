#!/usr/bin/env python3
"""
Production Readiness Checklist Evidence Generator

This script generates evidence links and validation data for the production
readiness checklist by cross-referencing with the control matrix and AWS
configurations.
"""

import boto3
import json
import csv
import sys
import argparse
from datetime import datetime
from typing import Dict, List, Any, Optional
from urllib.parse import quote
import re


class ChecklistEvidenceGenerator:
    """Generates evidence links and validation data for production readiness checklist"""
    
    def __init__(self, region: str = 'us-east-1', profile: Optional[str] = None):
        """Initialize AWS clients and load control matrix"""
        try:
            if profile:
                session = boto3.Session(profile_name=profile)
            else:
                session = boto3.Session()
            
            self.region = region
            self.session = session
            
            # Get account ID
            sts_client = session.client('sts')
            self.account_id = sts_client.get_caller_identity()['Account']
            
            # Load control matrix
            self.control_matrix = self._load_control_matrix()
            
        except Exception as e:
            print(f"ERROR: Failed to initialize: {e}")
            sys.exit(1)
    
    def _load_control_matrix(self) -> List[Dict[str, str]]:
        """Load control matrix from CSV file"""
        try:
            with open('docs/control-matrix.csv', 'r') as f:
                reader = csv.DictReader(f)
                return list(reader)
        except FileNotFoundError:
            print("WARNING: Control matrix not found at docs/control-matrix.csv")
            return []
        except Exception as e:
            print(f"ERROR: Failed to load control matrix: {e}")
            return []
    
    def generate_evidence_links(self, function_name: str) -> Dict[str, Dict[str, str]]:
        """Generate evidence links for all checklist items"""
        
        evidence_links = {}
        
        # Identity & Access Management
        evidence_links.update(self._generate_iam_evidence(function_name))
        
        # Code Integrity & Security
        evidence_links.update(self._generate_security_evidence(function_name))
        
        # Secrets & Configuration Management
        evidence_links.update(self._generate_config_evidence(function_name))
        
        # Network Security
        evidence_links.update(self._generate_network_evidence(function_name))
        
        # API & Event Sources
        evidence_links.update(self._generate_api_evidence(function_name))
        
        # Runtime & Reliability
        evidence_links.update(self._generate_runtime_evidence(function_name))
        
        # Observability & Monitoring
        evidence_links.update(self._generate_observability_evidence(function_name))
        
        # CI/CD & Deployment
        evidence_links.update(self._generate_cicd_evidence(function_name))
        
        # Disaster Recovery
        evidence_links.update(self._generate_dr_evidence(function_name))
        
        # Cost Management
        evidence_links.update(self._generate_cost_evidence(function_name))
        
        # Compliance & Governance
        evidence_links.update(self._generate_compliance_evidence(function_name))
        
        return evidence_links
    
    def _generate_iam_evidence(self, function_name: str) -> Dict[str, Dict[str, str]]:
        """Generate IAM evidence links"""
        return {
            'IAM-001': {
                'console_link': f"https://console.aws.amazon.com/iam/home#/roles",
                'description': "IAM Roles Console - Verify execution role has no wildcard permissions",
                'validation_command': f"aws iam get-role --role-name $(aws lambda get-function --function-name {function_name} --query 'Configuration.Role' --output text | cut -d'/' -f2)",
                'control_reference': "SEC-001.1"
            },
            'IAM-002': {
                'console_link': f"https://console.aws.amazon.com/iam/home#/policies",
                'description': "IAM Permission Boundaries - Verify boundary policy is attached",
                'validation_command': f"aws iam get-role --role-name $(aws lambda get-function --function-name {function_name} --query 'Configuration.Role' --output text | cut -d'/' -f2) --query 'Role.PermissionsBoundary'",
                'control_reference': "SEC-001.2"
            },
            'IAM-003': {
                'console_link': f"https://console.aws.amazon.com/singlesignon/home",
                'description': "Identity Center Console - Verify federation is configured",
                'validation_command': "aws sso-admin list-instances",
                'control_reference': "SEC-001.3"
            },
            'IAM-004': {
                'console_link': "https://github.com/settings/secrets/actions",
                'description': "GitHub Actions Settings - Verify OIDC configuration",
                'validation_command': "Check GitHub repository settings for OIDC provider configuration",
                'control_reference': "SEC-001.3"
            }
        }
    
    def _generate_security_evidence(self, function_name: str) -> Dict[str, Dict[str, str]]:
        """Generate security evidence links"""
        return {
            'SEC-001': {
                'console_link': f"https://{self.region}.console.aws.amazon.com/lambda/home?region={self.region}#/functions/{function_name}?tab=configuration",
                'description': "Lambda Configuration - Verify Code Signing Configuration is attached",
                'validation_command': f"aws lambda get-function --function-name {function_name} --query 'Configuration.CodeSigningConfigArn'",
                'control_reference': "SEC-003.1"
            },
            'SEC-002': {
                'console_link': f"https://{self.region}.console.aws.amazon.com/securityhub/home?region={self.region}#/findings",
                'description': "Security Hub Console - Verify security scan results are integrated",
                'validation_command': f"aws securityhub get-findings --filters 'ResourceId=[{{\"Value\":\"{function_name}\",\"Comparison\":\"EQUALS\"}}]'",
                'control_reference': "SEC-003.2"
            },
            'SEC-003': {
                'console_link': "https://github.com/security/dependabot",
                'description': "GitHub Dependabot - Verify dependency scanning is enabled",
                'validation_command': "Check .github/dependabot.yml configuration file",
                'control_reference': "SEC-003.2"
            },
            'SEC-004': {
                'console_link': f"https://s3.console.aws.amazon.com/s3/home?region={self.region}",
                'description': "S3 Console - Verify artifact storage has versioning and MFA delete",
                'validation_command': "aws s3api get-bucket-versioning --bucket <deployment-artifacts-bucket>",
                'control_reference': "SEC-003.2"
            }
        }
    
    def _generate_config_evidence(self, function_name: str) -> Dict[str, Dict[str, str]]:
        """Generate configuration management evidence links"""
        return {
            'CFG-001': {
                'console_link': f"https://{self.region}.console.aws.amazon.com/secretsmanager/home?region={self.region}#/listSecrets",
                'description': "Secrets Manager Console - Verify secrets are stored with rotation",
                'validation_command': f"aws secretsmanager list-secrets --query 'SecretList[?contains(Name, `{function_name}`)]'",
                'control_reference': "SEC-002.1"
            },
            'CFG-002': {
                'console_link': f"https://{self.region}.console.aws.amazon.com/systems-manager/parameters?region={self.region}",
                'description': "Parameter Store Console - Verify SecureString parameters with CMK",
                'validation_command': f"aws ssm describe-parameters --parameter-filters 'Key=Name,Values=/{function_name}/'",
                'control_reference': "SEC-002.2"
            },
            'CFG-003': {
                'console_link': f"https://{self.region}.console.aws.amazon.com/lambda/home?region={self.region}#/functions/{function_name}?tab=configuration",
                'description': "Lambda Configuration - Verify environment variables are encrypted with CMK",
                'validation_command': f"aws lambda get-function --function-name {function_name} --query 'Configuration.KMSKeyArn'",
                'control_reference': "SEC-002.3"
            },
            'CFG-004': {
                'console_link': f"https://{self.region}.console.aws.amazon.com/kms/home?region={self.region}#/kms/keys",
                'description': "KMS Console - Verify customer-managed keys have rotation enabled",
                'validation_command': "aws kms describe-key --key-id <key-id> --query 'KeyMetadata.KeyRotationStatus'",
                'control_reference': "SEC-002.3"
            }
        }
    
    def _generate_network_evidence(self, function_name: str) -> Dict[str, Dict[str, str]]:
        """Generate network security evidence links"""
        return {
            'NET-001': {
                'console_link': f"https://{self.region}.console.aws.amazon.com/vpc/home?region={self.region}#subnets:",
                'description': "VPC Subnets Console - Verify Lambda is in private subnets",
                'validation_command': f"aws lambda get-function --function-name {function_name} --query 'Configuration.VpcConfig'",
                'control_reference': "SEC-004.1"
            },
            'NET-002': {
                'console_link': f"https://{self.region}.console.aws.amazon.com/ec2/home?region={self.region}#SecurityGroups:",
                'description': "Security Groups Console - Verify minimal access rules",
                'validation_command': f"aws ec2 describe-security-groups --group-ids $(aws lambda get-function --function-name {function_name} --query 'Configuration.VpcConfig.SecurityGroupIds[]' --output text)",
                'control_reference': "SEC-004.1"
            },
            'NET-003': {
                'console_link': f"https://{self.region}.console.aws.amazon.com/vpc/home?region={self.region}#Endpoints:",
                'description': "VPC Endpoints Console - Verify endpoints are configured for AWS services",
                'validation_command': f"aws ec2 describe-vpc-endpoints --filters 'Name=vpc-id,Values=$(aws lambda get-function --function-name {function_name} --query \"Configuration.VpcConfig.VpcId\" --output text)'",
                'control_reference': "SEC-004.2"
            },
            'NET-004': {
                'console_link': f"https://{self.region}.console.aws.amazon.com/wafv2/homev2/web-acls?region={self.region}",
                'description': "WAF Console - Verify Web ACL is associated with API Gateway",
                'validation_command': "aws wafv2 list-web-acls --scope REGIONAL",
                'control_reference': "SEC-005.1"
            }
        }
    
    def _generate_api_evidence(self, function_name: str) -> Dict[str, Dict[str, str]]:
        """Generate API and event sources evidence links"""
        return {
            'API-001': {
                'console_link': f"https://{self.region}.console.aws.amazon.com/apigateway/home?region={self.region}#/apis",
                'description': "API Gateway Console - Verify authentication is configured",
                'validation_command': "aws apigateway get-authorizers --rest-api-id <api-id>",
                'control_reference': "SEC-005.2"
            },
            'API-002': {
                'console_link': f"https://{self.region}.console.aws.amazon.com/apigateway/home?region={self.region}#/apis",
                'description': "API Gateway Stages - Verify HTTPS-only with TLS 1.2+",
                'validation_command': "aws apigateway get-stage --rest-api-id <api-id> --stage-name <stage-name>",
                'control_reference': "SEC-005.3"
            },
            'API-003': {
                'console_link': f"https://{self.region}.console.aws.amazon.com/apigateway/home?region={self.region}#/usage-plans",
                'description': "API Gateway Usage Plans - Verify throttling and quotas",
                'validation_command': "aws apigateway get-usage-plans",
                'control_reference': "ESA-001.2"
            },
            'EVT-001': {
                'console_link': f"https://{self.region}.console.aws.amazon.com/events/home?region={self.region}#/rules",
                'description': "EventBridge Rules - Verify event filtering and DLQ configuration",
                'validation_command': f"aws events list-rules --name-prefix {function_name}",
                'control_reference': "ESA-002.1"
            },
            'SQS-001': {
                'console_link': f"https://{self.region}.console.aws.amazon.com/sqs/v2/home?region={self.region}#/queues",
                'description': "SQS Queues - Verify redrive policies and encryption",
                'validation_command': f"aws sqs list-queues --queue-name-prefix {function_name}",
                'control_reference': "ESA-003.1"
            }
        }
    
    def _generate_runtime_evidence(self, function_name: str) -> Dict[str, Dict[str, str]]:
        """Generate runtime and reliability evidence links"""
        return {
            'REL-001': {
                'console_link': f"https://{self.region}.console.aws.amazon.com/lambda/home?region={self.region}#/functions/{function_name}?tab=versions",
                'description': "Lambda Versions - Verify versioning and aliases are configured",
                'validation_command': f"aws lambda list-versions-by-function --function-name {function_name}",
                'control_reference': "LRR-001.1"
            },
            'REL-002': {
                'console_link': f"https://{self.region}.console.aws.amazon.com/codesuite/codedeploy/applications?region={self.region}",
                'description': "CodeDeploy Applications - Verify canary deployment configuration",
                'validation_command': f"aws deploy list-applications --query 'applications[?contains(@, `{function_name}`)]'",
                'control_reference': "LRR-001.3"
            },
            'REL-003': {
                'console_link': f"https://{self.region}.console.aws.amazon.com/lambda/home?region={self.region}#/functions/{function_name}?tab=configuration",
                'description': "Lambda Configuration - Verify timeout is appropriately configured",
                'validation_command': f"aws lambda get-function --function-name {function_name} --query 'Configuration.Timeout'",
                'control_reference': "LRR-002.3"
            },
            'REL-004': {
                'console_link': f"https://{self.region}.console.aws.amazon.com/lambda/home?region={self.region}#/functions/{function_name}?tab=configuration",
                'description': "Lambda Configuration - Verify memory allocation is optimized",
                'validation_command': f"aws lambda get-function --function-name {function_name} --query 'Configuration.MemorySize'",
                'control_reference': "LRR-002.4"
            },
            'REL-005': {
                'console_link': f"https://{self.region}.console.aws.amazon.com/lambda/home?region={self.region}#/functions/{function_name}?tab=configuration",
                'description': "Lambda Configuration - Verify concurrency limits are configured",
                'validation_command': f"aws lambda get-function-concurrency --function-name {function_name}",
                'control_reference': "LRR-002.1"
            },
            'REL-006': {
                'console_link': f"https://{self.region}.console.aws.amazon.com/sqs/v2/home?region={self.region}#/queues",
                'description': "SQS Dead Letter Queues - Verify DLQ configuration",
                'validation_command': f"aws lambda get-function --function-name {function_name} --query 'Configuration.DeadLetterConfig'",
                'control_reference': "LRR-003.2"
            },
            'REL-007': {
                'console_link': f"https://{self.region}.console.aws.amazon.com/dynamodb/home?region={self.region}#tables",
                'description': "DynamoDB Tables - Verify idempotency table exists",
                'validation_command': f"aws dynamodb describe-table --table-name {function_name}-idempotency",
                'control_reference': "LRR-003.1"
            }
        }
    
    def _generate_observability_evidence(self, function_name: str) -> Dict[str, Dict[str, str]]:
        """Generate observability evidence links"""
        return {
            'OBS-001': {
                'console_link': f"https://{self.region}.console.aws.amazon.com/cloudwatch/home?region={self.region}#logsV2:log-groups/log-group/$252Faws$252Flambda$252F{quote(function_name)}",
                'description': "CloudWatch Logs - Verify Lambda Powertools structured logging",
                'validation_command': f"aws logs describe-log-groups --log-group-name-prefix '/aws/lambda/{function_name}'",
                'control_reference': "OBS-001.1"
            },
            'OBS-002': {
                'console_link': f"https://{self.region}.console.aws.amazon.com/xray/home?region={self.region}#/service-map",
                'description': "X-Ray Service Map - Verify tracing is enabled",
                'validation_command': f"aws lambda get-function --function-name {function_name} --query 'Configuration.TracingConfig'",
                'control_reference': "OBS-001.2"
            },
            'OBS-003': {
                'console_link': f"https://{self.region}.console.aws.amazon.com/cloudwatch/home?region={self.region}#alarmsV2:alarm/{quote(function_name)}",
                'description': "CloudWatch Alarms - Verify error rate, duration, and throttle alarms",
                'validation_command': f"aws cloudwatch describe-alarms --alarm-name-prefix {function_name}",
                'control_reference': "OBS-002.2"
            },
            'OBS-004': {
                'console_link': f"https://{self.region}.console.aws.amazon.com/cloudwatch/home?region={self.region}#logsV2:logs-insights",
                'description': "CloudWatch Logs Insights - Verify structured logging with correlation IDs",
                'validation_command': f"aws logs start-query --log-group-name '/aws/lambda/{function_name}' --start-time $(date -d '1 hour ago' +%s) --end-time $(date +%s) --query-string 'fields @timestamp, @message | filter @message like /correlation_id/'",
                'control_reference': "OBS-001.3"
            },
            'OBS-005': {
                'console_link': f"https://{self.region}.console.aws.amazon.com/cloudwatch/home?region={self.region}#logsV2:log-groups",
                'description': "CloudWatch Log Groups - Verify retention policies are configured",
                'validation_command': f"aws logs describe-log-groups --log-group-name-prefix '/aws/lambda/{function_name}' --query 'logGroups[].retentionInDays'",
                'control_reference': "OBS-003.1"
            },
            'OBS-006': {
                'console_link': f"https://{self.region}.console.aws.amazon.com/cloudwatch/home?region={self.region}#dashboards:",
                'description': "CloudWatch Dashboards - Verify operational dashboards exist",
                'validation_command': f"aws cloudwatch list-dashboards --dashboard-name-prefix {function_name}",
                'control_reference': "OBS-002.3"
            }
        }
    
    def _generate_cicd_evidence(self, function_name: str) -> Dict[str, Dict[str, str]]:
        """Generate CI/CD evidence links"""
        return {
            'CICD-001': {
                'console_link': "https://github.com/actions",
                'description': "GitHub Actions - Verify workflow configuration with OIDC",
                'validation_command': "Check .github/workflows/ directory for CI/CD configuration",
                'control_reference': "Multiple"
            },
            'CICD-002': {
                'console_link': f"https://{self.region}.console.aws.amazon.com/signer/home?region={self.region}#/signing-profiles",
                'description': "AWS Signer - Verify code signing profiles and jobs",
                'validation_command': "aws signer list-signing-profiles",
                'control_reference': "SEC-003.1"
            },
            'CICD-003': {
                'console_link': "https://github.com/security",
                'description': "GitHub Security - Verify policy validation in CI/CD",
                'validation_command': "Check .github/workflows/ for Checkov and terraform-compliance",
                'control_reference': "Multiple"
            },
            'CICD-004': {
                'console_link': f"https://{self.region}.console.aws.amazon.com/codesuite/codedeploy/deployments?region={self.region}",
                'description': "CodeDeploy Deployments - Verify rollback configuration",
                'validation_command': f"aws deploy list-deployments --application-name {function_name}-deploy",
                'control_reference': "LRR-001.3"
            }
        }
    
    def _generate_dr_evidence(self, function_name: str) -> Dict[str, Dict[str, str]]:
        """Generate disaster recovery evidence links"""
        return {
            'DR-001': {
                'console_link': f"https://{self.region}.console.aws.amazon.com/lambda/home?region={self.region}#/functions/{function_name}",
                'description': "Lambda Function - Verify multi-AZ deployment (inherent)",
                'validation_command': f"aws lambda get-function --function-name {function_name} --query 'Configuration.VpcConfig'",
                'control_reference': "NFR-001.2"
            },
            'DR-002': {
                'console_link': f"https://s3.console.aws.amazon.com/s3/home?region={self.region}",
                'description': "S3 Cross-Region Replication - Verify backup strategy",
                'validation_command': "aws s3api get-bucket-replication --bucket <backup-bucket>",
                'control_reference': "NFR-004.3"
            },
            'DR-003': {
                'console_link': "../runbooks/",
                'description': "DR Runbooks - Verify recovery procedures are documented",
                'validation_command': "Review disaster recovery runbooks and test results",
                'control_reference': "NFR-004.1"
            },
            'DR-004': {
                'console_link': "../runbooks/",
                'description': "Operational Runbooks - Verify incident response procedures",
                'validation_command': "Review operational runbooks and escalation procedures",
                'control_reference': "OBS-004.1"
            }
        }
    
    def _generate_cost_evidence(self, function_name: str) -> Dict[str, Dict[str, str]]:
        """Generate cost management evidence links"""
        return {
            'COST-001': {
                'console_link': f"https://console.aws.amazon.com/cost-management/home?region={self.region}#/dashboard",
                'description': "Cost Explorer - Verify cost monitoring and budgets",
                'validation_command': "aws budgets describe-budgets --account-id $(aws sts get-caller-identity --query Account --output text)",
                'control_reference': "NFR-006.1"
            },
            'COST-002': {
                'console_link': f"https://{self.region}.console.aws.amazon.com/resource-groups/home?region={self.region}#/groups",
                'description': "Resource Groups - Verify consistent tagging strategy",
                'validation_command': f"aws lambda get-function --function-name {function_name} --query 'Tags'",
                'control_reference': "NFR-006.1"
            },
            'COST-003': {
                'console_link': "../optimization/",
                'description': "Performance Optimization - Verify cost vs performance analysis",
                'validation_command': "Review Lambda Power Tuning results and optimization reports",
                'control_reference': "NFR-006.2"
            }
        }
    
    def _generate_compliance_evidence(self, function_name: str) -> Dict[str, Dict[str, str]]:
        """Generate compliance and governance evidence links"""
        return {
            'COMP-001': {
                'console_link': f"https://{self.region}.console.aws.amazon.com/config/home?region={self.region}#/conformance-packs",
                'description': "Config Conformance Packs - Verify Lambda compliance rules",
                'validation_command': "aws configservice describe-conformance-packs",
                'control_reference': "Multiple"
            },
            'COMP-002': {
                'console_link': "https://console.aws.amazon.com/organizations/v2/home/policies",
                'description': "Organizations SCPs - Verify Lambda governance policies",
                'validation_command': "aws organizations list-policies --filter SERVICE_CONTROL_POLICY",
                'control_reference': "Multiple"
            },
            'COMP-003': {
                'console_link': f"https://{self.region}.console.aws.amazon.com/cloudtrail/home?region={self.region}#/dashboard",
                'description': "CloudTrail - Verify audit logging is configured",
                'validation_command': "aws cloudtrail describe-trails",
                'control_reference': "Multiple"
            },
            'COMP-004': {
                'console_link': f"https://{self.region}.console.aws.amazon.com/securityhub/home?region={self.region}#/summary",
                'description': "Security Hub - Verify security findings aggregation",
                'validation_command': "aws securityhub get-enabled-standards",
                'control_reference': "OBS-005.3"
            }
        }
    
    def generate_checklist_with_evidence(self, function_name: str, output_file: str):
        """Generate a completed checklist with evidence links"""
        
        evidence_links = self.generate_evidence_links(function_name)
        
        # Read the checklist template
        try:
            with open('docs/checklists/lambda-production-readiness-checklist.md', 'r') as f:
                checklist_content = f.read()
        except FileNotFoundError:
            print("ERROR: Checklist template not found")
            return
        
        # Replace placeholder links with actual evidence links
        for item_id, evidence in evidence_links.items():
            # Create evidence link with description
            evidence_link = f"[{evidence['description']}]({evidence['console_link']})"
            
            # Add validation command as a comment
            if evidence.get('validation_command'):
                evidence_link += f"\n<!-- Validation: {evidence['validation_command']} -->"
            
            # Replace in checklist content (this is a simplified approach)
            # In a real implementation, you'd want more sophisticated template replacement
            checklist_content = checklist_content.replace(
                f"[Link to {item_id.split('-')[0]} config]",
                evidence_link
            )
        
        # Add metadata
        metadata = f"""
<!-- Generated Evidence Links for {function_name} -->
<!-- Generated on: {datetime.now().isoformat()} -->
<!-- Region: {self.region} -->
<!-- Account: {self.account_id} -->

"""
        
        checklist_content = metadata + checklist_content
        
        # Write to output file
        with open(output_file, 'w') as f:
            f.write(checklist_content)
        
        print(f"✅ Generated checklist with evidence links: {output_file}")
    
    def generate_evidence_summary(self, function_name: str) -> str:
        """Generate a summary of evidence links"""
        
        evidence_links = self.generate_evidence_links(function_name)
        
        summary = []
        summary.append(f"# Evidence Links Summary for {function_name}")
        summary.append(f"Generated: {datetime.now().isoformat()}")
        summary.append(f"Region: {self.region}")
        summary.append(f"Account: {self.account_id}")
        summary.append("")
        
        # Group by category
        categories = {
            'IAM': 'Identity & Access Management',
            'SEC': 'Code Integrity & Security',
            'CFG': 'Secrets & Configuration Management',
            'NET': 'Network Security',
            'API': 'API & Event Sources',
            'EVT': 'API & Event Sources',
            'SQS': 'API & Event Sources',
            'REL': 'Runtime & Reliability',
            'OBS': 'Observability & Monitoring',
            'CICD': 'CI/CD & Deployment',
            'DR': 'Disaster Recovery',
            'COST': 'Cost Management',
            'COMP': 'Compliance & Governance'
        }
        
        current_category = None
        for item_id, evidence in evidence_links.items():
            category_prefix = item_id.split('-')[0]
            category_name = categories.get(category_prefix, 'Other')
            
            if category_name != current_category:
                summary.append(f"\n## {category_name}")
                summary.append("")
                current_category = category_name
            
            summary.append(f"### {item_id}")
            summary.append(f"- **Description**: {evidence['description']}")
            summary.append(f"- **Console Link**: {evidence['console_link']}")
            summary.append(f"- **Validation**: `{evidence['validation_command']}`")
            summary.append(f"- **Control Reference**: {evidence['control_reference']}")
            summary.append("")
        
        return '\n'.join(summary)


def main():
    """Main function"""
    parser = argparse.ArgumentParser(
        description='Generate production readiness checklist evidence links'
    )
    parser.add_argument(
        'function_name',
        help='Lambda function name'
    )
    parser.add_argument(
        '--region',
        default='us-east-1',
        help='AWS region (default: us-east-1)'
    )
    parser.add_argument(
        '--profile',
        help='AWS profile to use'
    )
    parser.add_argument(
        '--output',
        help='Output file for checklist with evidence links'
    )
    parser.add_argument(
        '--summary',
        action='store_true',
        help='Generate evidence summary instead of full checklist'
    )
    
    args = parser.parse_args()
    
    # Initialize generator
    generator = ChecklistEvidenceGenerator(
        region=args.region,
        profile=args.profile
    )
    
    if args.summary:
        # Generate evidence summary
        summary = generator.generate_evidence_summary(args.function_name)
        
        if args.output:
            with open(args.output, 'w') as f:
                f.write(summary)
            print(f"Evidence summary saved to: {args.output}")
        else:
            print(summary)
    else:
        # Generate checklist with evidence links
        output_file = args.output or f"checklist-{args.function_name}-{datetime.now().strftime('%Y%m%d')}.md"
        generator.generate_checklist_with_evidence(args.function_name, output_file)


if __name__ == '__main__':
    main()