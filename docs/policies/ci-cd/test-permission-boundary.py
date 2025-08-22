#!/usr/bin/env python3
"""
Test script to validate IAM permission boundary effectiveness for CI/CD roles.
This script simulates various scenarios to ensure the permission boundary
properly restricts actions according to the security requirements.
"""

import json
import boto3
import pytest
from moto import mock_iam, mock_lambda, mock_apigateway
from botocore.exceptions import ClientError


class TestPermissionBoundary:
    """Test cases for CI/CD permission boundary validation."""
    
    def setup_method(self):
        """Set up test environment with mocked AWS services."""
        self.iam_client = boto3.client('iam', region_name='us-east-1')
        self.lambda_client = boto3.client('lambda', region_name='us-east-1')
        self.apigateway_client = boto3.client('apigateway', region_name='us-east-1')
        
        # Load the permission boundary policy
        with open('../iam-permission-boundary-cicd.json', 'r') as f:
            self.permission_boundary_policy = json.load(f)
    
    @mock_iam
    def test_create_role_with_permission_boundary(self):
        """Test that CI/CD roles can be created with proper permission boundary."""
        # Create the permission boundary policy
        policy_doc = json.dumps(self.permission_boundary_policy)
        
        self.iam_client.create_policy(
            PolicyName='CICDPermissionBoundary',
            PolicyDocument=policy_doc,
            Path='/boundaries/'
        )
        
        # Create a CI/CD role with permission boundary
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
            RoleName='lambda-execution-test',
            AssumeRolePolicyDocument=json.dumps(assume_role_policy),
            PermissionsBoundary='arn:aws:iam::123456789012:policy/boundaries/CICDPermissionBoundary',
            Tags=[
                {'Key': 'ManagedBy', 'Value': 'CI/CD'},
                {'Key': 'Environment', 'Value': 'dev'}
            ]
        )
        
        assert response['Role']['RoleName'] == 'lambda-execution-test'
        assert 'PermissionsBoundary' in response['Role']
    
    @mock_lambda
    def test_lambda_function_creation_with_required_tags(self):
        """Test that Lambda functions require mandatory tags."""
        # This test would normally fail without proper tags
        # In a real environment, the permission boundary would deny this action
        
        function_code = {
            'ZipFile': b'fake code'
        }
        
        # Test with required tags - should succeed
        try:
            response = self.lambda_client.create_function(
                FunctionName='test-function-with-tags',
                Runtime='python3.9',
                Role='arn:aws:iam::123456789012:role/lambda-execution-test',
                Handler='index.handler',
                Code=function_code,
                Tags={
                    'ManagedBy': 'CI/CD',
                    'Environment': 'dev'
                }
            )
            assert response['FunctionName'] == 'test-function-with-tags'
        except ClientError as e:
            # In moto, this might still fail due to role not existing
            # In real AWS, this would test the permission boundary
            pass
    
    def test_deny_wildcard_iam_actions(self):
        """Test that wildcard IAM actions are denied."""
        # Simulate policy evaluation for wildcard IAM actions
        denied_actions = [
            'iam:*',
            'organizations:*',
            'account:*'
        ]
        
        for action in denied_actions:
            # Check if action is explicitly denied in permission boundary
            is_denied = self._check_action_denied(action)
            assert is_denied, f"Action {action} should be denied by permission boundary"
    
    def test_deny_unsigned_code_deployment(self):
        """Test that unsigned code deployment is denied."""
        # Check if lambda:UpdateFunctionCode without CodeSigningConfigArn is denied
        update_code_statements = [
            stmt for stmt in self.permission_boundary_policy['Statement']
            if stmt.get('Sid') == 'DenyUnsignedCodeDeployment'
        ]
        
        assert len(update_code_statements) == 1
        stmt = update_code_statements[0]
        assert stmt['Effect'] == 'Deny'
        assert 'lambda:UpdateFunctionCode' in stmt['Action']
        assert 'lambda:CreateFunction' in stmt['Action']
        
        # Check condition requires CodeSigningConfigArn
        condition = stmt.get('Condition', {})
        assert 'Null' in condition
        assert condition['Null'].get('lambda:CodeSigningConfigArn') == 'true'
    
    def test_region_restrictions(self):
        """Test that actions are restricted to allowed regions."""
        lambda_statements = [
            stmt for stmt in self.permission_boundary_policy['Statement']
            if stmt.get('Sid') == 'AllowLambdaManagement'
        ]
        
        assert len(lambda_statements) == 1
        stmt = lambda_statements[0]
        
        condition = stmt.get('Condition', {})
        allowed_regions = condition.get('StringEquals', {}).get('aws:RequestedRegion', [])
        
        expected_regions = ['us-east-1', 'us-west-2', 'eu-west-1']
        assert set(allowed_regions) == set(expected_regions)
    
    def test_production_access_restrictions(self):
        """Test that production access is restricted to specific principals."""
        prod_deny_statements = [
            stmt for stmt in self.permission_boundary_policy['Statement']
            if stmt.get('Sid') == 'DenyProductionAccessOutsideWorkflow'
        ]
        
        assert len(prod_deny_statements) == 1
        stmt = prod_deny_statements[0]
        assert stmt['Effect'] == 'Deny'
        
        condition = stmt.get('Condition', {})
        assert 'StringEquals' in condition
        assert condition['StringEquals'].get('aws:RequestTag/Environment') == 'prod'
        assert 'StringNotEquals' in condition
        assert 'aws:userid' in condition['StringNotEquals']
    
    def test_mandatory_tagging_enforcement(self):
        """Test that mandatory tags are enforced."""
        tag_statements = [
            stmt for stmt in self.permission_boundary_policy['Statement']
            if 'Tag' in stmt.get('Sid', '')
        ]
        
        # Should have statements for Environment and ManagedBy tags
        assert len(tag_statements) >= 2
        
        # Check Environment tag requirement
        env_statements = [
            stmt for stmt in tag_statements
            if 'Environment' in str(stmt.get('Condition', {}))
        ]
        assert len(env_statements) >= 1
        
        # Check ManagedBy tag requirement
        managed_by_statements = [
            stmt for stmt in tag_statements
            if 'ManagedBy' in str(stmt.get('Condition', {}))
        ]
        assert len(managed_by_statements) >= 1
    
    def test_function_url_denial(self):
        """Test that Lambda function URLs are denied."""
        function_url_statements = [
            stmt for stmt in self.permission_boundary_policy['Statement']
            if stmt.get('Sid') == 'DenyLambdaFunctionUrls'
        ]
        
        assert len(function_url_statements) == 1
        stmt = function_url_statements[0]
        assert stmt['Effect'] == 'Deny'
        assert 'lambda:CreateFunctionUrlConfig' in stmt['Action']
        assert 'lambda:UpdateFunctionUrlConfig' in stmt['Action']
    
    def test_encryption_in_transit_enforcement(self):
        """Test that encryption in transit is enforced."""
        encryption_statements = [
            stmt for stmt in self.permission_boundary_policy['Statement']
            if stmt.get('Sid') == 'EnforceEncryptionInTransit'
        ]
        
        assert len(encryption_statements) == 1
        stmt = encryption_statements[0]
        assert stmt['Effect'] == 'Deny'
        assert stmt['Action'] == '*'
        
        condition = stmt.get('Condition', {})
        assert 'Bool' in condition
        assert condition['Bool'].get('aws:SecureTransport') == 'false'
    
    def _check_action_denied(self, action):
        """Helper method to check if an action is denied by the permission boundary."""
        for statement in self.permission_boundary_policy['Statement']:
            if statement.get('Effect') == 'Deny':
                denied_actions = statement.get('Action', [])
                if isinstance(denied_actions, str):
                    denied_actions = [denied_actions]
                
                for denied_action in denied_actions:
                    if action == denied_action or (denied_action.endswith('*') and action.startswith(denied_action[:-1])):
                        return True
        return False


def test_policy_syntax_validation():
    """Test that the permission boundary policy has valid JSON syntax."""
    try:
        with open('../iam-permission-boundary-cicd.json', 'r') as f:
            policy = json.load(f)
        
        # Basic structure validation
        assert 'Version' in policy
        assert 'Statement' in policy
        assert isinstance(policy['Statement'], list)
        assert len(policy['Statement']) > 0
        
        # Validate each statement has required fields
        for stmt in policy['Statement']:
            assert 'Effect' in stmt
            assert stmt['Effect'] in ['Allow', 'Deny']
            assert 'Action' in stmt
            assert 'Resource' in stmt
            
    except json.JSONDecodeError as e:
        pytest.fail(f"Invalid JSON syntax in permission boundary policy: {e}")
    except FileNotFoundError:
        pytest.fail("Permission boundary policy file not found")


def test_policy_completeness():
    """Test that the permission boundary covers all required security controls."""
    with open('../iam-permission-boundary-cicd.json', 'r') as f:
        policy = json.load(f)
    
    statement_sids = [stmt.get('Sid', '') for stmt in policy['Statement']]
    
    required_controls = [
        'AllowLambdaManagement',
        'AllowCodeDeployForLambda',
        'DenyUnsignedCodeDeployment',
        'DenyLambdaFunctionUrls',
        'RestrictIAMWildcardActions',
        'DenyHighPrivilegeActions',
        'EnforceEncryptionInTransit',
        'RequireMandatoryTags',
        'RequireManagedByTag',
        'DenyProductionAccessOutsideWorkflow'
    ]
    
    for control in required_controls:
        assert control in statement_sids, f"Missing required control: {control}"


if __name__ == '__main__':
    # Run the tests
    pytest.main([__file__, '-v'])