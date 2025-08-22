#!/usr/bin/env python3
"""
Pytest configuration and fixtures for policy guardrail testing.
"""

import pytest
import boto3
import json
from pathlib import Path
from moto import mock_iam, mock_lambda, mock_config, mock_organizations


@pytest.fixture(scope="session")
def policies_dir():
    """Fixture providing path to policies directory."""
    return Path(__file__).parent.parent.parent / "docs" / "policies"


@pytest.fixture(scope="session")
def scp_policies(policies_dir):
    """Fixture providing all SCP policies."""
    policies = {}
    
    scp_files = [
        "scp-lambda-governance.json",
        "scp-lambda-code-signing.json",
        "scp-api-gateway-waf.json",
        "scp-lambda-production-governance.json"
    ]
    
    for scp_file in scp_files:
        file_path = policies_dir / scp_file
        if file_path.exists():
            with open(file_path, 'r') as f:
                policy_name = scp_file.replace('.json', '').replace('scp-', '')
                policies[policy_name] = json.load(f)
    
    return policies


@pytest.fixture(scope="session")
def permission_boundary_policies(policies_dir):
    """Fixture providing permission boundary policies."""
    policies = {}
    
    boundary_files = [
        "iam-permission-boundary-cicd.json",
        "iam-permission-boundary-lambda-execution.json"
    ]
    
    for boundary_file in boundary_files:
        file_path = policies_dir / boundary_file
        if file_path.exists():
            with open(file_path, 'r') as f:
                policy_name = boundary_file.replace('.json', '').replace('iam-permission-boundary-', '')
                policies[policy_name] = json.load(f)
    
    return policies


@pytest.fixture
def aws_credentials():
    """Mocked AWS Credentials for moto."""
    import os
    os.environ['AWS_ACCESS_KEY_ID'] = 'testing'
    os.environ['AWS_SECRET_ACCESS_KEY'] = 'testing'
    os.environ['AWS_SECURITY_TOKEN'] = 'testing'
    os.environ['AWS_SESSION_TOKEN'] = 'testing'
    os.environ['AWS_DEFAULT_REGION'] = 'us-east-1'


@pytest.fixture
def iam_client(aws_credentials):
    """Fixture providing mocked IAM client."""
    with mock_iam():
        yield boto3.client('iam', region_name='us-east-1')


@pytest.fixture
def lambda_client(aws_credentials):
    """Fixture providing mocked Lambda client."""
    with mock_lambda():
        yield boto3.client('lambda', region_name='us-east-1')


@pytest.fixture
def config_client(aws_credentials):
    """Fixture providing mocked Config client."""
    with mock_config():
        yield boto3.client('config', region_name='us-east-1')


@pytest.fixture
def organizations_client(aws_credentials):
    """Fixture providing mocked Organizations client."""
    with mock_organizations():
        yield boto3.client('organizations', region_name='us-east-1')


@pytest.fixture
def sample_lambda_function_config():
    """Fixture providing sample Lambda function configuration for testing."""
    return {
        'FunctionName': 'test-function',
        'Runtime': 'python3.9',
        'Role': 'arn:aws:iam::123456789012:role/lambda-execution-role',
        'Handler': 'index.handler',
        'Code': {'ZipFile': b'fake code'},
        'Description': 'Test Lambda function',
        'Timeout': 300,
        'MemorySize': 128,
        'Environment': {
            'Variables': {
                'ENV': 'test'
            }
        },
        'Tags': {
            'Environment': 'dev',
            'ManagedBy': 'CI/CD',
            'Encryption': 'AES256',
            'TracingConfig': 'Active'
        }
    }


@pytest.fixture
def sample_api_gateway_stage_config():
    """Fixture providing sample API Gateway stage configuration for testing."""
    return {
        'RestApiId': 'test-api-id',
        'StageName': 'prod',
        'DeploymentId': 'test-deployment-id',
        'Variables': {
            'environment': 'production'
        },
        'Tags': {
            'Environment': 'prod',
            'WAFEnabled': 'true'
        }
    }


class PolicyValidator:
    """Helper class for validating policy effectiveness."""
    
    @staticmethod
    def evaluate_policy_statement(statement, context):
        """
        Evaluate a policy statement against a given context.
        
        Args:
            statement: IAM policy statement
            context: Dictionary with action, resource, conditions, etc.
        
        Returns:
            tuple: (effect, matches) where effect is 'Allow'/'Deny' and matches is boolean
        """
        effect = statement.get('Effect')
        
        # Check if action matches
        actions = statement.get('Action', [])
        if isinstance(actions, str):
            actions = [actions]
        
        action_matches = False
        for action in actions:
            if action == '*' or action == context.get('action'):
                action_matches = True
                break
            elif action.endswith('*'):
                prefix = action[:-1]
                if context.get('action', '').startswith(prefix):
                    action_matches = True
                    break
        
        if not action_matches:
            return effect, False
        
        # Check if resource matches
        resources = statement.get('Resource', [])
        if isinstance(resources, str):
            resources = [resources]
        
        resource_matches = False
        for resource in resources:
            if resource == '*' or resource == context.get('resource'):
                resource_matches = True
                break
        
        if not resource_matches:
            return effect, False
        
        # Check conditions (simplified)
        conditions = statement.get('Condition', {})
        if conditions:
            # This is a simplified condition evaluation
            # In practice, this would need to be much more comprehensive
            condition_matches = PolicyValidator._evaluate_conditions(conditions, context)
            if not condition_matches:
                return effect, False
        
        return effect, True
    
    @staticmethod
    def _evaluate_conditions(conditions, context):
        """Simplified condition evaluation."""
        # This is a basic implementation - real condition evaluation is complex
        for operator, condition_block in conditions.items():
            if operator == 'StringEquals':
                for key, expected_value in condition_block.items():
                    actual_value = context.get('conditions', {}).get(key)
                    if actual_value != expected_value:
                        return False
            elif operator == 'Null':
                for key, expected_null in condition_block.items():
                    actual_value = context.get('conditions', {}).get(key)
                    is_null = actual_value is None
                    if is_null != (expected_null == 'true'):
                        return False
        
        return True


@pytest.fixture
def policy_validator():
    """Fixture providing policy validation helper."""
    return PolicyValidator