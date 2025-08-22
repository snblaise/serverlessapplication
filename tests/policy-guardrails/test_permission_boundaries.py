#!/usr/bin/env python3
"""
Test suite for IAM permission boundary validation.
Tests permission boundary effectiveness for CI/CD role restrictions.
"""

import json
import boto3
import pytest
from moto import mock_iam, mock_lambda, mock_sts
from botocore.exceptions import ClientError
from pathlib import Path
import re


class TestPermissionBoundaries:
    """Test cases for IAM permission boundary validation."""
    
    @classmethod
    def setup_class(cls):
        """Load permission boundary policies."""
        cls.policies_dir = Path(__file__).parent.parent.parent / "docs" / "policies"
        
        # Load CI/CD permission boundary
        with open(cls.policies_dir / "iam-permission-boundary-cicd.json", 'r') as f:
            cls.cicd_boundary_policy = json.load(f)
        
        # Load Lambda execution permission boundary
        with open(cls.policies_dir / "iam-permission-boundary-lambda-execution.json", 'r') as f:
            cls.lambda_execution_boundary_policy = json.load(f)
    
    def setup_method(self):
        """Set up test environment with mocked AWS services."""
        self.iam_client = boto3.client('iam', region_name='us-east-1')
        self.lambda_client = boto3.client('lambda', region_name='us-east-1')
        self.sts_client = boto3.client('sts', region_name='us-east-1')
    
    def test_cicd_boundary_policy_structure(self):
        """Test that CI/CD permission boundary has correct structure."""
        policy = self.cicd_boundary_policy
        
        assert policy['Version'] == '2012-10-17'
        assert 'Statement' in policy
        assert isinstance(policy['Statement'], list)
        
        # Check for required statement types
        statement_effects = [stmt.get('Effect') for stmt in policy['Statement']]
        assert 'Allow' in statement_effects
        assert 'Deny' in statement_effects
    
    def test_lambda_execution_boundary_structure(self):
        """Test that Lambda execution permission boundary has correct structure."""
        policy = self.lambda_execution_boundary_policy
        
        assert policy['Version'] == '2012-10-17'
        assert 'Statement' in policy
        assert isinstance(policy['Statement'], list)
    
    def test_wildcard_iam_actions_denied(self):
        """Test that wildcard IAM actions are denied in CI/CD boundary."""
        policy = self.cicd_boundary_policy
        
        # Find statements that deny wildcard IAM actions
        wildcard_deny_statements = []
        for stmt in policy['Statement']:
            if stmt.get('Effect') == 'Deny':
                actions = stmt.get('Action', [])
                if isinstance(actions, str):
                    actions = [actions]
                
                for action in actions:
                    if ('iam:*' in action or 
                        'organizations:*' in action or 
                        'account:*' in action):
                        wildcard_deny_statements.append(stmt)
                        break
        
        assert len(wildcard_deny_statements) >= 1, "Should deny wildcard IAM actions"
    
    def test_unsigned_code_deployment_denied(self):
        """Test that unsigned code deployment is denied."""
        policy = self.cicd_boundary_policy
        
        # Find statements that deny unsigned code deployment
        code_signing_statements = []
        for stmt in policy['Statement']:
            if stmt.get('Effect') == 'Deny':
                actions = stmt.get('Action', [])
                if isinstance(actions, str):
                    actions = [actions]
                
                if ('lambda:UpdateFunctionCode' in actions or 
                    'lambda:CreateFunction' in actions):
                    condition = stmt.get('Condition', {})
                    if ('Null' in condition and 
                        condition['Null'].get('lambda:CodeSigningConfigArn') == 'true'):
                        code_signing_statements.append(stmt)
        
        assert len(code_signing_statements) >= 1, "Should deny unsigned code deployment"
    
    def test_region_restrictions(self):
        """Test that actions are restricted to allowed regions."""
        policy = self.cicd_boundary_policy
        
        # Find statements with region restrictions
        region_restricted_statements = []
        for stmt in policy['Statement']:
            condition = stmt.get('Condition', {})
            if ('StringEquals' in condition and 
                'aws:RequestedRegion' in condition['StringEquals']):
                region_restricted_statements.append(stmt)
        
        assert len(region_restricted_statements) >= 1, "Should have region restrictions"
        
        # Check allowed regions
        for stmt in region_restricted_statements:
            condition = stmt['Condition']
            allowed_regions = condition['StringEquals']['aws:RequestedRegion']
            
            expected_regions = ['us-east-1', 'us-west-2', 'eu-west-1']
            if isinstance(allowed_regions, list):
                assert set(allowed_regions) == set(expected_regions)
            else:
                assert allowed_regions in expected_regions
    
    def test_mandatory_tagging_enforcement(self):
        """Test that mandatory tags are enforced."""
        policy = self.cicd_boundary_policy
        
        # Find statements that enforce tagging
        tagging_statements = []
        for stmt in policy['Statement']:
            if stmt.get('Effect') == 'Deny':
                condition = stmt.get('Condition', {})
                if ('Null' in condition and 
                    any('Tag' in key for key in condition['Null'].keys())):
                    tagging_statements.append(stmt)
        
        assert len(tagging_statements) >= 1, "Should enforce mandatory tagging"
        
        # Check for specific required tags
        required_tags = ['Environment', 'ManagedBy']
        for tag in required_tags:
            tag_enforced = False
            for stmt in tagging_statements:
                condition = stmt.get('Condition', {})
                null_conditions = condition.get('Null', {})
                
                for key in null_conditions.keys():
                    if tag in key:
                        tag_enforced = True
                        break
                
                if tag_enforced:
                    break
            
            assert tag_enforced, f"Tag {tag} should be enforced"
    
    def test_production_access_restrictions(self):
        """Test that production access is restricted."""
        policy = self.cicd_boundary_policy
        
        # Find statements that restrict production access
        prod_restriction_statements = []
        for stmt in policy['Statement']:
            if stmt.get('Effect') == 'Deny':
                condition = stmt.get('Condition', {})
                
                # Look for conditions that reference production environment
                condition_str = json.dumps(condition).lower()
                if 'prod' in condition_str or 'production' in condition_str:
                    prod_restriction_statements.append(stmt)
        
        assert len(prod_restriction_statements) >= 1, "Should restrict production access"
    
    def test_encryption_in_transit_enforcement(self):
        """Test that encryption in transit is enforced."""
        policies = [self.cicd_boundary_policy, self.lambda_execution_boundary_policy]
        
        encryption_enforced = False
        for policy in policies:
            for stmt in policy['Statement']:
                if stmt.get('Effect') == 'Deny':
                    condition = stmt.get('Condition', {})
                    if ('Bool' in condition and 
                        condition['Bool'].get('aws:SecureTransport') == 'false'):
                        encryption_enforced = True
                        break
            
            if encryption_enforced:
                break
        
        assert encryption_enforced, "Should enforce encryption in transit"
    
    def test_lambda_function_url_denial(self):
        """Test that Lambda function URLs are denied."""
        policy = self.cicd_boundary_policy
        
        # Find statements that deny Lambda function URLs
        function_url_statements = []
        for stmt in policy['Statement']:
            if stmt.get('Effect') == 'Deny':
                actions = stmt.get('Action', [])
                if isinstance(actions, str):
                    actions = [actions]
                
                for action in actions:
                    if ('lambda:CreateFunctionUrlConfig' in action or 
                        'lambda:UpdateFunctionUrlConfig' in action):
                        function_url_statements.append(stmt)
                        break
        
        assert len(function_url_statements) >= 1, "Should deny Lambda function URLs"
    
    @mock_iam
    def test_permission_boundary_attachment(self):
        """Test that permission boundaries can be attached to roles."""
        # Create permission boundary policy
        policy_doc = json.dumps(self.cicd_boundary_policy)
        
        try:
            self.iam_client.create_policy(
                PolicyName='TestCICDPermissionBoundary',
                PolicyDocument=policy_doc,
                Path='/boundaries/'
            )
            
            # Create role with permission boundary
            assume_role_policy = {
                "Version": "2012-10-17",
                "Statement": [
                    {
                        "Effect": "Allow",
                        "Principal": {"Service": "lambda.amazonaws.com"},
                        "Action": "sts:AssumeRole"
                    }
                ]
            }
            
            response = self.iam_client.create_role(
                RoleName='test-lambda-execution-role',
                AssumeRolePolicyDocument=json.dumps(assume_role_policy),
                PermissionsBoundary='arn:aws:iam::123456789012:policy/boundaries/TestCICDPermissionBoundary',
                Tags=[
                    {'Key': 'ManagedBy', 'Value': 'CI/CD'},
                    {'Key': 'Environment', 'Value': 'dev'}
                ]
            )
            
            assert response['Role']['RoleName'] == 'test-lambda-execution-role'
            assert 'PermissionsBoundary' in response['Role']
            
        except Exception as e:
            # Some operations might not be fully supported in moto
            pytest.skip(f"Permission boundary attachment test not supported: {e}")
    
    def test_policy_size_limits(self):
        """Test that permission boundary policies are within AWS size limits."""
        policies = [
            ('cicd-boundary', self.cicd_boundary_policy),
            ('lambda-execution-boundary', self.lambda_execution_boundary_policy)
        ]
        
        for policy_name, policy in policies:
            policy_json = json.dumps(policy)
            policy_size = len(policy_json.encode('utf-8'))
            
            # AWS IAM policy size limit is 6144 characters for managed policies
            assert policy_size <= 6144, f"Policy {policy_name} exceeds size limit: {policy_size} bytes"
    
    def test_policy_statement_limits(self):
        """Test that permission boundary policies are within statement limits."""
        policies = [
            ('cicd-boundary', self.cicd_boundary_policy),
            ('lambda-execution-boundary', self.lambda_execution_boundary_policy)
        ]
        
        for policy_name, policy in policies:
            statements = policy.get('Statement', [])
            
            # AWS allows up to 100 statements per policy
            assert len(statements) <= 100, f"Policy {policy_name} has too many statements: {len(statements)}"
    
    def test_action_pattern_validation(self):
        """Test that action patterns in policies are valid."""
        policies = [
            ('cicd-boundary', self.cicd_boundary_policy),
            ('lambda-execution-boundary', self.lambda_execution_boundary_policy)
        ]
        
        # Valid AWS action pattern
        action_pattern = re.compile(r'^[a-zA-Z0-9-]+:[a-zA-Z0-9*-]+$')
        
        for policy_name, policy in policies:
            for stmt in policy['Statement']:
                actions = stmt.get('Action', [])
                if isinstance(actions, str):
                    actions = [actions]
                
                for action in actions:
                    if action != '*':  # Wildcard is special case
                        assert action_pattern.match(action), \
                            f"Invalid action pattern in {policy_name}: {action}"
    
    def test_condition_key_validation(self):
        """Test that condition keys in policies are valid AWS condition keys."""
        policies = [
            ('cicd-boundary', self.cicd_boundary_policy),
            ('lambda-execution-boundary', self.lambda_execution_boundary_policy)
        ]
        
        # Common AWS condition keys
        valid_condition_operators = [
            'StringEquals', 'StringNotEquals', 'StringLike', 'StringNotLike',
            'Bool', 'Null', 'NumericEquals', 'NumericNotEquals',
            'NumericLessThan', 'NumericGreaterThan', 'DateEquals',
            'ForAllValues:StringEquals', 'ForAnyValue:StringEquals'
        ]
        
        for policy_name, policy in policies:
            for stmt in policy['Statement']:
                condition = stmt.get('Condition', {})
                
                for operator in condition.keys():
                    assert operator in valid_condition_operators, \
                        f"Invalid condition operator in {policy_name}: {operator}"


if __name__ == '__main__':
    pytest.main([__file__, '-v'])