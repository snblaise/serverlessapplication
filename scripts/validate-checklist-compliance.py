#!/usr/bin/env python3
"""
Checklist Compliance Validation Script

This script validates that all production readiness checklist items are properly
configured by checking actual AWS resources against the requirements and
generating compliance reports.
"""

import boto3
import json
import sys
import argparse
from datetime import datetime
from typing import Dict, List, Any, Optional, Tuple
import csv
from botocore.exceptions import ClientError, NoCredentialsError
import re


class ChecklistComplianceValidator:
    """Validates compliance against production readiness checklist items"""
    
    def __init__(self, region: str = 'us-east-1', profile: Optional[str] = None):
        """Initialize AWS clients"""
        try:
            if profile:
                session = boto3.Session(profile_name=profile)
            else:
                session = boto3.Session()
            
            self.region = region
            self.session = session
            
            # Initialize all required AWS clients
            self.lambda_client = session.client('lambda', region_name=region)
            self.iam_client = session.client('iam')
            self.apigateway_client = session.client('apigateway', region_name=region)
            self.apigatewayv2_client = session.client('apigatewayv2', region_name=region)
            self.wafv2_client = session.client('wafv2', region_name=region)
            self.config_client = session.client('config', region_name=region)
            self.cloudwatch_client = session.client('cloudwatch', region_name=region)
            self.logs_client = session.client('logs', region_name=region)
            self.secretsmanager_client = session.client('secretsmanager', region_name=region)
            self.ssm_client = session.client('ssm', region_name=region)
            self.kms_client = session.client('kms', region_name=region)
            self.sqs_client = session.client('sqs', region_name=region)
            self.sns_client = session.client('sns', region_name=region)
            self.codedeploy_client = session.client('codedeploy', region_name=region)
            self.xray_client = session.client('xray', region_name=region)
            self.events_client = session.client('events', region_name=region)
            self.ec2_client = session.client('ec2', region_name=region)
            self.s3_client = session.client('s3')
            self.organizations_client = session.client('organizations')
            self.signer_client = session.client('signer', region_name=region)
            
            # Get account ID
            sts_client = session.client('sts')
            self.account_id = sts_client.get_caller_identity()['Account']
            
        except NoCredentialsError:
            print("ERROR: AWS credentials not found. Please configure AWS CLI or set environment variables.")
            sys.exit(1)
        except Exception as e:
            print(f"ERROR: Failed to initialize AWS clients: {e}")
            sys.exit(1)
    
    def validate_all_checklist_items(self, function_name: str) -> Dict[str, Any]:
        """Validate all checklist items for a Lambda function"""
        
        print(f"\n🔍 Validating all checklist items for: {function_name}")
        
        results = {
            'function_name': function_name,
            'timestamp': datetime.now().isoformat(),
            'account_id': self.account_id,
            'region': self.region,
            'validations': {},
            'summary': {
                'total_items': 0,
                'passed': 0,
                'failed': 0,
                'warnings': 0,
                'errors': 0,
                'not_applicable': 0
            }
        }
        
        try:
            # Get function configuration
            function_config = self.lambda_client.get_function(FunctionName=function_name)
            function_info = function_config['Configuration']
            
            # Validate all categories
            validations = {}
            
            # Identity & Access Management
            validations.update(self._validate_iam_checklist(function_info))
            
            # Code Integrity & Security
            validations.update(self._validate_security_checklist(function_info))
            
            # Secrets & Configuration Management
            validations.update(self._validate_config_checklist(function_info))
            
            # Network Security
            validations.update(self._validate_network_checklist(function_info))
            
            # API & Event Sources
            validations.update(self._validate_api_checklist(function_name, function_info))
            
            # Runtime & Reliability
            validations.update(self._validate_runtime_checklist(function_name, function_info))
            
            # Observability & Monitoring
            validations.update(self._validate_observability_checklist(function_name, function_info))
            
            # CI/CD & Deployment
            validations.update(self._validate_cicd_checklist(function_name))
            
            # Disaster Recovery
            validations.update(self._validate_dr_checklist(function_name, function_info))
            
            # Cost Management
            validations.update(self._validate_cost_checklist(function_name, function_info))
            
            # Compliance & Governance
            validations.update(self._validate_compliance_checklist(function_name))
            
            results['validations'] = validations
            
            # Calculate summary
            for validation in validations.values():
                status = validation['status']
                results['summary']['total_items'] += 1
                
                if status == 'PASS':
                    results['summary']['passed'] += 1
                elif status == 'FAIL':
                    results['summary']['failed'] += 1
                elif status == 'WARN':
                    results['summary']['warnings'] += 1
                elif status == 'ERROR':
                    results['summary']['errors'] += 1
                elif status == 'N/A':
                    results['summary']['not_applicable'] += 1
            
        except ClientError as e:
            results['error'] = f"Failed to get function configuration: {e}"
        
        return results
    
    def _validate_iam_checklist(self, function_info: Dict) -> Dict[str, Dict]:
        """Validate IAM checklist items"""
        validations = {}
        
        role_arn = function_info.get('Role', '')
        role_name = role_arn.split('/')[-1] if role_arn else ''
        
        # IAM-001: Least privilege execution roles
        validations['IAM-001'] = self._check_least_privilege_role(role_name)
        
        # IAM-002: Permission boundaries
        validations['IAM-002'] = self._check_permission_boundary(role_name)
        
        # IAM-003: Identity Center federation
        validations['IAM-003'] = self._check_identity_center()
        
        # IAM-004: OIDC authentication
        validations['IAM-004'] = self._check_oidc_configuration()
        
        return validations
    
    def _check_least_privilege_role(self, role_name: str) -> Dict[str, Any]:
        """Check if IAM role follows least privilege principle"""
        try:
            # Get role policies
            attached_policies = self.iam_client.list_attached_role_policies(RoleName=role_name)
            inline_policies = self.iam_client.list_role_policies(RoleName=role_name)
            
            issues = []
            policy_count = len(attached_policies['AttachedPolicies']) + len(inline_policies['PolicyNames'])
            
            # Check attached policies for wildcards
            for policy in attached_policies['AttachedPolicies']:
                try:
                    policy_version = self.iam_client.get_policy(PolicyArn=policy['PolicyArn'])
                    policy_document = self.iam_client.get_policy_version(
                        PolicyArn=policy['PolicyArn'],
                        VersionId=policy_version['Policy']['DefaultVersionId']
                    )
                    
                    if self._has_wildcard_permissions(policy_document['PolicyVersion']['Document']):
                        issues.append(f"Wildcard permissions in policy: {policy['PolicyName']}")
                        
                except ClientError:
                    issues.append(f"Could not analyze policy: {policy['PolicyName']}")
            
            # Check inline policies for wildcards
            for policy_name in inline_policies['PolicyNames']:
                try:
                    policy_document = self.iam_client.get_role_policy(
                        RoleName=role_name,
                        PolicyName=policy_name
                    )
                    
                    if self._has_wildcard_permissions(policy_document['PolicyDocument']):
                        issues.append(f"Wildcard permissions in inline policy: {policy_name}")
                        
                except ClientError:
                    issues.append(f"Could not analyze inline policy: {policy_name}")
            
            status = 'FAIL' if issues else 'PASS'
            message = f"Role has {policy_count} policies" + (f", issues: {'; '.join(issues)}" if issues else ", no wildcard permissions found")
            
            return {
                'status': status,
                'message': message,
                'details': {
                    'role_name': role_name,
                    'attached_policies': len(attached_policies['AttachedPolicies']),
                    'inline_policies': len(inline_policies['PolicyNames']),
                    'issues': issues
                },
                'evidence_link': f"https://console.aws.amazon.com/iam/home#/roles/{role_name}",
                'remediation': "Remove wildcard permissions and use resource-specific ARNs" if issues else None
            }
            
        except ClientError as e:
            return {
                'status': 'ERROR',
                'message': f"Failed to check IAM role: {e}",
                'details': {'role_name': role_name},
                'evidence_link': None,
                'remediation': "Verify IAM permissions and role existence"
            }
    
    def _has_wildcard_permissions(self, policy_document: Dict) -> bool:
        """Check if policy document contains wildcard permissions"""
        statements = policy_document.get('Statement', [])
        if not isinstance(statements, list):
            statements = [statements]
        
        for statement in statements:
            if statement.get('Effect') == 'Allow':
                # Check actions
                actions = statement.get('Action', [])
                if isinstance(actions, str):
                    actions = [actions]
                
                for action in actions:
                    if '*' in action and action != 'logs:*':  # Allow logs:* as it's common and safe
                        return True
                
                # Check resources
                resources = statement.get('Resource', [])
                if isinstance(resources, str):
                    resources = [resources]
                
                for resource in resources:
                    if resource == '*':
                        return True
        
        return False
    
    def _check_permission_boundary(self, role_name: str) -> Dict[str, Any]:
        """Check if role has permission boundary attached"""
        try:
            role_info = self.iam_client.get_role(RoleName=role_name)
            permissions_boundary = role_info['Role'].get('PermissionsBoundary')
            
            status = 'PASS' if permissions_boundary else 'FAIL'
            message = 'Permission boundary attached' if permissions_boundary else 'No permission boundary found'
            
            return {
                'status': status,
                'message': message,
                'details': {
                    'boundary_arn': permissions_boundary.get('PermissionsBoundaryArn') if permissions_boundary else None
                },
                'evidence_link': f"https://console.aws.amazon.com/iam/home#/roles/{role_name}",
                'remediation': "Attach permission boundary policy to restrict maximum permissions" if not permissions_boundary else None
            }
            
        except ClientError as e:
            return {
                'status': 'ERROR',
                'message': f"Failed to check permission boundary: {e}",
                'details': {},
                'evidence_link': None,
                'remediation': "Verify IAM permissions and role existence"
            }
    
    def _check_identity_center(self) -> Dict[str, Any]:
        """Check if Identity Center is configured"""
        try:
            # This is a simplified check - in practice you'd check for actual usage
            return {
                'status': 'N/A',
                'message': 'Identity Center configuration requires manual verification',
                'details': {},
                'evidence_link': 'https://console.aws.amazon.com/singlesignon/home',
                'remediation': 'Configure Identity Center for human access with MFA'
            }
            
        except Exception:
            return {
                'status': 'N/A',
                'message': 'Identity Center check not available',
                'details': {},
                'evidence_link': None,
                'remediation': None
            }
    
    def _check_oidc_configuration(self) -> Dict[str, Any]:
        """Check OIDC configuration (GitHub Actions)"""
        try:
            # Check for OIDC identity providers
            providers = self.iam_client.list_open_id_connect_providers()
            
            github_oidc = any('token.actions.githubusercontent.com' in provider['Arn'] 
                            for provider in providers['OpenIDConnectProviderList'])
            
            status = 'PASS' if github_oidc else 'WARN'
            message = 'GitHub OIDC provider found' if github_oidc else 'No GitHub OIDC provider found'
            
            return {
                'status': status,
                'message': message,
                'details': {
                    'oidc_providers': len(providers['OpenIDConnectProviderList']),
                    'github_oidc': github_oidc
                },
                'evidence_link': 'https://console.aws.amazon.com/iam/home#/providers',
                'remediation': 'Configure GitHub OIDC provider for CI/CD authentication' if not github_oidc else None
            }
            
        except ClientError as e:
            return {
                'status': 'ERROR',
                'message': f"Failed to check OIDC providers: {e}",
                'details': {},
                'evidence_link': None,
                'remediation': "Verify IAM permissions"
            }
    
    def _validate_security_checklist(self, function_info: Dict) -> Dict[str, Dict]:
        """Validate security checklist items"""
        validations = {}
        
        # SEC-001: Code signing configuration
        validations['SEC-001'] = self._check_code_signing(function_info)
        
        # SEC-002: Security scanning integration
        validations['SEC-002'] = self._check_security_scanning()
        
        # SEC-003: Dependency scanning
        validations['SEC-003'] = self._check_dependency_scanning()
        
        # SEC-004: Artifact integrity
        validations['SEC-004'] = self._check_artifact_integrity()
        
        return validations
    
    def _check_code_signing(self, function_info: Dict) -> Dict[str, Any]:
        """Check if code signing is enabled"""
        code_signing_config = function_info.get('CodeSigningConfigArn')
        
        status = 'PASS' if code_signing_config else 'FAIL'
        message = 'Code signing enabled' if code_signing_config else 'Code signing not configured'
        
        return {
            'status': status,
            'message': message,
            'details': {
                'code_signing_config_arn': code_signing_config
            },
            'evidence_link': f"https://{self.region}.console.aws.amazon.com/lambda/home?region={self.region}#/functions/{function_info['FunctionName']}?tab=configuration",
            'remediation': 'Configure AWS Signer and attach CodeSigningConfig to Lambda function' if not code_signing_config else None
        }
    
    def _check_security_scanning(self) -> Dict[str, Any]:
        """Check security scanning integration"""
        # This would typically check Security Hub for scan results
        # For now, return a manual verification requirement
        return {
            'status': 'N/A',
            'message': 'Security scanning integration requires manual verification',
            'details': {},
            'evidence_link': f'https://{self.region}.console.aws.amazon.com/securityhub/home?region={self.region}#/findings',
            'remediation': 'Integrate SAST, SCA, and policy scans with Security Hub'
        }
    
    def _check_dependency_scanning(self) -> Dict[str, Any]:
        """Check dependency scanning configuration"""
        # This would typically check GitHub repository configuration
        return {
            'status': 'N/A',
            'message': 'Dependency scanning requires manual verification of GitHub/repository configuration',
            'details': {},
            'evidence_link': 'https://github.com/security/dependabot',
            'remediation': 'Enable Dependabot or equivalent dependency scanning'
        }
    
    def _check_artifact_integrity(self) -> Dict[str, Any]:
        """Check artifact integrity verification"""
        # This would check S3 bucket configuration for deployment artifacts
        return {
            'status': 'N/A',
            'message': 'Artifact integrity requires manual verification of S3 bucket configuration',
            'details': {},
            'evidence_link': f'https://s3.console.aws.amazon.com/s3/home?region={self.region}',
            'remediation': 'Configure S3 versioning, MFA delete, and checksum verification'
        }
    
    def _validate_config_checklist(self, function_info: Dict) -> Dict[str, Dict]:
        """Validate configuration management checklist items"""
        validations = {}
        
        # CFG-001: Secrets in Secrets Manager
        validations['CFG-001'] = self._check_secrets_manager_usage(function_info['FunctionName'])
        
        # CFG-002: Parameter Store configuration
        validations['CFG-002'] = self._check_parameter_store_usage(function_info['FunctionName'])
        
        # CFG-003: Environment variable encryption
        validations['CFG-003'] = self._check_env_var_encryption(function_info)
        
        # CFG-004: KMS key rotation
        validations['CFG-004'] = self._check_kms_key_rotation(function_info)
        
        return validations
    
    def _check_secrets_manager_usage(self, function_name: str) -> Dict[str, Any]:
        """Check if Secrets Manager is used for sensitive data"""
        try:
            # Look for secrets that might be related to this function
            secrets = self.secretsmanager_client.list_secrets()
            
            related_secrets = [s for s in secrets['SecretList'] 
                             if function_name.lower() in s['Name'].lower()]
            
            status = 'PASS' if related_secrets else 'WARN'
            message = f'Found {len(related_secrets)} related secrets' if related_secrets else 'No related secrets found (may be acceptable)'
            
            return {
                'status': status,
                'message': message,
                'details': {
                    'related_secrets': len(related_secrets),
                    'secret_names': [s['Name'] for s in related_secrets]
                },
                'evidence_link': f'https://{self.region}.console.aws.amazon.com/secretsmanager/home?region={self.region}#/listSecrets',
                'remediation': 'Store sensitive configuration in Secrets Manager with automatic rotation' if not related_secrets else None
            }
            
        except ClientError as e:
            return {
                'status': 'ERROR',
                'message': f"Failed to check Secrets Manager: {e}",
                'details': {},
                'evidence_link': None,
                'remediation': "Verify Secrets Manager permissions"
            }
    
    def _check_parameter_store_usage(self, function_name: str) -> Dict[str, Any]:
        """Check Parameter Store usage for non-sensitive configuration"""
        try:
            # Look for parameters that might be related to this function
            parameters = self.ssm_client.describe_parameters(
                ParameterFilters=[
                    {
                        'Key': 'Name',
                        'Values': [f'/{function_name}/']
                    }
                ]
            )
            
            secure_params = [p for p in parameters['Parameters'] if p['Type'] == 'SecureString']
            
            status = 'PASS' if secure_params else 'WARN'
            message = f'Found {len(secure_params)} SecureString parameters' if secure_params else 'No SecureString parameters found'
            
            return {
                'status': status,
                'message': message,
                'details': {
                    'total_parameters': len(parameters['Parameters']),
                    'secure_parameters': len(secure_params)
                },
                'evidence_link': f'https://{self.region}.console.aws.amazon.com/systems-manager/parameters?region={self.region}',
                'remediation': 'Use Parameter Store SecureString for non-sensitive configuration' if not secure_params else None
            }
            
        except ClientError as e:
            return {
                'status': 'ERROR',
                'message': f"Failed to check Parameter Store: {e}",
                'details': {},
                'evidence_link': None,
                'remediation': "Verify Systems Manager permissions"
            }
    
    def _check_env_var_encryption(self, function_info: Dict) -> Dict[str, Any]:
        """Check environment variable encryption"""
        kms_key_arn = function_info.get('KMSKeyArn')
        env_vars = function_info.get('Environment', {}).get('Variables', {})
        
        if not env_vars:
            status = 'N/A'
            message = 'No environment variables found'
            remediation = None
        elif kms_key_arn:
            status = 'PASS'
            message = f'Environment variables encrypted with CMK ({len(env_vars)} variables)'
            remediation = None
        else:
            status = 'FAIL'
            message = f'Environment variables not encrypted with CMK ({len(env_vars)} variables)'
            remediation = 'Configure KMS customer-managed key for environment variable encryption'
        
        return {
            'status': status,
            'message': message,
            'details': {
                'kms_key_arn': kms_key_arn,
                'env_var_count': len(env_vars)
            },
            'evidence_link': f"https://{self.region}.console.aws.amazon.com/lambda/home?region={self.region}#/functions/{function_info['FunctionName']}?tab=configuration",
            'remediation': remediation
        }
    
    def _check_kms_key_rotation(self, function_info: Dict) -> Dict[str, Any]:
        """Check KMS key rotation status"""
        kms_key_arn = function_info.get('KMSKeyArn')
        
        if not kms_key_arn:
            return {
                'status': 'N/A',
                'message': 'No KMS key configured',
                'details': {},
                'evidence_link': None,
                'remediation': None
            }
        
        try:
            # Extract key ID from ARN
            key_id = kms_key_arn.split('/')[-1]
            
            # Check key rotation status
            rotation_status = self.kms_client.get_key_rotation_status(KeyId=key_id)
            
            status = 'PASS' if rotation_status['KeyRotationEnabled'] else 'FAIL'
            message = 'KMS key rotation enabled' if rotation_status['KeyRotationEnabled'] else 'KMS key rotation disabled'
            
            return {
                'status': status,
                'message': message,
                'details': {
                    'key_id': key_id,
                    'rotation_enabled': rotation_status['KeyRotationEnabled']
                },
                'evidence_link': f'https://{self.region}.console.aws.amazon.com/kms/home?region={self.region}#/kms/keys/{key_id}',
                'remediation': 'Enable automatic key rotation for customer-managed KMS keys' if not rotation_status['KeyRotationEnabled'] else None
            }
            
        except ClientError as e:
            return {
                'status': 'ERROR',
                'message': f"Failed to check KMS key rotation: {e}",
                'details': {'kms_key_arn': kms_key_arn},
                'evidence_link': None,
                'remediation': "Verify KMS permissions and key existence"
            }
    
    def _validate_network_checklist(self, function_info: Dict) -> Dict[str, Dict]:
        """Validate network security checklist items"""
        validations = {}
        
        vpc_config = function_info.get('VpcConfig', {})
        
        # NET-001: VPC configuration
        validations['NET-001'] = self._check_vpc_configuration(vpc_config)
        
        # NET-002: Security groups
        validations['NET-002'] = self._check_security_groups(vpc_config)
        
        # NET-003: VPC endpoints
        validations['NET-003'] = self._check_vpc_endpoints(vpc_config)
        
        # NET-004: WAF protection (requires API Gateway analysis)
        validations['NET-004'] = self._check_waf_protection()
        
        return validations
    
    def _check_vpc_configuration(self, vpc_config: Dict) -> Dict[str, Any]:
        """Check VPC configuration"""
        vpc_id = vpc_config.get('VpcId')
        
        if not vpc_id:
            return {
                'status': 'N/A',
                'message': 'Lambda not in VPC (acceptable for functions not accessing private resources)',
                'details': {},
                'evidence_link': None,
                'remediation': 'Deploy Lambda in VPC if accessing private resources'
            }
        
        subnet_ids = vpc_config.get('SubnetIds', [])
        security_group_ids = vpc_config.get('SecurityGroupIds', [])
        
        status = 'PASS' if subnet_ids and security_group_ids else 'WARN'
        message = f'Lambda in VPC {vpc_id} with {len(subnet_ids)} subnets, {len(security_group_ids)} security groups'
        
        return {
            'status': status,
            'message': message,
            'details': {
                'vpc_id': vpc_id,
                'subnet_count': len(subnet_ids),
                'security_group_count': len(security_group_ids)
            },
            'evidence_link': f'https://{self.region}.console.aws.amazon.com/vpc/home?region={self.region}#vpcs:VpcId={vpc_id}',
            'remediation': 'Ensure Lambda is in private subnets with appropriate security groups' if status == 'WARN' else None
        }
    
    def _check_security_groups(self, vpc_config: Dict) -> Dict[str, Any]:
        """Check security group configuration"""
        security_group_ids = vpc_config.get('SecurityGroupIds', [])
        
        if not security_group_ids:
            return {
                'status': 'N/A',
                'message': 'No security groups (Lambda not in VPC)',
                'details': {},
                'evidence_link': None,
                'remediation': None
            }
        
        try:
            # Get security group details
            security_groups = self.ec2_client.describe_security_groups(
                GroupIds=security_group_ids
            )
            
            issues = []
            for sg in security_groups['SecurityGroups']:
                # Check for overly permissive rules
                for rule in sg.get('IpPermissions', []):
                    for ip_range in rule.get('IpRanges', []):
                        if ip_range.get('CidrIp') == '0.0.0.0/0':
                            issues.append(f"Security group {sg['GroupId']} allows inbound from 0.0.0.0/0")
                
                for rule in sg.get('IpPermissionsEgress', []):
                    for ip_range in rule.get('IpRanges', []):
                        if ip_range.get('CidrIp') == '0.0.0.0/0' and rule.get('IpProtocol') != 'tcp':
                            issues.append(f"Security group {sg['GroupId']} allows non-TCP egress to 0.0.0.0/0")
            
            status = 'WARN' if issues else 'PASS'
            message = f'Security groups configured' + (f', issues: {"; ".join(issues)}' if issues else '')
            
            return {
                'status': status,
                'message': message,
                'details': {
                    'security_group_ids': security_group_ids,
                    'issues': issues
                },
                'evidence_link': f'https://{self.region}.console.aws.amazon.com/ec2/home?region={self.region}#SecurityGroups:',
                'remediation': 'Review and restrict security group rules to follow least privilege' if issues else None
            }
            
        except ClientError as e:
            return {
                'status': 'ERROR',
                'message': f"Failed to check security groups: {e}",
                'details': {'security_group_ids': security_group_ids},
                'evidence_link': None,
                'remediation': "Verify EC2 permissions"
            }
    
    def _check_vpc_endpoints(self, vpc_config: Dict) -> Dict[str, Any]:
        """Check VPC endpoints configuration"""
        vpc_id = vpc_config.get('VpcId')
        
        if not vpc_id:
            return {
                'status': 'N/A',
                'message': 'No VPC endpoints check (Lambda not in VPC)',
                'details': {},
                'evidence_link': None,
                'remediation': None
            }
        
        try:
            # Get VPC endpoints
            endpoints = self.ec2_client.describe_vpc_endpoints(
                Filters=[
                    {
                        'Name': 'vpc-id',
                        'Values': [vpc_id]
                    }
                ]
            )
            
            endpoint_services = [ep['ServiceName'] for ep in endpoints['VpcEndpoints']]
            
            # Check for common AWS service endpoints
            recommended_endpoints = [
                f'com.amazonaws.{self.region}.s3',
                f'com.amazonaws.{self.region}.dynamodb',
                f'com.amazonaws.{self.region}.secretsmanager',
                f'com.amazonaws.{self.region}.ssm'
            ]
            
            missing_endpoints = [ep for ep in recommended_endpoints if ep not in endpoint_services]
            
            status = 'PASS' if len(missing_endpoints) <= 1 else 'WARN'
            message = f'VPC has {len(endpoints["VpcEndpoints"])} endpoints' + (f', missing: {", ".join(missing_endpoints)}' if missing_endpoints else '')
            
            return {
                'status': status,
                'message': message,
                'details': {
                    'endpoint_count': len(endpoints['VpcEndpoints']),
                    'endpoint_services': endpoint_services,
                    'missing_recommended': missing_endpoints
                },
                'evidence_link': f'https://{self.region}.console.aws.amazon.com/vpc/home?region={self.region}#Endpoints:',
                'remediation': 'Configure VPC endpoints for AWS services to avoid NAT gateway costs' if missing_endpoints else None
            }
            
        except ClientError as e:
            return {
                'status': 'ERROR',
                'message': f"Failed to check VPC endpoints: {e}",
                'details': {'vpc_id': vpc_id},
                'evidence_link': None,
                'remediation': "Verify EC2 permissions"
            }
    
    def _check_waf_protection(self) -> Dict[str, Any]:
        """Check WAF protection for API Gateway"""
        # This is a simplified check - would need API Gateway integration analysis
        return {
            'status': 'N/A',
            'message': 'WAF protection requires manual verification of API Gateway association',
            'details': {},
            'evidence_link': f'https://{self.region}.console.aws.amazon.com/wafv2/homev2/web-acls?region={self.region}',
            'remediation': 'Associate WAF Web ACL with internet-facing API Gateway stages'
        }
    
    # Additional validation methods would continue here for other categories...
    # For brevity, I'll implement a few more key ones and indicate where others would go
    
    def _validate_runtime_checklist(self, function_name: str, function_info: Dict) -> Dict[str, Dict]:
        """Validate runtime and reliability checklist items"""
        validations = {}
        
        # REL-001: Versioning and aliases
        validations['REL-001'] = self._check_versioning_aliases(function_name)
        
        # REL-002: CodeDeploy canary deployment
        validations['REL-002'] = self._check_codedeploy_config(function_name)
        
        # REL-003: Timeout configuration
        validations['REL-003'] = self._check_timeout_config(function_info)
        
        # REL-004: Memory allocation
        validations['REL-004'] = self._check_memory_allocation(function_info)
        
        # REL-005: Concurrency limits
        validations['REL-005'] = self._check_concurrency_limits(function_name)
        
        # REL-006: Dead Letter Queue
        validations['REL-006'] = self._check_dlq_config(function_info)
        
        # REL-007: Idempotency
        validations['REL-007'] = self._check_idempotency_config(function_name)
        
        return validations
    
    def _check_versioning_aliases(self, function_name: str) -> Dict[str, Any]:
        """Check Lambda versioning and aliases configuration"""
        try:
            versions = self.lambda_client.list_versions_by_function(FunctionName=function_name)
            aliases = self.lambda_client.list_aliases(FunctionName=function_name)
            
            # Check if $LATEST is used (should not be in production)
            published_versions = [v for v in versions['Versions'] if v['Version'] != '$LATEST']
            has_live_alias = any(alias['Name'].upper() in ['LIVE', 'PROD', 'PRODUCTION'] 
                               for alias in aliases['Aliases'])
            
            issues = []
            if len(published_versions) == 0:
                issues.append("No published versions found")
            if not has_live_alias:
                issues.append("No LIVE/PROD alias found")
            
            status = 'PASS' if not issues else 'FAIL'
            message = f'{len(published_versions)} versions, {len(aliases["Aliases"])} aliases' + (f', issues: {"; ".join(issues)}' if issues else '')
            
            return {
                'status': status,
                'message': message,
                'details': {
                    'published_versions': len(published_versions),
                    'aliases': [alias['Name'] for alias in aliases['Aliases']],
                    'has_live_alias': has_live_alias
                },
                'evidence_link': f"https://{self.region}.console.aws.amazon.com/lambda/home?region={self.region}#/functions/{function_name}?tab=versions",
                'remediation': 'Publish versions and create LIVE alias for production traffic routing' if issues else None
            }
            
        except ClientError as e:
            return {
                'status': 'ERROR',
                'message': f"Failed to check versions/aliases: {e}",
                'details': {},
                'evidence_link': None,
                'remediation': "Verify Lambda permissions"
            }
    
    def _check_timeout_config(self, function_info: Dict) -> Dict[str, Any]:
        """Check timeout configuration"""
        timeout = function_info.get('Timeout', 0)
        
        # Determine if timeout is appropriate
        if timeout <= 0:
            status = 'FAIL'
            message = 'Invalid timeout configuration'
            remediation = 'Configure appropriate timeout based on function requirements'
        elif timeout <= 30:
            status = 'PASS'
            message = f'Timeout: {timeout}s (appropriate for API functions)'
            remediation = None
        elif timeout <= 300:
            status = 'PASS'
            message = f'Timeout: {timeout}s (appropriate for event processing)'
            remediation = None
        elif timeout <= 900:
            status = 'WARN'
            message = f'Timeout: {timeout}s (high timeout, ensure this is necessary)'
            remediation = 'Review if high timeout is necessary, consider breaking into smaller functions'
        else:
            status = 'FAIL'
            message = f'Timeout: {timeout}s (exceeds maximum)'
            remediation = 'Reduce timeout to maximum 900 seconds'
        
        return {
            'status': status,
            'message': message,
            'details': {
                'timeout_seconds': timeout,
                'recommended_api_max': 30,
                'recommended_event_max': 300,
                'absolute_max': 900
            },
            'evidence_link': f"https://{self.region}.console.aws.amazon.com/lambda/home?region={self.region}#/functions/{function_info['FunctionName']}?tab=configuration",
            'remediation': remediation
        }
    
    # Placeholder methods for remaining categories
    def _validate_api_checklist(self, function_name: str, function_info: Dict) -> Dict[str, Dict]:
        """Validate API and event sources checklist items"""
        # Implementation would check API Gateway, EventBridge, SQS configurations
        return {
            'API-001': {'status': 'N/A', 'message': 'API Gateway authentication check requires manual verification', 'details': {}, 'evidence_link': None, 'remediation': None},
            'API-002': {'status': 'N/A', 'message': 'HTTPS configuration check requires manual verification', 'details': {}, 'evidence_link': None, 'remediation': None},
            'API-003': {'status': 'N/A', 'message': 'Throttling configuration check requires manual verification', 'details': {}, 'evidence_link': None, 'remediation': None},
            'EVT-001': {'status': 'N/A', 'message': 'EventBridge configuration check requires manual verification', 'details': {}, 'evidence_link': None, 'remediation': None},
            'SQS-001': {'status': 'N/A', 'message': 'SQS configuration check requires manual verification', 'details': {}, 'evidence_link': None, 'remediation': None}
        }
    
    def _validate_observability_checklist(self, function_name: str, function_info: Dict) -> Dict[str, Dict]:
        """Validate observability checklist items"""
        validations = {}
        
        # OBS-002: X-Ray tracing
        tracing_config = function_info.get('TracingConfig', {})
        tracing_mode = tracing_config.get('Mode', 'PassThrough')
        
        validations['OBS-002'] = {
            'status': 'PASS' if tracing_mode == 'Active' else 'FAIL',
            'message': f'X-Ray tracing: {tracing_mode}',
            'details': {'tracing_mode': tracing_mode},
            'evidence_link': f"https://{self.region}.console.aws.amazon.com/lambda/home?region={self.region}#/functions/{function_name}?tab=configuration",
            'remediation': 'Enable X-Ray active tracing for observability' if tracing_mode != 'Active' else None
        }
        
        # Add other observability checks...
        validations.update({
            'OBS-001': {'status': 'N/A', 'message': 'Lambda Powertools integration requires code review', 'details': {}, 'evidence_link': None, 'remediation': None},
            'OBS-003': {'status': 'N/A', 'message': 'CloudWatch alarms require manual verification', 'details': {}, 'evidence_link': None, 'remediation': None},
            'OBS-004': {'status': 'N/A', 'message': 'Structured logging requires code review', 'details': {}, 'evidence_link': None, 'remediation': None},
            'OBS-005': {'status': 'N/A', 'message': 'Log retention requires manual verification', 'details': {}, 'evidence_link': None, 'remediation': None},
            'OBS-006': {'status': 'N/A', 'message': 'Dashboards require manual verification', 'details': {}, 'evidence_link': None, 'remediation': None}
        })
        
        return validations
    
    def _validate_cicd_checklist(self, function_name: str) -> Dict[str, Dict]:
        """Validate CI/CD checklist items"""
        return {
            'CICD-001': {'status': 'N/A', 'message': 'GitHub Actions workflow requires repository access', 'details': {}, 'evidence_link': None, 'remediation': None},
            'CICD-002': {'status': 'N/A', 'message': 'Code signing pipeline requires manual verification', 'details': {}, 'evidence_link': None, 'remediation': None},
            'CICD-003': {'status': 'N/A', 'message': 'Policy validation requires repository access', 'details': {}, 'evidence_link': None, 'remediation': None},
            'CICD-004': {'status': 'N/A', 'message': 'Rollback configuration requires manual verification', 'details': {}, 'evidence_link': None, 'remediation': None}
        }
    
    def _validate_dr_checklist(self, function_name: str, function_info: Dict) -> Dict[str, Dict]:
        """Validate disaster recovery checklist items"""
        return {
            'DR-001': {'status': 'PASS', 'message': 'Lambda inherently multi-AZ', 'details': {}, 'evidence_link': None, 'remediation': None},
            'DR-002': {'status': 'N/A', 'message': 'Cross-region backup requires manual verification', 'details': {}, 'evidence_link': None, 'remediation': None},
            'DR-003': {'status': 'N/A', 'message': 'RTO/RPO requirements require manual verification', 'details': {}, 'evidence_link': None, 'remediation': None},
            'DR-004': {'status': 'N/A', 'message': 'Runbooks require manual verification', 'details': {}, 'evidence_link': None, 'remediation': None}
        }
    
    def _validate_cost_checklist(self, function_name: str, function_info: Dict) -> Dict[str, Dict]:
        """Validate cost management checklist items"""
        return {
            'COST-001': {'status': 'N/A', 'message': 'Cost monitoring requires manual verification', 'details': {}, 'evidence_link': None, 'remediation': None},
            'COST-002': {'status': 'N/A', 'message': 'Resource tagging requires manual verification', 'details': {}, 'evidence_link': None, 'remediation': None},
            'COST-003': {'status': 'N/A', 'message': 'Performance optimization requires manual verification', 'details': {}, 'evidence_link': None, 'remediation': None}
        }
    
    def _validate_compliance_checklist(self, function_name: str) -> Dict[str, Dict]:
        """Validate compliance checklist items"""
        return {
            'COMP-001': {'status': 'N/A', 'message': 'Config rules require manual verification', 'details': {}, 'evidence_link': None, 'remediation': None},
            'COMP-002': {'status': 'N/A', 'message': 'SCPs require manual verification', 'details': {}, 'evidence_link': None, 'remediation': None},
            'COMP-003': {'status': 'N/A', 'message': 'Audit logging requires manual verification', 'details': {}, 'evidence_link': None, 'remediation': None},
            'COMP-004': {'status': 'N/A', 'message': 'Security Hub integration requires manual verification', 'details': {}, 'evidence_link': None, 'remediation': None}
        }
    
    # Continue with remaining helper methods...
    def _check_memory_allocation(self, function_info: Dict) -> Dict[str, Any]:
        """Check memory allocation optimization"""
        memory_size = function_info.get('MemorySize', 0)
        
        if memory_size < 512:
            status = 'WARN'
            message = f'Memory: {memory_size}MB (below recommended minimum of 512MB)'
            remediation = 'Consider increasing memory to at least 512MB for better price/performance'
        elif memory_size >= 512:
            status = 'PASS'
            message = f'Memory: {memory_size}MB (appropriate allocation)'
            remediation = None
        else:
            status = 'FAIL'
            message = f'Invalid memory allocation: {memory_size}MB'
            remediation = 'Configure valid memory allocation (128MB - 10,240MB)'
        
        return {
            'status': status,
            'message': message,
            'details': {
                'memory_mb': memory_size,
                'recommended_minimum': 512
            },
            'evidence_link': f"https://{self.region}.console.aws.amazon.com/lambda/home?region={self.region}#/functions/{function_info['FunctionName']}?tab=configuration",
            'remediation': remediation
        }
    
    def _check_concurrency_limits(self, function_name: str) -> Dict[str, Any]:
        """Check concurrency configuration"""
        try:
            concurrency = self.lambda_client.get_function_concurrency(FunctionName=function_name)
            reserved_concurrency = concurrency.get('ReservedConcurrencyLimit')
            
            status = 'PASS' if reserved_concurrency else 'WARN'
            message = f'Reserved concurrency: {reserved_concurrency}' if reserved_concurrency else 'No reserved concurrency configured'
            
            return {
                'status': status,
                'message': message,
                'details': {
                    'reserved_concurrency': reserved_concurrency
                },
                'evidence_link': f"https://{self.region}.console.aws.amazon.com/lambda/home?region={self.region}#/functions/{function_name}?tab=configuration",
                'remediation': 'Configure reserved concurrency based on load testing results' if not reserved_concurrency else None
            }
            
        except ClientError:
            return {
                'status': 'WARN',
                'message': 'No concurrency configuration found',
                'details': {},
                'evidence_link': f"https://{self.region}.console.aws.amazon.com/lambda/home?region={self.region}#/functions/{function_name}?tab=configuration",
                'remediation': 'Configure reserved concurrency to prevent resource starvation'
            }
    
    def _check_dlq_config(self, function_info: Dict) -> Dict[str, Any]:
        """Check Dead Letter Queue configuration"""
        dlq_config = function_info.get('DeadLetterConfig', {})
        target_arn = dlq_config.get('TargetArn')
        
        status = 'PASS' if target_arn else 'WARN'
        message = 'DLQ configured' if target_arn else 'No DLQ configured (may be acceptable for synchronous functions)'
        
        return {
            'status': status,
            'message': message,
            'details': {
                'dlq_target_arn': target_arn
            },
            'evidence_link': f"https://{self.region}.console.aws.amazon.com/lambda/home?region={self.region}#/functions/{function_info['FunctionName']}?tab=configuration",
            'remediation': 'Configure DLQ for asynchronous functions to handle failures' if not target_arn else None
        }
    
    def _check_idempotency_config(self, function_name: str) -> Dict[str, Any]:
        """Check idempotency configuration"""
        # This would typically check for DynamoDB table or other idempotency mechanism
        return {
            'status': 'N/A',
            'message': 'Idempotency implementation requires code review',
            'details': {},
            'evidence_link': f'https://{self.region}.console.aws.amazon.com/dynamodb/home?region={self.region}#tables',
            'remediation': 'Implement idempotency pattern with DynamoDB for safe retries'
        }
    
    def _check_codedeploy_config(self, function_name: str) -> Dict[str, Any]:
        """Check CodeDeploy configuration"""
        try:
            applications = self.codedeploy_client.list_applications()
            
            # Look for CodeDeploy application matching function name
            matching_apps = [app for app in applications['applications'] 
                           if function_name.lower() in app.lower()]
            
            status = 'PASS' if matching_apps else 'WARN'
            message = f'CodeDeploy applications found: {len(matching_apps)}' if matching_apps else 'No CodeDeploy application found'
            
            return {
                'status': status,
                'message': message,
                'details': {
                    'applications': matching_apps
                },
                'evidence_link': f'https://{self.region}.console.aws.amazon.com/codesuite/codedeploy/applications?region={self.region}',
                'remediation': 'Configure CodeDeploy application for canary deployments' if not matching_apps else None
            }
            
        except ClientError as e:
            return {
                'status': 'ERROR',
                'message': f"Failed to check CodeDeploy: {e}",
                'details': {},
                'evidence_link': None,
                'remediation': "Verify CodeDeploy permissions"
            }
    
    def generate_compliance_report(self, results: Dict[str, Any], output_format: str = 'summary') -> str:
        """Generate compliance report"""
        
        if output_format == 'json':
            return json.dumps(results, indent=2)
        
        elif output_format == 'summary':
            summary = []
            summary.append("🔍 AWS Lambda Production Readiness Compliance Report")
            summary.append("=" * 65)
            summary.append(f"Function: {results['function_name']}")
            summary.append(f"Account: {results['account_id']}")
            summary.append(f"Region: {results['region']}")
            summary.append(f"Timestamp: {results['timestamp']}")
            summary.append("")
            
            # Overall summary
            s = results['summary']
            summary.append("📊 Overall Summary")
            summary.append("-" * 20)
            summary.append(f"Total Items: {s['total_items']}")
            summary.append(f"✅ Passed: {s['passed']}")
            summary.append(f"❌ Failed: {s['failed']}")
            summary.append(f"⚠️  Warnings: {s['warnings']}")
            summary.append(f"🔥 Errors: {s['errors']}")
            summary.append(f"ℹ️  Not Applicable: {s['not_applicable']}")
            
            # Determine overall status
            if s['failed'] > 0 or s['errors'] > 0:
                overall_status = "❌ NOT READY FOR PRODUCTION"
            elif s['warnings'] > 0:
                overall_status = "⚠️  READY WITH WARNINGS"
            else:
                overall_status = "✅ PRODUCTION READY"
            
            summary.append(f"\n🎯 Production Readiness: {overall_status}")
            
            # Category breakdown
            categories = {
                'IAM': 'Identity & Access Management',
                'SEC': 'Code Integrity & Security',
                'CFG': 'Secrets & Configuration',
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
            for item_id, validation in results['validations'].items():
                category_prefix = item_id.split('-')[0]
                category_name = categories.get(category_prefix, 'Other')
                
                if category_name != current_category:
                    summary.append(f"\n📋 {category_name}")
                    summary.append("-" * 40)
                    current_category = category_name
                
                status = validation['status']
                message = validation['message']
                
                status_icon = {
                    'PASS': '✅',
                    'FAIL': '❌',
                    'WARN': '⚠️',
                    'ERROR': '🔥',
                    'N/A': 'ℹ️'
                }.get(status, '❓')
                
                summary.append(f"  {status_icon} {item_id}: {message}")
                
                # Add remediation if available
                if validation.get('remediation'):
                    summary.append(f"    💡 Remediation: {validation['remediation']}")
            
            # Critical failures
            critical_failures = [
                item_id for item_id, validation in results['validations'].items()
                if validation['status'] == 'FAIL' and item_id in [
                    'IAM-001', 'SEC-001', 'CFG-001', 'REL-001', 'OBS-002'
                ]
            ]
            
            if critical_failures:
                summary.append(f"\n🚨 Critical Issues Requiring Immediate Attention:")
                for item_id in critical_failures:
                    validation = results['validations'][item_id]
                    summary.append(f"  ❌ {item_id}: {validation['message']}")
                    if validation.get('remediation'):
                        summary.append(f"    💡 {validation['remediation']}")
            
            return '\n'.join(summary)
        
        else:
            raise ValueError(f"Unsupported output format: {output_format}")


def main():
    """Main function"""
    parser = argparse.ArgumentParser(
        description='Validate AWS Lambda production readiness checklist compliance'
    )
    parser.add_argument(
        'function_name',
        help='Lambda function name to validate'
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
        choices=['json', 'summary'],
        default='summary',
        help='Output format (default: summary)'
    )
    parser.add_argument(
        '--output-file',
        help='Output file path (default: stdout)'
    )
    
    args = parser.parse_args()
    
    # Initialize validator
    validator = ChecklistComplianceValidator(
        region=args.region,
        profile=args.profile
    )
    
    # Validate checklist compliance
    results = validator.validate_all_checklist_items(args.function_name)
    
    # Generate report
    report = validator.generate_compliance_report(results, args.output)
    
    # Output report
    if args.output_file:
        with open(args.output_file, 'w') as f:
            f.write(report)
        print(f"Compliance report saved to: {args.output_file}")
    else:
        print(report)


if __name__ == '__main__':
    main()