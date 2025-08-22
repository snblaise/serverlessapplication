import json
import boto3
from botocore.exceptions import ClientError

def lambda_handler(event, context):
    """
    Custom Config rule to check if Lambda functions use CMK encryption
    for environment variables
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
        
        # Check if environment variables exist
        if 'Environment' not in function_config:
            return {
                'compliance_type': 'COMPLIANT',
                'annotation': 'No environment variables configured'
            }
        
        # Check KMS key configuration
        kms_key_arn = function_config.get('KMSKeyArn')
        
        if not kms_key_arn:
            return {
                'compliance_type': 'NON_COMPLIANT',
                'annotation': 'Lambda function environment variables are not encrypted with CMK'
            }
        
        # Verify it's a CMK (not AWS managed key)
        if 'alias/aws/lambda' in kms_key_arn:
            return {
                'compliance_type': 'NON_COMPLIANT',
                'annotation': 'Lambda function uses AWS managed key instead of CMK'
            }
        
        return {
            'compliance_type': 'COMPLIANT',
            'annotation': f'Lambda function uses CMK for encryption: {kms_key_arn}'
        }
        
    except ClientError as e:
        return {
            'compliance_type': 'NON_COMPLIANT',
            'annotation': f'Error checking Lambda function: {str(e)}'
        }

def evaluate_compliance(configuration_item):
    """
    Evaluate compliance for the Lambda function
    """
    # This function would contain the main compliance logic
    # Called by the main handler
    pass