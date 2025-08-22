#!/usr/bin/env python3
"""
AWS Lambda Production Readiness Validation Script

This script automates the validation of AWS Lambda production readiness
checklist items by checking actual AWS configurations against requirements.
"""

import boto3
import json
import sys
import argparse
from datetime import datetime
from typing import Dict, List, Any, Optional
import csv
from botocore.exceptions import ClientError, NoCredentialsError


class ProductionReadinessValidator:
    """Validates AWS Lambda production readiness requirements"""
    
    def __init__(self, region: str = 'us-east-1', profile: Optional[str] = None):
        """Initialize AWS clients"""
        try:
            if profile:
                session = boto3.Session(profile_name=profile)
            else:
                session = boto3.Session()
            
            self.region = region
            self.lambda_client = session.client('lambda', region_name=region)
            self.iam_client = session.client('iam')
            self.apigateway_client = session.client('apigateway', region_name=region)
            self.wafv2_client = session.client('wafv2', region_name=region)
            self.config_client = session.client('config', region_name=region)
            self.cloudwatch_client = session.client('cloudwatch', region_name=region)
            self.secretsmanager_client = session.client('secretsmanager', region_name=region)
            self.ssm_client = session.client('ssm', region_name=region)
            self.kms_client = session.client('kms', region_name=region)
            self.sqs_client = session.client('sqs', region_name=region)
            self.sns_client = session.client('sns', region_name=region)
            self.codedeploy_client = session.client('codedeploy', region_name=region)
            self.xray_client = session.client('xray', region_name=region)
            
            # Get account ID
            sts_client = session.client('sts')
            self.account_id = sts_client.get_caller_identity()['Account']
            
        except NoCredentialsError:
            print("ERROR: AWS credentials not found. Please configure AWS CLI or set environment variables.")
            sys.exit(1)
        except Exception as e:
            print(f"ERROR: Failed to initialize AWS clients: {e}")
            sys.exit(1)
    
    def validate_function(self, function_name: str) -> Dict[str, Any]:
        """Validate a specific Lambda function against all checklist items"""
        print(f"\n🔍 Validating Lambda function: {function_name}")
        
        results = {
            'function_name': function_name,
            'timestamp': datetime.now().isoformat(),
            'validations': {}
        }
        
        try:
            # Get function configuration
            function_config = self.lambda_client.get_function(FunctionName=function_name)
            function_info = function_config['Configuration']
            
            # Identity & Access Management
            results['validations'].update(self._validate_iam(function_info))
            
            # Code Integrity & Security
            results['validations'].update(self._validate_code_security(function_info))
            
            # Secrets & Configuration Management
            results['validations'].update(self._validate_secrets_config(function_info))
            
            # Network Security
            results['validations'].update(self._validate_network_security(function_info))
            
            # Runtime & Reliability
            results['validations'].update(self._validate_runtime_reliability(function_name, function_info))
            
            # Observability & Monitoring
            results['validations'].update(self._validate_observability(function_name, function_info))
            
            # CI/CD & Deployment
            results['validations'].update(self._validate_cicd_deployment(function_name))
            
            # Compliance & Governance
            results['validations'].update(self._validate_compliance(function_name))
            
        except ClientError as e:
            results['error'] = f"Failed to get function configuration: {e}"
            
        return results
    
    def _validate_iam(self, function_info: Dict) -> Dict[str, Dict]:
        """Validate IAM-related checklist items"""
        validations = {}
        
        # IAM-001: Least privilege execution role
        role_arn = function_info.get('Role', '')
        role_name = role_arn.split('/')[-1] if role_arn else ''
        
        try:
            # Get role policy
            role_policies = self.iam_client.list_attached_role_policies(RoleName=role_name)
            inline_policies = self.iam_client.list_role_policies(RoleName=role_name)
            
            has_wildcards = False
            policy_details = []
            
            # Check attached policies
            for policy in role_policies['AttachedPolicies']:
                policy_version = self.iam_client.get_policy(PolicyArn=policy['PolicyArn'])
                policy_document = self.iam_client.get_policy_version(
                    PolicyArn=policy['PolicyArn'],
                    VersionId=policy_version['Policy']['DefaultVersionId']
                )
                
                policy_details.append({
                    'name': policy['PolicyName'],
                    'arn': policy['PolicyArn'],
                    'type': 'attached'
                })
                
                # Check for wildcard permissions
                statements = policy_document['PolicyVersion']['Document'].get('Statement', [])
                for statement in statements:
                    if isinstance(statement.get('Resource'), str) and '*' in statement['Resource']:
                        has_wildcards = True
                    elif isinstance(statement.get('Action'), str) and '*' in statement['Action']:
                        has_wildcards = True
            
            # Check inline policies
            for policy_name in inline_policies['PolicyNames']:
                policy_document = self.iam_client.get_role_policy(
                    RoleName=role_name,
                    PolicyName=policy_name
                )
                
                policy_details.append({
                    'name': policy_name,
                    'type': 'inline'
                })
                
                # Check for wildcard permissions
                statements = policy_document['PolicyDocument'].get('Statement', [])
                for statement in statements:
                    if isinstance(statement.get('Resource'), str) and '*' in statement['Resource']:
                        has_wildcards = True
                    elif isinstance(statement.get('Action'), str) and '*' in statement['Action']:
                        has_wildcards = True
            
            validations['IAM-001'] = {
                'status': 'PASS' if not has_wildcards else 'FAIL',
                'message': 'No wildcard permissions found' if not has_wildcards else 'Wildcard permissions detected',
                'details': {
                    'role_arn': role_arn,
                    'policies': policy_details,
                    'has_wildcards': has_wildcards
                }
            }
            
        except ClientError as e:
            validations['IAM-001'] = {
                'status': 'ERROR',
                'message': f"Failed to validate IAM role: {e}",
                'details': {'role_arn': role_arn}
            }
        
        # IAM-002: Permission boundaries
        try:
            role_info = self.iam_client.get_role(RoleName=role_name)
            permissions_boundary = role_info['Role'].get('PermissionsBoundary')
            
            validations['IAM-002'] = {
                'status': 'PASS' if permissions_boundary else 'FAIL',
                'message': 'Permission boundary attached' if permissions_boundary else 'No permission boundary found',
                'details': {
                    'boundary_arn': permissions_boundary.get('PermissionsBoundaryArn') if permissions_boundary else None
                }
            }
            
        except ClientError as e:
            validations['IAM-002'] = {
                'status': 'ERROR',
                'message': f"Failed to check permission boundary: {e}",
                'details': {}
            }
        
        return validations
    
    def _validate_code_security(self, function_info: Dict) -> Dict[str, Dict]:
        """Validate code integrity and security checklist items"""
        validations = {}
        
        # SEC-001: Code signing configuration
        code_signing_config = function_info.get('CodeSigningConfigArn')
        
        validations['SEC-001'] = {
            'status': 'PASS' if code_signing_config else 'FAIL',
            'message': 'Code signing enabled' if code_signing_config else 'Code signing not configured',
            'details': {
                'code_signing_config_arn': code_signing_config
            }
        }
        
        return validations
    
    def _validate_secrets_config(self, function_info: Dict) -> Dict[str, Dict]:
        """Validate secrets and configuration management"""
        validations = {}
        
        # CFG-003: Environment variables encryption
        kms_key_arn = function_info.get('KMSKeyArn')
        env_vars = function_info.get('Environment', {}).get('Variables', {})
        
        validations['CFG-003'] = {
            'status': 'PASS' if kms_key_arn else 'FAIL' if env_vars else 'N/A',
            'message': 'Environment variables encrypted with CMK' if kms_key_arn else 
                      'No KMS encryption for environment variables' if env_vars else 
                      'No environment variables found',
            'details': {
                'kms_key_arn': kms_key_arn,
                'env_var_count': len(env_vars)
            }
        }
        
        return validations
    
    def _validate_network_security(self, function_info: Dict) -> Dict[str, Dict]:
        """Validate network security configuration"""
        validations = {}
        
        # NET-001: VPC configuration
        vpc_config = function_info.get('VpcConfig', {})
        vpc_id = vpc_config.get('VpcId')
        
        validations['NET-001'] = {
            'status': 'PASS' if vpc_id else 'N/A',
            'message': 'Lambda deployed in VPC' if vpc_id else 'Lambda not in VPC (may be acceptable)',
            'details': {
                'vpc_id': vpc_id,
                'subnet_ids': vpc_config.get('SubnetIds', []),
                'security_group_ids': vpc_config.get('SecurityGroupIds', [])
            }
        }
        
        return validations
    
    def _validate_runtime_reliability(self, function_name: str, function_info: Dict) -> Dict[str, Dict]:
        """Validate runtime and reliability configuration"""
        validations = {}
        
        # REL-001: Lambda versioning and aliases
        try:
            versions = self.lambda_client.list_versions_by_function(FunctionName=function_name)
            aliases = self.lambda_client.list_aliases(FunctionName=function_name)
            
            # Check if $LATEST is used (should not be in production)
            has_versions = len([v for v in versions['Versions'] if v['Version'] != '$LATEST']) > 0
            has_live_alias = any(alias['Name'].upper() == 'LIVE' for alias in aliases['Aliases'])
            
            validations['REL-001'] = {
                'status': 'PASS' if has_versions and has_live_alias else 'FAIL',
                'message': 'Proper versioning and aliases configured' if has_versions and has_live_alias else 
                          'Missing versions or LIVE alias',
                'details': {
                    'version_count': len(versions['Versions']) - 1,  # Exclude $LATEST
                    'aliases': [alias['Name'] for alias in aliases['Aliases']],
                    'has_live_alias': has_live_alias
                }
            }
            
        except ClientError as e:
            validations['REL-001'] = {
                'status': 'ERROR',
                'message': f"Failed to check versions/aliases: {e}",
                'details': {}
            }
        
        # REL-003: Timeout configuration
        timeout = function_info.get('Timeout', 0)
        
        validations['REL-003'] = {
            'status': 'PASS' if 1 <= timeout <= 900 else 'FAIL',
            'message': f'Timeout configured: {timeout}s' if 1 <= timeout <= 900 else 
                      f'Invalid timeout: {timeout}s',
            'details': {
                'timeout_seconds': timeout,
                'recommended_max_api': 30,
                'recommended_max_batch': 900
            }
        }
        
        # REL-004: Memory allocation
        memory_size = function_info.get('MemorySize', 0)
        
        validations['REL-004'] = {
            'status': 'PASS' if memory_size >= 512 else 'WARN',
            'message': f'Memory: {memory_size}MB' + (' (recommended minimum 512MB)' if memory_size < 512 else ''),
            'details': {
                'memory_mb': memory_size,
                'recommended_minimum': 512
            }
        }
        
        # REL-005: Concurrency configuration
        try:
            concurrency = self.lambda_client.get_function_concurrency(FunctionName=function_name)
            reserved_concurrency = concurrency.get('ReservedConcurrencyLimit')
            
            validations['REL-005'] = {
                'status': 'PASS' if reserved_concurrency else 'WARN',
                'message': f'Reserved concurrency: {reserved_concurrency}' if reserved_concurrency else 
                          'No reserved concurrency configured',
                'details': {
                    'reserved_concurrency': reserved_concurrency
                }
            }
            
        except ClientError:
            validations['REL-005'] = {
                'status': 'WARN',
                'message': 'No concurrency configuration found',
                'details': {}
            }
        
        # REL-006: Dead Letter Queue
        dlq_config = function_info.get('DeadLetterConfig', {})
        target_arn = dlq_config.get('TargetArn')
        
        validations['REL-006'] = {
            'status': 'PASS' if target_arn else 'WARN',
            'message': 'DLQ configured' if target_arn else 'No DLQ configured (may be acceptable for sync functions)',
            'details': {
                'dlq_target_arn': target_arn
            }
        }
        
        return validations
    
    def _validate_observability(self, function_name: str, function_info: Dict) -> Dict[str, Dict]:
        """Validate observability and monitoring configuration"""
        validations = {}
        
        # OBS-002: X-Ray tracing
        tracing_config = function_info.get('TracingConfig', {})
        tracing_mode = tracing_config.get('Mode', 'PassThrough')
        
        validations['OBS-002'] = {
            'status': 'PASS' if tracing_mode == 'Active' else 'FAIL',
            'message': f'X-Ray tracing: {tracing_mode}',
            'details': {
                'tracing_mode': tracing_mode
            }
        }
        
        # OBS-003: CloudWatch alarms
        try:
            alarms = self.cloudwatch_client.describe_alarms(
                AlarmNamePrefix=function_name
            )
            
            alarm_count = len(alarms['MetricAlarms'])
            
            validations['OBS-003'] = {
                'status': 'PASS' if alarm_count >= 3 else 'WARN',
                'message': f'{alarm_count} CloudWatch alarms found' + 
                          (' (recommend error rate, duration, throttle alarms)' if alarm_count < 3 else ''),
                'details': {
                    'alarm_count': alarm_count,
                    'alarm_names': [alarm['AlarmName'] for alarm in alarms['MetricAlarms']]
                }
            }
            
        except ClientError as e:
            validations['OBS-003'] = {
                'status': 'ERROR',
                'message': f"Failed to check CloudWatch alarms: {e}",
                'details': {}
            }
        
        return validations
    
    def _validate_cicd_deployment(self, function_name: str) -> Dict[str, Dict]:
        """Validate CI/CD and deployment configuration"""
        validations = {}
        
        # CICD-002: CodeDeploy configuration
        try:
            applications = self.codedeploy_client.list_applications()
            
            # Look for CodeDeploy application matching function name
            matching_apps = [app for app in applications['applications'] 
                           if function_name.lower() in app.lower()]
            
            validations['CICD-002'] = {
                'status': 'PASS' if matching_apps else 'WARN',
                'message': f'CodeDeploy applications found: {len(matching_apps)}' if matching_apps else 
                          'No CodeDeploy application found',
                'details': {
                    'applications': matching_apps
                }
            }
            
        except ClientError as e:
            validations['CICD-002'] = {
                'status': 'ERROR',
                'message': f"Failed to check CodeDeploy: {e}",
                'details': {}
            }
        
        return validations
    
    def _validate_compliance(self, function_name: str) -> Dict[str, Dict]:
        """Validate compliance and governance configuration"""
        validations = {}
        
        # COMP-001: AWS Config rules
        try:
            config_rules = self.config_client.describe_config_rules()
            
            lambda_rules = [rule for rule in config_rules['ConfigRules'] 
                          if 'lambda' in rule['ConfigRuleName'].lower()]
            
            validations['COMP-001'] = {
                'status': 'PASS' if len(lambda_rules) >= 3 else 'WARN',
                'message': f'{len(lambda_rules)} Lambda-related Config rules found',
                'details': {
                    'rule_count': len(lambda_rules),
                    'rule_names': [rule['ConfigRuleName'] for rule in lambda_rules]
                }
            }
            
        except ClientError as e:
            validations['COMP-001'] = {
                'status': 'ERROR',
                'message': f"Failed to check Config rules: {e}",
                'details': {}
            }
        
        return validations
    
    def generate_report(self, results: List[Dict[str, Any]], output_format: str = 'json') -> str:
        """Generate validation report in specified format"""
        
        if output_format == 'json':
            return json.dumps(results, indent=2)
        
        elif output_format == 'csv':
            if not results:
                return "No results to report"
            
            # Flatten results for CSV
            csv_rows = []
            for result in results:
                function_name = result['function_name']
                timestamp = result['timestamp']
                
                for check_id, validation in result.get('validations', {}).items():
                    csv_rows.append({
                        'function_name': function_name,
                        'timestamp': timestamp,
                        'check_id': check_id,
                        'status': validation['status'],
                        'message': validation['message']
                    })
            
            if not csv_rows:
                return "No validation results found"
            
            # Generate CSV
            output = []
            fieldnames = ['function_name', 'timestamp', 'check_id', 'status', 'message']
            
            # Header
            output.append(','.join(fieldnames))
            
            # Rows
            for row in csv_rows:
                csv_row = []
                for field in fieldnames:
                    value = str(row.get(field, ''))
                    # Escape commas and quotes
                    if ',' in value or '"' in value:
                        value = '"' + value.replace('"', '""') + '"'
                    csv_row.append(value)
                output.append(','.join(csv_row))
            
            return '\n'.join(output)
        
        elif output_format == 'summary':
            summary = []
            summary.append("🔍 AWS Lambda Production Readiness Validation Summary")
            summary.append("=" * 60)
            
            total_functions = len(results)
            total_checks = 0
            passed_checks = 0
            failed_checks = 0
            warning_checks = 0
            error_checks = 0
            
            for result in results:
                function_name = result['function_name']
                validations = result.get('validations', {})
                
                summary.append(f"\n📋 Function: {function_name}")
                summary.append("-" * 40)
                
                for check_id, validation in validations.items():
                    status = validation['status']
                    message = validation['message']
                    
                    status_icon = {
                        'PASS': '✅',
                        'FAIL': '❌',
                        'WARN': '⚠️',
                        'ERROR': '🔥',
                        'N/A': 'ℹ️'
                    }.get(status, '❓')
                    
                    summary.append(f"  {status_icon} {check_id}: {message}")
                    
                    total_checks += 1
                    if status == 'PASS':
                        passed_checks += 1
                    elif status == 'FAIL':
                        failed_checks += 1
                    elif status == 'WARN':
                        warning_checks += 1
                    elif status == 'ERROR':
                        error_checks += 1
            
            # Overall summary
            summary.append(f"\n📊 Overall Summary")
            summary.append("=" * 30)
            summary.append(f"Functions validated: {total_functions}")
            summary.append(f"Total checks: {total_checks}")
            summary.append(f"✅ Passed: {passed_checks}")
            summary.append(f"❌ Failed: {failed_checks}")
            summary.append(f"⚠️  Warnings: {warning_checks}")
            summary.append(f"🔥 Errors: {error_checks}")
            
            if failed_checks > 0 or error_checks > 0:
                summary.append(f"\n⚠️  Production readiness: NOT READY")
            elif warning_checks > 0:
                summary.append(f"\n⚠️  Production readiness: READY WITH WARNINGS")
            else:
                summary.append(f"\n✅ Production readiness: READY")
            
            return '\n'.join(summary)
        
        else:
            raise ValueError(f"Unsupported output format: {output_format}")


def main():
    """Main function"""
    parser = argparse.ArgumentParser(
        description='Validate AWS Lambda production readiness requirements'
    )
    parser.add_argument(
        'functions',
        nargs='+',
        help='Lambda function names to validate'
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
        choices=['json', 'csv', 'summary'],
        default='summary',
        help='Output format (default: summary)'
    )
    parser.add_argument(
        '--output-file',
        help='Output file path (default: stdout)'
    )
    
    args = parser.parse_args()
    
    # Initialize validator
    validator = ProductionReadinessValidator(
        region=args.region,
        profile=args.profile
    )
    
    # Validate functions
    results = []
    for function_name in args.functions:
        result = validator.validate_function(function_name)
        results.append(result)
    
    # Generate report
    report = validator.generate_report(results, args.output)
    
    # Output report
    if args.output_file:
        with open(args.output_file, 'w') as f:
            f.write(report)
        print(f"Report saved to: {args.output_file}")
    else:
        print(report)


if __name__ == '__main__':
    main()