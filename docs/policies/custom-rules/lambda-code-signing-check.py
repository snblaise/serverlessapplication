import json
import boto3
from botocore.exceptions import ClientError

def lambda_handler(event, context):
    """
    Custom Config rule to check if Lambda functions have
    code signing configuration enabled
    """
    
    # Initialize AWS clients
    config_client = boto3.client('config')
    lambda_client = boto3.client('lambda')
    
    # Get the configuration item from the event
    configuration_item = event['configurationItem']
    
    # Check if this is a Lambda function
    if configuration_item['resourceType'] != 'AWS::Lambda::Function':
        return {
            'compliance_type': 'NOT_APPLICABLE',
            'annotation': 'Resource is not a Lambda function'
        }
    
    function_name = configuration_item['resourceName']
    
    try:
        # Get Lambda function configuration
        response = lambda_client.get_function(FunctionName=function_name)
        function_config = response['Configuration']
        
        # Check code signing configuration
        code_signing_config_arn = function_config.get('CodeSigningConfigArn')
        
        if not code_signing_config_arn:
            return {
                'compliance_type': 'NON_COMPLIANT',
                'annotation': 'Lambda function does not have code signing configuration'
            }
        
        # Verify the code signing config exists and is active
        try:
            signing_response = lambda_client.get_code_signing_config(
                CodeSigningConfigArn=code_signing_config_arn
            )
            
            signing_config = signing_response['CodeSigningConfig']
            
            # Check if code signing is enforced
            code_signing_policies = signing_config.get('CodeSigningPolicies', {})
            untrusted_artifact_on_deployment = code_signing_policies.get('UntrustedArtifactOnDeployment', 'Warn')
            
            if untrusted_artifact_on_deployment != 'Enforce':
                return {
                    'compliance_type': 'NON_COMPLIANT',
                    'annotation': 'Code signing configuration does not enforce signature validation'
                }
            
            return {
                'compliance_type': 'COMPLIANT',
                'annotation': f'Lambda function has enforced code signing: {code_signing_config_arn}'
            }
            
        except ClientError as e:
            return {
                'compliance_type': 'NON_COMPLIANT',
                'annotation': f'Code signing configuration not found or invalid: {str(e)}'
            }
        
    except ClientError as e:
        return {
            'compliance_type': 'NON_COMPLIANT',
            'annotation': f'Error checking Lambda function: {str(e)}'
        }