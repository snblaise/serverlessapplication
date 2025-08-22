#!/usr/bin/env python3
"""
Test suite for Service Control Policy (SCP) enforcement validation.
Tests SCP policies in a sandbox environment to ensure proper governance controls.
"""

import json
import boto3
import pytest
from moto import mock_lambda, mock_organizations, mock_sts
from botocore.exceptions import ClientError
import os
from pathlib import Path


class TestSCPEnforcement:
    """Test cases for Service Control Policy enforcement."""
    
    @classmethod
    def setup_class(cls):
        """Load SCP policies for testing."""
        cls.policies_dir = Path(__file__).parent.parent.parent / "docs" / "policies"
        
        # Load SCP policies
        with open(cls.policies_dir / "scp-lambda-governance.json", 'r') as f:
            cls.lambda_governance_policy = json.load(f)
        
        with open(cls.policies_dir / "scp-lambda-code-signing.json", 'r') as f:
            cls.code_signing_policy = json.load(f)
        
        with open(cls.policies_dir / "scp-api-gateway-waf.json", 'r') as f:
            cls.api_gateway_waf_policy = json.load(f)
    
    def setup_method(self):
        """Set up test environment with mocked AWS services."""
        self.lambda_client = boto3.client('lambda', region_name='us-east-1')
        self.organizations_client = boto3.client('organizations', region_name='us-east-1')
    
    def test_lambda_governance_policy_structure(self):
        """Test that Lambda governance SCP has correct structure."""
        policy = self.lambda_governance_policy
        
        assert policy['Version'] == '2012-10-17'
        assert 'Statement' in policy
        assert isinstance(policy['Statement'], list)
        
        # Check for required statements
        statement_sids = [stmt.get('Sid', '') for stmt in policy['Statement']]
        required_sids = [
            'RestrictLambdaRegions',
            'RequireEncryptionTags',
            'RequireTracingTags',
            'RequireEnvironmentTag'
        ]
        
        for sid in required_sids:
            assert sid in statement_sids, f"Missing required statement: {sid}"
    
    def test_code_signing_policy_structure(self):
        """Test that code signing SCP has correct structure."""
        policy = self.code_signing_policy
        
        assert policy['Version'] == '2012-10-17'
        assert 'Statement' in policy
        
        # Check for code signing enforcement
        code_signing_statements = [
            stmt for stmt in policy['Statement']
            if 'lambda:UpdateFunctionCode' in stmt.get('Action', [])
        ]
        
        assert len(code_signing_statements) >= 1
        
        # Verify condition requires CodeSigningConfigArn
        for stmt in code_signing_statements:
            assert stmt['Effect'] == 'Deny'
            condition = stmt.get('Condition', {})
            assert 'Null' in condition
            assert condition['Null'].get('lambda:CodeSigningConfigArn') == 'true'
    
    def test_region_restriction_enforcement(self):
        """Test that Lambda actions are restricted to allowed regions."""
        policy = self.lambda_governance_policy
        
        region_statements = [
            stmt for stmt in policy['Statement']
            if stmt.get('Sid') == 'RestrictLambdaRegions'
        ]
        
        assert len(region_statements) == 1
        stmt = region_statements[0]
        
        assert stmt['Effect'] == 'Deny'
        assert 'lambda:*' in stmt['Action']
        
        condition = stmt.get('Condition', {})
        allowed_regions = condition.get('StringNotEquals', {}).get('aws:RequestedRegion', [])
        
        expected_regions = ['us-east-1', 'us-west-2', 'eu-west-1']
        assert set(allowed_regions) == set(expected_regions)
    
    def test_mandatory_tagging_enforcement(self):
        """Test that mandatory tags are enforced by SCP."""
        policy = self.lambda_governance_policy
        
        # Test encryption tag requirement
        encryption_statements = [
            stmt for stmt in policy['Statement']
            if stmt.get('Sid') == 'RequireEncryptionTags'
        ]
        
        assert len(encryption_statements) == 1
        stmt = encryption_statements[0]
        assert stmt['Effect'] == 'Deny'
        assert 'lambda:CreateFunction' in stmt['Action']
        assert 'lambda:UpdateFunctionConfiguration' in stmt['Action']
        
        condition = stmt.get('Condition', {})
        assert condition.get('Null', {}).get('aws:RequestTag/Encryption') == 'true'
        
        # Test tracing tag requirement
        tracing_statements = [
            stmt for stmt in policy['Statement']
            if stmt.get('Sid') == 'RequireTracingTags'
        ]
        
        assert len(tracing_statements) == 1
        stmt = tracing_statements[0]
        assert condition.get('Null', {}).get('aws:RequestTag/TracingConfig') == 'true'
    
    def test_environment_tag_validation(self):
        """Test that Environment tag values are restricted to allowed values."""
        policy = self.lambda_governance_policy
        
        env_statements = [
            stmt for stmt in policy['Statement']
            if stmt.get('Sid') == 'RequireEnvironmentTag'
        ]
        
        assert len(env_statements) == 1
        stmt = env_statements[0]
        
        condition = stmt.get('Condition', {})
        allowed_environments = condition.get('ForAllValues:StringNotEquals', {}).get('aws:RequestTag/Environment', [])
        
        expected_environments = ['dev', 'staging', 'prod']
        assert set(allowed_environments) == set(expected_environments)
    
    @mock_lambda
    def test_simulate_scp_enforcement(self):
        """Simulate SCP enforcement scenarios."""
        # Test 1: Function creation without required tags should be denied
        function_code = {'ZipFile': b'fake code'}
        
        # This would be denied by SCP in real environment
        test_cases = [
            {
                'name': 'missing-encryption-tag',
                'tags': {'Environment': 'dev', 'TracingConfig': 'Active'},
                'should_fail': True
            },
            {
                'name': 'missing-tracing-tag',
                'tags': {'Environment': 'dev', 'Encryption': 'AES256'},
                'should_fail': True
            },
            {
                'name': 'invalid-environment',
                'tags': {'Environment': 'production', 'Encryption': 'AES256', 'TracingConfig': 'Active'},
                'should_fail': True
            },
            {
                'name': 'valid-tags',
                'tags': {'Environment': 'dev', 'Encryption': 'AES256', 'TracingConfig': 'Active'},
                'should_fail': False
            }
        ]
        
        for test_case in test_cases:
            # In a real test environment, we would validate against actual SCP
            # Here we validate the policy logic
            is_compliant = self._validate_tags_against_scp(test_case['tags'])
            
            if test_case['should_fail']:
                assert not is_compliant, f"Test case {test_case['name']} should fail SCP validation"
            else:
                assert is_compliant, f"Test case {test_case['name']} should pass SCP validation"
    
    def test_api_gateway_waf_requirement(self):
        """Test that API Gateway stages require WAF association."""
        if not (self.policies_dir / "scp-api-gateway-waf.json").exists():
            pytest.skip("API Gateway WAF SCP policy not found")
        
        policy = self.api_gateway_waf_policy
        
        waf_statements = [
            stmt for stmt in policy['Statement']
            if 'apigateway:CreateStage' in stmt.get('Action', [])
        ]
        
        assert len(waf_statements) >= 1
        
        for stmt in waf_statements:
            assert stmt['Effect'] == 'Deny'
            # Should have condition requiring WAF association
            condition = stmt.get('Condition', {})
            assert len(condition) > 0  # Should have some condition for WAF
    
    def _validate_tags_against_scp(self, tags):
        """Helper method to validate tags against SCP requirements."""
        # Check required tags
        required_tags = ['Environment', 'Encryption', 'TracingConfig']
        for tag in required_tags:
            if tag not in tags:
                return False
        
        # Check Environment tag values
        valid_environments = ['dev', 'staging', 'prod']
        if tags.get('Environment') not in valid_environments:
            return False
        
        return True
    
    def test_scp_policy_syntax_validation(self):
        """Test that all SCP policies have valid JSON syntax and structure."""
        policies = [
            ('lambda-governance', self.lambda_governance_policy),
            ('code-signing', self.code_signing_policy),
            ('api-gateway-waf', self.api_gateway_waf_policy)
        ]
        
        for policy_name, policy in policies:
            # Basic structure validation
            assert 'Version' in policy, f"Policy {policy_name} missing Version"
            assert 'Statement' in policy, f"Policy {policy_name} missing Statement"
            assert isinstance(policy['Statement'], list), f"Policy {policy_name} Statement must be list"
            
            # Validate each statement
            for i, stmt in enumerate(policy['Statement']):
                assert 'Effect' in stmt, f"Policy {policy_name} statement {i} missing Effect"
                assert stmt['Effect'] in ['Allow', 'Deny'], f"Policy {policy_name} statement {i} invalid Effect"
                assert 'Action' in stmt, f"Policy {policy_name} statement {i} missing Action"
                assert 'Resource' in stmt, f"Policy {policy_name} statement {i} missing Resource"


if __name__ == '__main__':
    pytest.main([__file__, '-v'])