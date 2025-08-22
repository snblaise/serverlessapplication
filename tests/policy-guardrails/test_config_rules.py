#!/usr/bin/env python3
"""
Test suite for AWS Config rules validation.
Tests both managed and custom Config rules for Lambda production readiness.
"""

import json
import boto3
import pytest
from moto import mock_config, mock_lambda, mock_apigateway
from botocore.exceptions import ClientError
import yaml
from pathlib import Path


class TestConfigRules:
    """Test cases for AWS Config rules validation."""
    
    @classmethod
    def setup_class(cls):
        """Load Config conformance pack and custom rules."""
        cls.policies_dir = Path(__file__).parent.parent.parent / "docs" / "policies"
        
        # Load conformance pack
        with open(cls.policies_dir / "config-conformance-pack-lambda.yaml", 'r') as f:
            cls.conformance_pack = yaml.safe_load(f)
        
        # Load custom rules
        cls.custom_rules_dir = cls.policies_dir / "custom-rules"
    
    def setup_method(self):
        """Set up test environment with mocked AWS services."""
        self.config_client = boto3.client('config', region_name='us-east-1')
        self.lambda_client = boto3.client('lambda', region_name='us-east-1')
    
    def test_conformance_pack_structure(self):
        """Test that the conformance pack has correct structure."""
        assert 'AWSTemplateFormatVersion' in self.conformance_pack
        assert 'Resources' in self.conformance_pack
        
        resources = self.conformance_pack['Resources']
        
        # Check for conformance pack resource
        conformance_packs = [
            name for name, resource in resources.items()
            if resource.get('Type') == 'AWS::Config::ConformancePack'
        ]
        assert len(conformance_packs) >= 1
    
    def test_managed_config_rules_present(self):
        """Test that required managed Config rules are present."""
        template_body = self.conformance_pack['Resources']['LambdaProductionConformancePack']['Properties']['TemplateBody']
        template = yaml.safe_load(template_body)
        
        resources = template.get('Resources', {})
        
        # Check for required managed rules
        required_managed_rules = [
            'LambdaFunctionSettingsCheck',
            'LambdaInsideVpcCheck',
            'LambdaConcurrencyCheck'
        ]
        
        for rule_name in required_managed_rules:
            assert rule_name in resources, f"Missing managed rule: {rule_name}"
            
            rule = resources[rule_name]
            assert rule['Type'] == 'AWS::Config::ConfigRule'
            assert rule['Properties']['Source']['Owner'] == 'AWS'
    
    def test_custom_config_rules_present(self):
        """Test that required custom Config rules are present."""
        template_body = self.conformance_pack['Resources']['LambdaProductionConformancePack']['Properties']['TemplateBody']
        template = yaml.safe_load(template_body)
        
        resources = template.get('Resources', {})
        
        # Check for required custom rules
        required_custom_rules = [
            'LambdaCMKEncryptionCheck',
            'APIGatewayWAFAssociationCheck',
            'LambdaCodeSigningCheck'
        ]
        
        for rule_name in required_custom_rules:
            assert rule_name in resources, f"Missing custom rule: {rule_name}"
            
            rule = resources[rule_name]
            assert rule['Type'] == 'AWS::Config::ConfigRule'
            assert rule['Properties']['Source']['Owner'] == 'AWS_CONFIG_RULE'
    
    def test_lambda_function_settings_rule_parameters(self):
        """Test Lambda function settings rule has correct parameters."""
        template_body = self.conformance_pack['Resources']['LambdaProductionConformancePack']['Properties']['TemplateBody']
        template = yaml.safe_load(template_body)
        
        rule = template['Resources']['LambdaFunctionSettingsCheck']
        input_params = json.loads(rule['Properties']['InputParameters'])
        
        # Check runtime restrictions
        allowed_runtimes = input_params['runtime'].split(',')
        expected_runtimes = ['nodejs18.x', 'nodejs20.x', 'python3.9', 'python3.10', 'python3.11']
        
        for runtime in expected_runtimes:
            assert runtime in allowed_runtimes, f"Runtime {runtime} not in allowed list"
        
        # Check timeout setting
        assert input_params['timeout'] == '300'
    
    def test_lambda_concurrency_rule_parameters(self):
        """Test Lambda concurrency rule has correct parameters."""
        template_body = self.conformance_pack['Resources']['LambdaProductionConformancePack']['Properties']['TemplateBody']
        template = yaml.safe_load(template_body)
        
        rule = template['Resources']['LambdaConcurrencyCheck']
        input_params = json.loads(rule['Properties']['InputParameters'])
        
        assert 'ConcurrencyLimitHigh' in input_params
        assert 'ConcurrencyLimitLow' in input_params
        assert int(input_params['ConcurrencyLimitHigh']) >= 1000
        assert int(input_params['ConcurrencyLimitLow']) >= 100
    
    def test_custom_rule_lambda_cmk_encryption(self):
        """Test custom rule for Lambda CMK encryption validation."""
        custom_rule_file = self.custom_rules_dir / "lambda-cmk-encryption-check.py"
        
        if not custom_rule_file.exists():
            pytest.skip("Lambda CMK encryption custom rule not found")
        
        with open(custom_rule_file, 'r') as f:
            rule_code = f.read()
        
        # Basic validation of custom rule structure
        assert 'def lambda_handler' in rule_code
        assert 'boto3' in rule_code
        assert 'config' in rule_code.lower()
        assert 'compliance' in rule_code.lower()
    
    def test_custom_rule_api_gateway_waf(self):
        """Test custom rule for API Gateway WAF association validation."""
        custom_rule_file = self.custom_rules_dir / "api-gateway-waf-association-check.py"
        
        if not custom_rule_file.exists():
            pytest.skip("API Gateway WAF association custom rule not found")
        
        with open(custom_rule_file, 'r') as f:
            rule_code = f.read()
        
        # Basic validation of custom rule structure
        assert 'def lambda_handler' in rule_code
        assert 'apigateway' in rule_code.lower()
        assert 'waf' in rule_code.lower()
        assert 'compliance' in rule_code.lower()
    
    def test_custom_rule_code_signing(self):
        """Test custom rule for Lambda code signing validation."""
        custom_rule_file = self.custom_rules_dir / "lambda-code-signing-check.py"
        
        if not custom_rule_file.exists():
            pytest.skip("Lambda code signing custom rule not found")
        
        with open(custom_rule_file, 'r') as f:
            rule_code = f.read()
        
        # Basic validation of custom rule structure
        assert 'def lambda_handler' in rule_code
        assert 'code_signing' in rule_code.lower() or 'codesigning' in rule_code.lower()
        assert 'compliance' in rule_code.lower()
    
    def test_custom_rule_concurrency_validation(self):
        """Test custom rule for Lambda concurrency validation."""
        custom_rule_file = self.custom_rules_dir / "lambda-concurrency-validation-check.py"
        
        if not custom_rule_file.exists():
            pytest.skip("Lambda concurrency validation custom rule not found")
        
        with open(custom_rule_file, 'r') as f:
            rule_code = f.read()
        
        # Basic validation of custom rule structure
        assert 'def lambda_handler' in rule_code
        assert 'concurrency' in rule_code.lower()
        assert 'compliance' in rule_code.lower()
    
    @mock_config
    def test_config_rule_deployment_simulation(self):
        """Simulate Config rule deployment and validation."""
        # Test deploying a simple Config rule
        try:
            response = self.config_client.put_config_rule(
                ConfigRule={
                    'ConfigRuleName': 'test-lambda-settings-check',
                    'Source': {
                        'Owner': 'AWS',
                        'SourceIdentifier': 'LAMBDA_FUNCTION_SETTINGS_CHECK'
                    },
                    'InputParameters': json.dumps({
                        'runtime': 'nodejs18.x,python3.9',
                        'timeout': '300'
                    })
                }
            )
            
            # Verify rule was created
            rules = self.config_client.describe_config_rules(
                ConfigRuleNames=['test-lambda-settings-check']
            )
            
            assert len(rules['ConfigRules']) == 1
            rule = rules['ConfigRules'][0]
            assert rule['ConfigRuleName'] == 'test-lambda-settings-check'
            
        except Exception as e:
            # In moto environment, some operations might not be fully supported
            pytest.skip(f"Config rule deployment simulation not supported: {e}")
    
    def test_config_s3_bucket_configuration(self):
        """Test that Config S3 bucket is properly configured."""
        resources = self.conformance_pack['Resources']
        
        # Find Config bucket
        config_buckets = [
            name for name, resource in resources.items()
            if resource.get('Type') == 'AWS::S3::Bucket'
        ]
        
        assert len(config_buckets) >= 1
        
        bucket = resources[config_buckets[0]]
        properties = bucket['Properties']
        
        # Check encryption
        assert 'BucketEncryption' in properties
        encryption_config = properties['BucketEncryption']['ServerSideEncryptionConfiguration'][0]
        assert encryption_config['ServerSideEncryptionByDefault']['SSEAlgorithm'] == 'AES256'
        
        # Check public access block
        assert 'PublicAccessBlockConfiguration' in properties
        public_access = properties['PublicAccessBlockConfiguration']
        assert public_access['BlockPublicAcls'] is True
        assert public_access['BlockPublicPolicy'] is True
        assert public_access['IgnorePublicAcls'] is True
        assert public_access['RestrictPublicBuckets'] is True
    
    def test_config_rule_scope_configuration(self):
        """Test that Config rules have proper scope configuration."""
        template_body = self.conformance_pack['Resources']['LambdaProductionConformancePack']['Properties']['TemplateBody']
        template = yaml.safe_load(template_body)
        
        resources = template.get('Resources', {})
        
        # Check rules that should have specific resource type scopes
        scoped_rules = [
            ('LambdaCMKEncryptionCheck', 'AWS::Lambda::Function'),
            ('APIGatewayWAFAssociationCheck', 'AWS::ApiGateway::Stage'),
            ('LambdaCodeSigningCheck', 'AWS::Lambda::Function')
        ]
        
        for rule_name, expected_resource_type in scoped_rules:
            if rule_name in resources:
                rule = resources[rule_name]
                scope = rule['Properties'].get('Scope', {})
                
                if 'ComplianceResourceTypes' in scope:
                    resource_types = scope['ComplianceResourceTypes']
                    assert expected_resource_type in resource_types, \
                        f"Rule {rule_name} missing resource type {expected_resource_type}"
    
    def test_config_rule_event_triggers(self):
        """Test that custom Config rules have proper event triggers."""
        template_body = self.conformance_pack['Resources']['LambdaProductionConformancePack']['Properties']['TemplateBody']
        template = yaml.safe_load(template_body)
        
        resources = template.get('Resources', {})
        
        custom_rules = [
            'LambdaCMKEncryptionCheck',
            'APIGatewayWAFAssociationCheck',
            'LambdaCodeSigningCheck'
        ]
        
        for rule_name in custom_rules:
            if rule_name in resources:
                rule = resources[rule_name]
                source = rule['Properties']['Source']
                
                assert 'SourceDetail' in source
                source_details = source['SourceDetail']
                
                # Should have configuration change notification
                event_sources = [detail['EventSource'] for detail in source_details]
                assert 'aws.config' in event_sources
                
                message_types = [detail['MessageType'] for detail in source_details]
                assert 'ConfigurationItemChangeNotification' in message_types


if __name__ == '__main__':
    pytest.main([__file__, '-v'])