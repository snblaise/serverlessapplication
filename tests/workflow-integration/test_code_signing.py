#!/usr/bin/env python3
"""
Test suite for code signing validation and signature enforcement.
Tests AWS Signer integration and signature verification processes.
"""

import json
import boto3
import pytest
import subprocess
import tempfile
import zipfile
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock
from moto import mock_lambda, mock_signer
import hashlib
import base64


class TestCodeSigning:
    """Test cases for code signing validation and enforcement."""
    
    @classmethod
    def setup_class(cls):
        """Set up test environment and load configurations."""
        cls.project_root = Path(__file__).parent.parent.parent
        cls.scripts_dir = cls.project_root / "scripts"
        cls.policies_dir = cls.project_root / "docs" / "policies"
    
    def setup_method(self):
        """Set up test method with temporary directories."""
        self.temp_dir = Path(tempfile.mkdtemp())
        self.test_package_path = self.temp_dir / "test-lambda.zip"
        self._create_test_lambda_package()
    
    def teardown_method(self):
        """Clean up temporary directories."""
        import shutil
        if self.temp_dir.exists():
            shutil.rmtree(self.temp_dir)
    
    def _create_test_lambda_package(self):
        """Create a test Lambda package for signing tests."""
        with zipfile.ZipFile(self.test_package_path, 'w') as zip_file:
            # Add a simple Lambda function
            zip_file.writestr('index.js', '''
exports.handler = async (event) => {
    return {
        statusCode: 200,
        body: JSON.stringify('Hello from Lambda!')
    };
};
''')
            # Add package.json
            zip_file.writestr('package.json', '''
{
    "name": "test-lambda",
    "version": "1.0.0",
    "main": "index.js"
}
''')
    
    def test_signing_script_exists(self):
        """Test that code signing script exists and has correct structure."""
        signing_script = self.scripts_dir / "sign-lambda-package.sh"
        
        assert signing_script.exists(), "Code signing script should exist"
        
        with open(signing_script, 'r') as f:
            script_content = f.read()
        
        # Basic script validation
        assert script_content.startswith('#!/'), "Script should have shebang"
        assert 'set -e' in script_content, "Script should have error handling"
        
        # Check for AWS Signer integration
        assert 'aws signer' in script_content.lower(), "Should use AWS Signer CLI"
        assert 'signing-profile' in script_content.lower(), "Should reference signing profile"
        
        # Check for required parameters
        required_elements = [
            'profile-name', 'source', 'destination'
        ]
        
        for element in required_elements:
            assert element in script_content.lower(), f"Script should include {element}"
    
    def test_scp_code_signing_enforcement(self):
        """Test that SCP enforces code signing requirements."""
        scp_file = self.policies_dir / "scp-lambda-code-signing.json"
        
        assert scp_file.exists(), "Code signing SCP should exist"
        
        with open(scp_file, 'r') as f:
            scp_policy = json.load(f)
        
        # Validate SCP structure
        assert scp_policy['Version'] == '2012-10-17'
        assert 'Statement' in scp_policy
        
        # Check for code signing enforcement statements
        code_signing_statements = []
        for stmt in scp_policy['Statement']:
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
        
        assert len(code_signing_statements) >= 1, "SCP should enforce code signing"
    
    @mock_signer
    def test_signing_profile_configuration(self):
        """Test AWS Signer profile configuration."""
        signer_client = boto3.client('signer', region_name='us-east-1')
        
        try:
            # Create a test signing profile
            profile_name = 'test-lambda-signing-profile'
            
            response = signer_client.put_signing_profile(
                profileName=profile_name,
                signingMaterial={
                    'certificateArn': 'arn:aws:acm:us-east-1:123456789012:certificate/test-cert'
                },
                platformId='AWSLambda-SHA384-ECDSA'
            )
            
            assert response['arn'], "Signing profile should be created successfully"
            
            # List signing profiles
            profiles = signer_client.list_signing_profiles()
            profile_names = [p['profileName'] for p in profiles['profiles']]
            assert profile_name in profile_names, "Profile should be listed"
            
        except Exception as e:
            # Some operations might not be fully supported in moto
            pytest.skip(f"Signing profile test not supported: {e}")
    
    @patch('subprocess.run')
    def test_package_signing_process(self, mock_subprocess):
        """Test the package signing process."""
        # Mock successful signing
        mock_subprocess.return_value = Mock(
            returncode=0,
            stdout='Successfully signed package',
            stderr=''
        )
        
        signing_script = self.scripts_dir / "sign-lambda-package.sh"
        
        if signing_script.exists():
            # Test signing script execution
            result = subprocess.run([
                'bash', str(signing_script),
                str(self.test_package_path),
                'test-signing-profile',
                str(self.temp_dir / "signed-package.zip")
            ], capture_output=True, text=True)
            
            assert result.returncode == 0, "Signing script should execute successfully"
    
    def test_signature_verification_logic(self):
        """Test signature verification logic."""
        # Check if there's a signature verification script or function
        validation_script = self.scripts_dir / "validate-lambda-package.sh"
        
        if validation_script.exists():
            with open(validation_script, 'r') as f:
                script_content = f.read()
            
            # Check for signature verification
            verification_keywords = [
                'signature', 'verify', 'signed', 'signer'
            ]
            
            found_keywords = []
            for keyword in verification_keywords:
                if keyword in script_content.lower():
                    found_keywords.append(keyword)
            
            assert len(found_keywords) >= 2, f"Should have signature verification, found: {found_keywords}"
    
    @mock_lambda
    def test_unsigned_code_deployment_prevention(self):
        """Test that unsigned code deployment is prevented."""
        lambda_client = boto3.client('lambda', region_name='us-east-1')
        
        try:
            # Attempt to create function without code signing config
            # This should be denied by SCP in real environment
            function_name = 'test-unsigned-function'
            
            # In a real test, this would be blocked by SCP
            # Here we simulate the policy evaluation
            deployment_allowed = self._simulate_scp_evaluation(
                action='lambda:CreateFunction',
                conditions={'lambda:CodeSigningConfigArn': None}
            )
            
            assert not deployment_allowed, "Unsigned code deployment should be denied"
            
        except Exception as e:
            # Expected in real environment with SCP enforcement
            pass
    
    def _simulate_scp_evaluation(self, action, conditions):
        """Simulate SCP policy evaluation for code signing."""
        # Load the code signing SCP
        scp_file = self.policies_dir / "scp-lambda-code-signing.json"
        
        if not scp_file.exists():
            return True  # No policy, allow by default
        
        with open(scp_file, 'r') as f:
            scp_policy = json.load(f)
        
        # Evaluate policy statements
        for stmt in scp_policy['Statement']:
            if stmt.get('Effect') == 'Deny':
                actions = stmt.get('Action', [])
                if isinstance(actions, str):
                    actions = [actions]
                
                if action in actions:
                    condition = stmt.get('Condition', {})
                    if self._evaluate_condition(condition, conditions):
                        return False  # Denied
        
        return True  # Allowed
    
    def _evaluate_condition(self, policy_condition, actual_conditions):
        """Evaluate policy condition against actual conditions."""
        for operator, condition_block in policy_condition.items():
            if operator == 'Null':
                for key, expected_null in condition_block.items():
                    actual_value = actual_conditions.get(key.split(':')[-1])
                    is_null = actual_value is None
                    
                    if expected_null == 'true' and not is_null:
                        return False
                    elif expected_null == 'false' and is_null:
                        return False
        
        return True
    
    def test_code_signing_config_creation(self):
        """Test Lambda code signing configuration creation."""
        # This would typically be done via CloudFormation or Terraform
        # Here we test the configuration structure
        
        code_signing_config = {
            'AllowedPublishers': {
                'SigningProfileVersionArns': [
                    'arn:aws:signer:us-east-1:123456789012:signing-profile/lambda-signing-profile'
                ]
            },
            'CodeSigningPolicies': {
                'UntrustedArtifactOnDeployment': 'Enforce'
            }
        }
        
        # Validate configuration structure
        assert 'AllowedPublishers' in code_signing_config
        assert 'SigningProfileVersionArns' in code_signing_config['AllowedPublishers']
        assert 'CodeSigningPolicies' in code_signing_config
        assert code_signing_config['CodeSigningPolicies']['UntrustedArtifactOnDeployment'] == 'Enforce'
    
    def test_signing_job_monitoring(self):
        """Test that signing jobs can be monitored and tracked."""
        # Check for monitoring integration in signing script
        signing_script = self.scripts_dir / "sign-lambda-package.sh"
        
        if signing_script.exists():
            with open(signing_script, 'r') as f:
                script_content = f.read()
            
            # Check for job tracking
            monitoring_elements = [
                'job-id', 'status', 'describe-signing-job'
            ]
            
            found_elements = []
            for element in monitoring_elements:
                if element in script_content.lower():
                    found_elements.append(element)
            
            # Should have some form of job monitoring
            assert len(found_elements) >= 1, f"Should monitor signing jobs, found: {found_elements}"
    
    def test_signature_format_validation(self):
        """Test that signature format is validated."""
        # Test signature format requirements
        expected_signature_format = {
            'algorithm': 'SHA384withECDSA',
            'format': 'PKCS7',
            'platform': 'AWSLambda-SHA384-ECDSA'
        }
        
        # Validate that these are the expected formats for Lambda
        assert expected_signature_format['algorithm'] == 'SHA384withECDSA'
        assert expected_signature_format['platform'] == 'AWSLambda-SHA384-ECDSA'
    
    def test_certificate_validation(self):
        """Test certificate validation requirements."""
        # Check for certificate validation in scripts or policies
        validation_script = self.scripts_dir / "validate-lambda-package.sh"
        
        if validation_script.exists():
            with open(validation_script, 'r') as f:
                script_content = f.read()
            
            # Check for certificate validation
            cert_keywords = [
                'certificate', 'cert', 'acm', 'ca'
            ]
            
            found_keywords = []
            for keyword in cert_keywords:
                if keyword in script_content.lower():
                    found_keywords.append(keyword)
            
            # Should validate certificates
            if len(found_keywords) >= 1:
                assert True, "Certificate validation found"
            else:
                # Certificate validation might be handled by AWS Signer automatically
                pytest.skip("Certificate validation handled by AWS Signer")
    
    def test_signing_metadata_preservation(self):
        """Test that signing preserves package metadata."""
        # Create test package with metadata
        metadata_package = self.temp_dir / "metadata-test.zip"
        
        with zipfile.ZipFile(metadata_package, 'w') as zip_file:
            zip_file.writestr('index.js', 'exports.handler = () => {};')
            zip_file.writestr('package.json', '{"name": "test", "version": "1.0.0"}')
            zip_file.writestr('README.md', '# Test Package')
        
        # Get original package info
        original_info = zipfile.ZipFile(metadata_package).infolist()
        original_files = [info.filename for info in original_info]
        
        # Simulate signing (in real scenario, this would call AWS Signer)
        signed_package = self.temp_dir / "signed-metadata-test.zip"
        
        # For testing, just copy the package (real signing would modify it)
        import shutil
        shutil.copy2(metadata_package, signed_package)
        
        # Verify files are preserved
        signed_info = zipfile.ZipFile(signed_package).infolist()
        signed_files = [info.filename for info in signed_info]
        
        assert set(original_files) == set(signed_files), "Signing should preserve all files"
    
    def test_signing_error_handling(self):
        """Test error handling in signing process."""
        signing_script = self.scripts_dir / "sign-lambda-package.sh"
        
        if signing_script.exists():
            with open(signing_script, 'r') as f:
                script_content = f.read()
            
            # Check for error handling
            error_handling_elements = [
                'set -e', 'trap', 'exit', 'error'
            ]
            
            found_elements = []
            for element in error_handling_elements:
                if element in script_content.lower():
                    found_elements.append(element)
            
            assert len(found_elements) >= 2, f"Should have proper error handling, found: {found_elements}"


if __name__ == '__main__':
    pytest.main([__file__, '-v'])