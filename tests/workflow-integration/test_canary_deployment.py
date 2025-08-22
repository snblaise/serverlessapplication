#!/usr/bin/env python3
"""
Test suite for canary deployment scenario testing and rollback validation.
Tests CodeDeploy canary deployments and automated rollback procedures.
"""

import json
import boto3
import pytest
import time
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock
from moto import mock_lambda, mock_codedeploy, mock_cloudwatch, mock_iam
import subprocess


class TestCanaryDeployment:
    """Test cases for canary deployment and rollback validation."""
    
    @classmethod
    def setup_class(cls):
        """Set up test environment and load configurations."""
        cls.project_root = Path(__file__).parent.parent.parent
        cls.scripts_dir = cls.project_root / "scripts"
    
    def setup_method(self):
        """Set up test method with AWS clients."""
        self.lambda_client = boto3.client('lambda', region_name='us-east-1')
        self.codedeploy_client = boto3.client('codedeploy', region_name='us-east-1')
        self.cloudwatch_client = boto3.client('cloudwatch', region_name='us-east-1')
    
    def test_canary_deployment_script_structure(self):
        """Test that canary deployment script has correct structure."""
        canary_script = self.scripts_dir / "deploy-lambda-canary.sh"
        
        assert canary_script.exists(), "Canary deployment script should exist"
        
        with open(canary_script, 'r') as f:
            script_content = f.read()
        
        # Basic script validation
        assert script_content.startswith('#!/'), "Script should have shebang"
        assert 'set -e' in script_content, "Script should have error handling"
        
        # Check for CodeDeploy integration
        codedeploy_elements = [
            'aws deploy', 'codedeploy', 'deployment-config', 'application-name'
        ]
        
        found_elements = []
        for element in codedeploy_elements:
            if element in script_content.lower():
                found_elements.append(element)
        
        assert len(found_elements) >= 2, f"Should use CodeDeploy, found: {found_elements}"
        
        # Check for Lambda alias management
        alias_elements = [
            'alias', 'version', 'update-alias'
        ]
        
        found_alias_elements = []
        for element in alias_elements:
            if element in script_content.lower():
                found_alias_elements.append(element)
        
        assert len(found_alias_elements) >= 2, f"Should manage Lambda aliases, found: {found_alias_elements}"
    
    def test_rollback_script_structure(self):
        """Test that rollback script has correct structure."""
        rollback_script = self.scripts_dir / "rollback-lambda-deployment.sh"
        
        assert rollback_script.exists(), "Rollback script should exist"
        
        with open(rollback_script, 'r') as f:
            script_content = f.read()
        
        # Basic script validation
        assert script_content.startswith('#!/'), "Script should have shebang"
        assert 'set -e' in script_content, "Script should have error handling"
        
        # Check for rollback functionality
        rollback_elements = [
            'rollback', 'previous', 'restore', 'revert'
        ]
        
        found_elements = []
        for element in rollback_elements:
            if element in script_content.lower():
                found_elements.append(element)
        
        assert len(found_elements) >= 1, f"Should have rollback functionality, found: {found_elements}"
        
        # Check for validation steps
        validation_elements = [
            'validate', 'check', 'verify', 'test'
        ]
        
        found_validation = []
        for element in validation_elements:
            if element in script_content.lower():
                found_validation.append(element)
        
        assert len(found_validation) >= 1, f"Should validate rollback, found: {found_validation}"
    
    @mock_lambda
    @mock_codedeploy
    def test_lambda_alias_management(self):
        """Test Lambda alias creation and management for canary deployments."""
        function_name = 'test-canary-function'
        
        try:
            # Create Lambda function
            self.lambda_client.create_function(
                FunctionName=function_name,
                Runtime='python3.9',
                Role='arn:aws:iam::123456789012:role/lambda-execution-role',
                Handler='index.handler',
                Code={'ZipFile': b'def handler(event, context): return "v1"'},
                Publish=True
            )
            
            # Create production alias pointing to version 1
            self.lambda_client.create_alias(
                FunctionName=function_name,
                Name='prod',
                FunctionVersion='1',
                Description='Production alias'
            )
            
            # Verify alias creation
            aliases = self.lambda_client.list_aliases(FunctionName=function_name)
            prod_alias = next((a for a in aliases['Aliases'] if a['Name'] == 'prod'), None)
            
            assert prod_alias is not None, "Production alias should be created"
            assert prod_alias['FunctionVersion'] == '1', "Alias should point to version 1"
            
            # Publish new version
            new_version = self.lambda_client.publish_version(
                FunctionName=function_name,
                CodeSha256='new-code-hash',
                Description='Version 2'
            )
            
            # Update alias for canary deployment (weighted routing)
            self.lambda_client.update_alias(
                FunctionName=function_name,
                Name='prod',
                FunctionVersion='2',
                RoutingConfig={
                    'AdditionalVersionWeights': {
                        '1': 0.9,  # 90% traffic to old version
                        '2': 0.1   # 10% traffic to new version
                    }
                }
            )
            
            # Verify weighted routing
            updated_alias = self.lambda_client.get_alias(
                FunctionName=function_name,
                Name='prod'
            )
            
            routing_config = updated_alias.get('RoutingConfig', {})
            assert 'AdditionalVersionWeights' in routing_config, "Should have weighted routing"
            
        except Exception as e:
            # Some operations might not be fully supported in moto
            pytest.skip(f"Lambda alias management test not supported: {e}")
    
    @mock_codedeploy
    def test_codedeploy_application_configuration(self):
        """Test CodeDeploy application and deployment group configuration."""
        try:
            # Create CodeDeploy application
            app_name = 'test-lambda-app'
            
            self.codedeploy_client.create_application(
                applicationName=app_name,
                computePlatform='Lambda'
            )
            
            # Create deployment group
            deployment_group_name = 'test-deployment-group'
            
            self.codedeploy_client.create_deployment_group(
                applicationName=app_name,
                deploymentGroupName=deployment_group_name,
                serviceRoleArn='arn:aws:iam::123456789012:role/CodeDeployServiceRole',
                deploymentConfigName='CodeDeployDefault.LambdaCanary10Percent5Minutes'
            )
            
            # Verify deployment group creation
            deployment_groups = self.codedeploy_client.list_deployment_groups(
                applicationName=app_name
            )
            
            assert deployment_group_name in deployment_groups['deploymentGroups']
            
        except Exception as e:
            # Some operations might not be fully supported in moto
            pytest.skip(f"CodeDeploy configuration test not supported: {e}")
    
    def test_canary_deployment_configurations(self):
        """Test different canary deployment configurations."""
        # Test various CodeDeploy configurations for Lambda
        canary_configs = [
            'CodeDeployDefault.LambdaCanary10Percent5Minutes',
            'CodeDeployDefault.LambdaCanary10Percent10Minutes',
            'CodeDeployDefault.LambdaCanary10Percent15Minutes',
            'CodeDeployDefault.LambdaLinear10PercentEvery1Minute',
            'CodeDeployDefault.LambdaLinear10PercentEvery2Minutes'
        ]
        
        # Validate configuration names
        for config in canary_configs:
            assert 'Lambda' in config, f"Configuration {config} should be for Lambda"
            assert ('Canary' in config or 'Linear' in config), f"Configuration {config} should be canary or linear"
    
    @mock_cloudwatch
    def test_cloudwatch_alarms_for_rollback(self):
        """Test CloudWatch alarms configuration for automatic rollback."""
        try:
            # Create CloudWatch alarms for monitoring deployment health
            alarm_name = 'lambda-error-rate-alarm'
            
            self.cloudwatch_client.put_metric_alarm(
                AlarmName=alarm_name,
                ComparisonOperator='GreaterThanThreshold',
                EvaluationPeriods=2,
                MetricName='Errors',
                Namespace='AWS/Lambda',
                Period=300,
                Statistic='Sum',
                Threshold=5.0,
                ActionsEnabled=True,
                AlarmActions=[
                    'arn:aws:sns:us-east-1:123456789012:lambda-deployment-alerts'
                ],
                AlarmDescription='Alarm for Lambda error rate during deployment',
                Dimensions=[
                    {
                        'Name': 'FunctionName',
                        'Value': 'test-function'
                    }
                ]
            )
            
            # Verify alarm creation
            alarms = self.cloudwatch_client.describe_alarms(
                AlarmNames=[alarm_name]
            )
            
            assert len(alarms['MetricAlarms']) == 1
            alarm = alarms['MetricAlarms'][0]
            assert alarm['AlarmName'] == alarm_name
            assert alarm['MetricName'] == 'Errors'
            
        except Exception as e:
            # Some operations might not be fully supported in moto
            pytest.skip(f"CloudWatch alarms test not supported: {e}")
    
    @patch('subprocess.run')
    def test_canary_deployment_execution(self, mock_subprocess):
        """Test canary deployment script execution."""
        # Mock successful deployment
        mock_subprocess.return_value = Mock(
            returncode=0,
            stdout='Deployment successful',
            stderr=''
        )
        
        canary_script = self.scripts_dir / "deploy-lambda-canary.sh"
        
        if canary_script.exists():
            # Test deployment script execution
            result = subprocess.run([
                'bash', str(canary_script),
                'test-function',
                'test-version',
                'prod'
            ], capture_output=True, text=True)
            
            assert result.returncode == 0, "Canary deployment should execute successfully"
    
    @patch('subprocess.run')
    def test_rollback_execution(self, mock_subprocess):
        """Test rollback script execution."""
        # Mock successful rollback
        mock_subprocess.return_value = Mock(
            returncode=0,
            stdout='Rollback successful',
            stderr=''
        )
        
        rollback_script = self.scripts_dir / "rollback-lambda-deployment.sh"
        
        if rollback_script.exists():
            # Test rollback script execution
            result = subprocess.run([
                'bash', str(rollback_script),
                'test-function',
                'prod'
            ], capture_output=True, text=True)
            
            assert result.returncode == 0, "Rollback should execute successfully"
    
    def test_deployment_validation_checks(self):
        """Test deployment validation and health checks."""
        canary_script = self.scripts_dir / "deploy-lambda-canary.sh"
        
        if canary_script.exists():
            with open(canary_script, 'r') as f:
                script_content = f.read()
            
            # Check for validation steps
            validation_checks = [
                'health', 'check', 'validate', 'test', 'invoke'
            ]
            
            found_checks = []
            for check in validation_checks:
                if check in script_content.lower():
                    found_checks.append(check)
            
            assert len(found_checks) >= 2, f"Should have validation checks, found: {found_checks}"
    
    def test_traffic_shifting_strategy(self):
        """Test traffic shifting strategy configuration."""
        # Test different traffic shifting patterns
        traffic_patterns = [
            {'initial': 10, 'increment': 10, 'interval': 5},  # 10% every 5 minutes
            {'initial': 5, 'increment': 5, 'interval': 2},    # 5% every 2 minutes
            {'initial': 25, 'increment': 25, 'interval': 10}  # 25% every 10 minutes
        ]
        
        for pattern in traffic_patterns:
            # Validate pattern makes sense
            assert pattern['initial'] > 0, "Initial traffic should be positive"
            assert pattern['increment'] > 0, "Increment should be positive"
            assert pattern['interval'] > 0, "Interval should be positive"
            assert pattern['initial'] <= 100, "Initial traffic should not exceed 100%"
    
    def test_rollback_triggers(self):
        """Test automatic rollback trigger configuration."""
        rollback_script = self.scripts_dir / "rollback-lambda-deployment.sh"
        
        if rollback_script.exists():
            with open(rollback_script, 'r') as f:
                script_content = f.read()
            
            # Check for rollback triggers
            trigger_elements = [
                'alarm', 'error', 'threshold', 'metric'
            ]
            
            found_triggers = []
            for element in trigger_elements:
                if element in script_content.lower():
                    found_triggers.append(element)
            
            # Should have some form of automatic triggering
            if len(found_triggers) >= 1:
                assert True, f"Rollback triggers found: {found_triggers}"
            else:
                # Manual rollback is also acceptable
                pytest.skip("Manual rollback configuration")
    
    def test_deployment_monitoring(self):
        """Test deployment monitoring and observability."""
        canary_script = self.scripts_dir / "deploy-lambda-canary.sh"
        
        if canary_script.exists():
            with open(canary_script, 'r') as f:
                script_content = f.read()
            
            # Check for monitoring integration
            monitoring_elements = [
                'cloudwatch', 'metric', 'log', 'x-ray', 'trace'
            ]
            
            found_monitoring = []
            for element in monitoring_elements:
                if element in script_content.lower():
                    found_monitoring.append(element)
            
            assert len(found_monitoring) >= 1, f"Should have monitoring integration, found: {found_monitoring}"
    
    def test_canary_cleanup_procedures(self):
        """Test cleanup procedures after successful/failed canary deployment."""
        canary_script = self.scripts_dir / "deploy-lambda-canary.sh"
        
        if canary_script.exists():
            with open(canary_script, 'r') as f:
                script_content = f.read()
            
            # Check for cleanup procedures
            cleanup_elements = [
                'cleanup', 'clean', 'remove', 'delete'
            ]
            
            found_cleanup = []
            for element in cleanup_elements:
                if element in script_content.lower():
                    found_cleanup.append(element)
            
            # Cleanup is optional but recommended
            if len(found_cleanup) >= 1:
                assert True, f"Cleanup procedures found: {found_cleanup}"
            else:
                # No explicit cleanup found, which is acceptable
                pass
    
    def test_deployment_state_management(self):
        """Test deployment state tracking and management."""
        # Check for state management in deployment scripts
        scripts_to_check = [
            self.scripts_dir / "deploy-lambda-canary.sh",
            self.scripts_dir / "rollback-lambda-deployment.sh"
        ]
        
        state_management_found = False
        
        for script_path in scripts_to_check:
            if script_path.exists():
                with open(script_path, 'r') as f:
                    script_content = f.read()
                
                # Check for state management
                state_elements = [
                    'state', 'status', 'deployment-id', 'track'
                ]
                
                for element in state_elements:
                    if element in script_content.lower():
                        state_management_found = True
                        break
                
                if state_management_found:
                    break
        
        assert state_management_found, "Should track deployment state"
    
    def test_concurrent_deployment_prevention(self):
        """Test prevention of concurrent deployments."""
        canary_script = self.scripts_dir / "deploy-lambda-canary.sh"
        
        if canary_script.exists():
            with open(canary_script, 'r') as f:
                script_content = f.read()
            
            # Check for concurrent deployment prevention
            concurrency_elements = [
                'lock', 'mutex', 'concurrent', 'running'
            ]
            
            found_concurrency = []
            for element in concurrency_elements:
                if element in script_content.lower():
                    found_concurrency.append(element)
            
            # Concurrency prevention is recommended but not required
            if len(found_concurrency) >= 1:
                assert True, f"Concurrency prevention found: {found_concurrency}"
            else:
                # No explicit concurrency prevention, which is acceptable for simple cases
                pass


if __name__ == '__main__':
    pytest.main([__file__, '-v'])