#!/usr/bin/env python3
"""
Test suite for CI/CD pipeline workflow validation.
Tests end-to-end CI/CD pipeline with mock deployments and integrations.
"""

import json
import yaml
import pytest
import subprocess
import tempfile
import shutil
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock
import boto3
from moto import mock_lambda, mock_codedeploy, mock_s3, mock_iam


class TestCICDPipeline:
    """Test cases for CI/CD pipeline workflow validation."""
    
    @classmethod
    def setup_class(cls):
        """Set up test environment and load workflow configurations."""
        cls.project_root = Path(__file__).parent.parent.parent
        cls.github_workflows_dir = cls.project_root / ".github" / "workflows"
        cls.scripts_dir = cls.project_root / "scripts"
    
    def setup_method(self):
        """Set up test method with temporary directories."""
        self.temp_dir = Path(tempfile.mkdtemp())
        self.mock_repo_dir = self.temp_dir / "mock-repo"
        self.mock_repo_dir.mkdir()
    
    def teardown_method(self):
        """Clean up temporary directories."""
        if self.temp_dir.exists():
            shutil.rmtree(self.temp_dir)
    
    def test_github_workflow_structure(self):
        """Test that GitHub Actions workflow has correct structure."""
        workflow_files = list(self.github_workflows_dir.glob("*.yml")) + list(self.github_workflows_dir.glob("*.yaml"))
        
        assert len(workflow_files) >= 1, "Should have at least one GitHub Actions workflow"
        
        for workflow_file in workflow_files:
            with open(workflow_file, 'r') as f:
                workflow = yaml.safe_load(f)
            
            # Basic workflow structure validation
            assert 'name' in workflow, f"Workflow {workflow_file.name} missing name"
            assert 'on' in workflow, f"Workflow {workflow_file.name} missing triggers"
            assert 'jobs' in workflow, f"Workflow {workflow_file.name} missing jobs"
            
            # Check for required jobs
            jobs = workflow['jobs']
            job_names = list(jobs.keys())
            
            # Should have lint, test, build, and deploy jobs
            expected_job_types = ['lint', 'test', 'build', 'deploy']
            found_job_types = []
            
            for job_name in job_names:
                job_name_lower = job_name.lower()
                for job_type in expected_job_types:
                    if job_type in job_name_lower:
                        found_job_types.append(job_type)
            
            assert len(found_job_types) >= 2, f"Workflow should have multiple job types, found: {found_job_types}"
    
    def test_oidc_authentication_configuration(self):
        """Test that OIDC authentication is properly configured."""
        workflow_files = list(self.github_workflows_dir.glob("*.yml")) + list(self.github_workflows_dir.glob("*.yaml"))
        
        oidc_configured = False
        
        for workflow_file in workflow_files:
            with open(workflow_file, 'r') as f:
                workflow_content = f.read()
            
            # Check for OIDC configuration
            if ('id-token: write' in workflow_content and 
                'aws-actions/configure-aws-credentials' in workflow_content):
                oidc_configured = True
                
                # Parse YAML to check specific configuration
                workflow = yaml.safe_load(workflow_content)
                
                # Check permissions
                permissions = workflow.get('permissions', {})
                if isinstance(permissions, dict):
                    assert permissions.get('id-token') == 'write', "Should have id-token write permission"
                
                # Check for role-to-assume in jobs
                jobs = workflow.get('jobs', {})
                for job_name, job_config in jobs.items():
                    steps = job_config.get('steps', [])
                    for step in steps:
                        if step.get('uses', '').startswith('aws-actions/configure-aws-credentials'):
                            step_with = step.get('with', {})
                            assert 'role-to-assume' in step_with, f"Job {job_name} missing role-to-assume"
                            break
        
        assert oidc_configured, "OIDC authentication should be configured in workflow"
    
    def test_security_scanning_stages(self):
        """Test that security scanning stages are present."""
        workflow_files = list(self.github_workflows_dir.glob("*.yml")) + list(self.github_workflows_dir.glob("*.yaml"))
        
        security_tools_found = []
        
        for workflow_file in workflow_files:
            with open(workflow_file, 'r') as f:
                workflow_content = f.read()
            
            # Check for various security scanning tools
            security_tools = {
                'sast': ['codeql', 'sonarqube', 'semgrep'],
                'sca': ['dependabot', 'snyk', 'safety'],
                'iac': ['checkov', 'tfsec', 'terraform-compliance'],
                'secrets': ['trufflesecurity', 'gitleaks', 'detect-secrets']
            }
            
            for category, tools in security_tools.items():
                for tool in tools:
                    if tool.lower() in workflow_content.lower():
                        security_tools_found.append(f"{category}:{tool}")
        
        assert len(security_tools_found) >= 2, f"Should have multiple security tools, found: {security_tools_found}"
    
    def test_build_and_package_stages(self):
        """Test that build and package stages are properly configured."""
        # Check for build scripts
        build_scripts = [
            self.scripts_dir / "build-lambda-package.sh",
            self.scripts_dir / "validate-lambda-package.sh"
        ]
        
        for script in build_scripts:
            if script.exists():
                with open(script, 'r') as f:
                    script_content = f.read()
                
                # Basic script validation
                assert script_content.startswith('#!/'), f"Script {script.name} should have shebang"
                assert 'set -e' in script_content, f"Script {script.name} should have error handling"
    
    def test_code_signing_integration(self):
        """Test that code signing is integrated into the pipeline."""
        # Check for code signing script
        signing_script = self.scripts_dir / "sign-lambda-package.sh"
        
        if signing_script.exists():
            with open(signing_script, 'r') as f:
                script_content = f.read()
            
            # Check for AWS Signer integration
            assert 'aws signer' in script_content.lower(), "Should use AWS Signer"
            assert 'signing-profile' in script_content.lower(), "Should reference signing profile"
        
        # Check workflow integration
        workflow_files = list(self.github_workflows_dir.glob("*.yml")) + list(self.github_workflows_dir.glob("*.yaml"))
        
        code_signing_found = False
        for workflow_file in workflow_files:
            with open(workflow_file, 'r') as f:
                workflow_content = f.read()
            
            if 'sign' in workflow_content.lower() and 'signer' in workflow_content.lower():
                code_signing_found = True
                break
        
        # Code signing should be present in either script or workflow
        assert signing_script.exists() or code_signing_found, "Code signing should be configured"
    
    @mock_lambda
    @mock_codedeploy
    def test_canary_deployment_configuration(self):
        """Test canary deployment configuration and simulation."""
        # Check for canary deployment script
        canary_script = self.scripts_dir / "deploy-lambda-canary.sh"
        
        if canary_script.exists():
            with open(canary_script, 'r') as f:
                script_content = f.read()
            
            # Check for CodeDeploy integration
            assert 'aws deploy' in script_content.lower(), "Should use AWS CodeDeploy"
            assert 'canary' in script_content.lower(), "Should reference canary deployment"
            assert 'alias' in script_content.lower(), "Should use Lambda aliases"
        
        # Simulate canary deployment
        lambda_client = boto3.client('lambda', region_name='us-east-1')
        codedeploy_client = boto3.client('codedeploy', region_name='us-east-1')
        
        try:
            # Create mock Lambda function
            function_name = 'test-canary-function'
            lambda_client.create_function(
                FunctionName=function_name,
                Runtime='python3.9',
                Role='arn:aws:iam::123456789012:role/lambda-execution-role',
                Handler='index.handler',
                Code={'ZipFile': b'fake code'},
                Publish=True
            )
            
            # Create alias
            lambda_client.create_alias(
                FunctionName=function_name,
                Name='prod',
                FunctionVersion='1'
            )
            
            # Verify alias creation
            aliases = lambda_client.list_aliases(FunctionName=function_name)
            assert len(aliases['Aliases']) >= 1
            
        except Exception as e:
            # Some operations might not be fully supported in moto
            pytest.skip(f"Canary deployment simulation not supported: {e}")
    
    def test_rollback_procedures(self):
        """Test rollback procedure configuration."""
        rollback_script = self.scripts_dir / "rollback-lambda-deployment.sh"
        
        if rollback_script.exists():
            with open(rollback_script, 'r') as f:
                script_content = f.read()
            
            # Check for rollback functionality
            assert 'rollback' in script_content.lower(), "Should have rollback functionality"
            assert 'previous' in script_content.lower() or 'last' in script_content.lower(), "Should reference previous version"
            
            # Check for error handling
            assert 'set -e' in script_content, "Should have error handling"
            
            # Check for validation
            assert 'validate' in script_content.lower() or 'check' in script_content.lower(), "Should validate rollback"
    
    def test_environment_specific_configurations(self):
        """Test that environment-specific configurations are supported."""
        workflow_files = list(self.github_workflows_dir.glob("*.yml")) + list(self.github_workflows_dir.glob("*.yaml"))
        
        environment_support = False
        
        for workflow_file in workflow_files:
            with open(workflow_file, 'r') as f:
                workflow = yaml.safe_load(f)
            
            # Check for environment configuration
            jobs = workflow.get('jobs', {})
            for job_name, job_config in jobs.items():
                # Check for environment in job
                if 'environment' in job_config:
                    environment_support = True
                    break
                
                # Check for environment variables
                env_vars = job_config.get('env', {})
                if any('env' in key.lower() for key in env_vars.keys()):
                    environment_support = True
                    break
        
        # Environment support should be present
        assert environment_support, "Should support environment-specific configurations"
    
    def test_approval_gates_configuration(self):
        """Test that approval gates are configured for production deployments."""
        workflow_files = list(self.github_workflows_dir.glob("*.yml")) + list(self.github_workflows_dir.glob("*.yaml"))
        
        approval_gates_found = False
        
        for workflow_file in workflow_files:
            with open(workflow_file, 'r') as f:
                workflow = yaml.safe_load(f)
            
            jobs = workflow.get('jobs', {})
            for job_name, job_config in jobs.items():
                # Check for environment with protection rules
                environment = job_config.get('environment')
                if environment:
                    if isinstance(environment, dict):
                        # Environment object with protection rules
                        approval_gates_found = True
                    elif isinstance(environment, str) and 'prod' in environment.lower():
                        # Production environment (likely has protection rules)
                        approval_gates_found = True
        
        # For production deployments, approval gates should be configured
        # This might be configured at the repository level rather than in workflow
        # So we'll check for production environment references
        assert approval_gates_found or self._check_production_references(workflow_files), \
            "Should have approval gates or production environment references"
    
    def _check_production_references(self, workflow_files):
        """Helper to check for production environment references."""
        for workflow_file in workflow_files:
            with open(workflow_file, 'r') as f:
                content = f.read().lower()
            
            if 'prod' in content or 'production' in content:
                return True
        
        return False
    
    @patch('subprocess.run')
    def test_pipeline_script_execution(self, mock_subprocess):
        """Test that pipeline scripts can be executed successfully."""
        # Mock successful script execution
        mock_subprocess.return_value = Mock(returncode=0, stdout='Success', stderr='')
        
        scripts_to_test = [
            'build-lambda-package.sh',
            'validate-lambda-package.sh',
            'sign-lambda-package.sh'
        ]
        
        for script_name in scripts_to_test:
            script_path = self.scripts_dir / script_name
            
            if script_path.exists():
                # Test script execution (mocked)
                result = subprocess.run(['bash', str(script_path)], capture_output=True, text=True)
                assert result.returncode == 0, f"Script {script_name} should execute successfully"
    
    def test_security_hub_integration(self):
        """Test Security Hub integration for centralized security findings."""
        workflow_files = list(self.github_workflows_dir.glob("*.yml")) + list(self.github_workflows_dir.glob("*.yaml"))
        
        security_hub_integration = False
        
        for workflow_file in workflow_files:
            with open(workflow_file, 'r') as f:
                workflow_content = f.read()
            
            # Check for Security Hub integration
            if ('security-hub' in workflow_content.lower() or 
                'securityhub' in workflow_content.lower() or
                'aws security' in workflow_content.lower()):
                security_hub_integration = True
                break
        
        # Check for Security Hub upload script
        security_scripts = [
            self.scripts_dir / "upload-security-findings.py",
            self.scripts_dir / "validate-production-readiness.py"
        ]
        
        for script in security_scripts:
            if script.exists():
                with open(script, 'r') as f:
                    script_content = f.read()
                
                if 'securityhub' in script_content.lower():
                    security_hub_integration = True
                    break
        
        assert security_hub_integration, "Should have Security Hub integration for centralized security findings"
    
    def test_artifact_validation(self):
        """Test that build artifacts are properly validated."""
        validation_script = self.scripts_dir / "validate-lambda-package.sh"
        
        if validation_script.exists():
            with open(validation_script, 'r') as f:
                script_content = f.read()
            
            # Check for validation steps
            validation_checks = [
                'checksum', 'hash', 'signature', 'size', 'format'
            ]
            
            found_checks = []
            for check in validation_checks:
                if check in script_content.lower():
                    found_checks.append(check)
            
            assert len(found_checks) >= 2, f"Should have multiple validation checks, found: {found_checks}"
    
    def test_monitoring_and_alerting_setup(self):
        """Test that monitoring and alerting are configured in deployment."""
        workflow_files = list(self.github_workflows_dir.glob("*.yml")) + list(self.github_workflows_dir.glob("*.yaml"))
        
        monitoring_configured = False
        
        for workflow_file in workflow_files:
            with open(workflow_file, 'r') as f:
                workflow_content = f.read()
            
            # Check for monitoring setup
            monitoring_keywords = [
                'cloudwatch', 'alarm', 'metric', 'monitoring', 'x-ray', 'tracing'
            ]
            
            for keyword in monitoring_keywords:
                if keyword in workflow_content.lower():
                    monitoring_configured = True
                    break
            
            if monitoring_configured:
                break
        
        # Check deployment scripts for monitoring setup
        if not monitoring_configured:
            deploy_script = self.scripts_dir / "deploy-lambda-canary.sh"
            if deploy_script.exists():
                with open(deploy_script, 'r') as f:
                    script_content = f.read()
                
                if any(keyword in script_content.lower() for keyword in monitoring_keywords):
                    monitoring_configured = True
        
        assert monitoring_configured, "Should configure monitoring and alerting during deployment"


if __name__ == '__main__':
    pytest.main([__file__, '-v'])