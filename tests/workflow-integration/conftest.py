#!/usr/bin/env python3
"""
Pytest configuration and fixtures for workflow integration testing.
"""

import pytest
import boto3
import tempfile
import shutil
from pathlib import Path
from unittest.mock import Mock, patch
from moto import mock_lambda, mock_codedeploy, mock_cloudwatch, mock_s3, mock_iam, mock_signer


@pytest.fixture(scope="session")
def project_root():
    """Fixture providing path to project root directory."""
    return Path(__file__).parent.parent.parent


@pytest.fixture(scope="session")
def scripts_dir(project_root):
    """Fixture providing path to scripts directory."""
    return project_root / "scripts"


@pytest.fixture(scope="session")
def github_workflows_dir(project_root):
    """Fixture providing path to GitHub workflows directory."""
    return project_root / ".github" / "workflows"


@pytest.fixture
def temp_workspace():
    """Fixture providing temporary workspace for testing."""
    temp_dir = Path(tempfile.mkdtemp())
    yield temp_dir
    shutil.rmtree(temp_dir)


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
def lambda_client(aws_credentials):
    """Fixture providing mocked Lambda client."""
    with mock_lambda():
        yield boto3.client('lambda', region_name='us-east-1')


@pytest.fixture
def codedeploy_client(aws_credentials):
    """Fixture providing mocked CodeDeploy client."""
    with mock_codedeploy():
        yield boto3.client('codedeploy', region_name='us-east-1')


@pytest.fixture
def cloudwatch_client(aws_credentials):
    """Fixture providing mocked CloudWatch client."""
    with mock_cloudwatch():
        yield boto3.client('cloudwatch', region_name='us-east-1')


@pytest.fixture
def s3_client(aws_credentials):
    """Fixture providing mocked S3 client."""
    with mock_s3():
        yield boto3.client('s3', region_name='us-east-1')


@pytest.fixture
def iam_client(aws_credentials):
    """Fixture providing mocked IAM client."""
    with mock_iam():
        yield boto3.client('iam', region_name='us-east-1')


@pytest.fixture
def signer_client(aws_credentials):
    """Fixture providing mocked Signer client."""
    with mock_signer():
        yield boto3.client('signer', region_name='us-east-1')


@pytest.fixture
def sample_lambda_function():
    """Fixture providing sample Lambda function configuration."""
    return {
        'FunctionName': 'test-integration-function',
        'Runtime': 'python3.9',
        'Role': 'arn:aws:iam::123456789012:role/lambda-execution-role',
        'Handler': 'index.handler',
        'Code': {'ZipFile': b'def handler(event, context): return {"statusCode": 200}'},
        'Description': 'Test function for integration testing',
        'Timeout': 30,
        'MemorySize': 128,
        'Environment': {
            'Variables': {
                'ENVIRONMENT': 'test'
            }
        },
        'Tags': {
            'Environment': 'test',
            'ManagedBy': 'CI/CD'
        }
    }


@pytest.fixture
def sample_codedeploy_config():
    """Fixture providing sample CodeDeploy configuration."""
    return {
        'applicationName': 'test-lambda-app',
        'deploymentGroupName': 'test-deployment-group',
        'deploymentConfigName': 'CodeDeployDefault.LambdaCanary10Percent5Minutes',
        'serviceRoleArn': 'arn:aws:iam::123456789012:role/CodeDeployServiceRole'
    }


@pytest.fixture
def mock_github_context():
    """Fixture providing mock GitHub Actions context."""
    return {
        'github': {
            'repository': 'test-org/test-repo',
            'ref': 'refs/heads/main',
            'sha': 'abc123def456',
            'actor': 'test-user',
            'event_name': 'push'
        },
        'env': {
            'AWS_REGION': 'us-east-1',
            'ENVIRONMENT': 'dev'
        }
    }


class MockSubprocessResult:
    """Mock subprocess result for testing script execution."""
    
    def __init__(self, returncode=0, stdout='', stderr=''):
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr


@pytest.fixture
def mock_subprocess_success():
    """Fixture providing mock successful subprocess execution."""
    return MockSubprocessResult(returncode=0, stdout='Success', stderr='')


@pytest.fixture
def mock_subprocess_failure():
    """Fixture providing mock failed subprocess execution."""
    return MockSubprocessResult(returncode=1, stdout='', stderr='Error occurred')


class WorkflowValidator:
    """Helper class for validating workflow configurations."""
    
    @staticmethod
    def validate_github_workflow(workflow_content):
        """Validate GitHub Actions workflow structure."""
        import yaml
        
        try:
            workflow = yaml.safe_load(workflow_content)
        except yaml.YAMLError as e:
            return False, f"Invalid YAML: {e}"
        
        # Check required fields
        required_fields = ['name', 'on', 'jobs']
        for field in required_fields:
            if field not in workflow:
                return False, f"Missing required field: {field}"
        
        # Validate jobs structure
        jobs = workflow.get('jobs', {})
        if not isinstance(jobs, dict) or len(jobs) == 0:
            return False, "No jobs defined"
        
        for job_name, job_config in jobs.items():
            if 'runs-on' not in job_config:
                return False, f"Job {job_name} missing runs-on"
            
            if 'steps' not in job_config:
                return False, f"Job {job_name} missing steps"
        
        return True, "Valid workflow"
    
    @staticmethod
    def validate_deployment_script(script_content):
        """Validate deployment script structure."""
        # Check for shebang
        if not script_content.startswith('#!'):
            return False, "Missing shebang"
        
        # Check for error handling
        if 'set -e' not in script_content:
            return False, "Missing error handling (set -e)"
        
        # Check for required AWS CLI usage
        aws_commands = ['aws lambda', 'aws deploy', 'aws codedeploy']
        has_aws_command = any(cmd in script_content.lower() for cmd in aws_commands)
        
        if not has_aws_command:
            return False, "Missing AWS CLI commands"
        
        return True, "Valid deployment script"


@pytest.fixture
def workflow_validator():
    """Fixture providing workflow validation helper."""
    return WorkflowValidator


class DeploymentSimulator:
    """Helper class for simulating deployment scenarios."""
    
    def __init__(self, lambda_client, codedeploy_client):
        self.lambda_client = lambda_client
        self.codedeploy_client = codedeploy_client
    
    def simulate_canary_deployment(self, function_name, new_version):
        """Simulate a canary deployment scenario."""
        try:
            # Update alias with weighted routing
            self.lambda_client.update_alias(
                FunctionName=function_name,
                Name='prod',
                FunctionVersion=new_version,
                RoutingConfig={
                    'AdditionalVersionWeights': {
                        '1': 0.9,  # 90% to old version
                        new_version: 0.1  # 10% to new version
                    }
                }
            )
            return True, "Canary deployment simulated"
        except Exception as e:
            return False, f"Canary deployment failed: {e}"
    
    def simulate_rollback(self, function_name, previous_version):
        """Simulate a rollback scenario."""
        try:
            # Rollback alias to previous version
            self.lambda_client.update_alias(
                FunctionName=function_name,
                Name='prod',
                FunctionVersion=previous_version,
                RoutingConfig={}  # Remove weighted routing
            )
            return True, "Rollback simulated"
        except Exception as e:
            return False, f"Rollback failed: {e}"


@pytest.fixture
def deployment_simulator(lambda_client, codedeploy_client):
    """Fixture providing deployment simulation helper."""
    return DeploymentSimulator(lambda_client, codedeploy_client)


@pytest.fixture
def sample_cloudwatch_alarms():
    """Fixture providing sample CloudWatch alarm configurations."""
    return [
        {
            'AlarmName': 'lambda-error-rate',
            'MetricName': 'Errors',
            'Namespace': 'AWS/Lambda',
            'Statistic': 'Sum',
            'Threshold': 5.0,
            'ComparisonOperator': 'GreaterThanThreshold'
        },
        {
            'AlarmName': 'lambda-duration',
            'MetricName': 'Duration',
            'Namespace': 'AWS/Lambda',
            'Statistic': 'Average',
            'Threshold': 10000.0,
            'ComparisonOperator': 'GreaterThanThreshold'
        },
        {
            'AlarmName': 'lambda-throttles',
            'MetricName': 'Throttles',
            'Namespace': 'AWS/Lambda',
            'Statistic': 'Sum',
            'Threshold': 1.0,
            'ComparisonOperator': 'GreaterThanOrEqualToThreshold'
        }
    ]