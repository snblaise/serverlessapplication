import json
import boto3
from botocore.exceptions import ClientError

def lambda_handler(event, context):
    """
    Custom Config rule to validate Lambda concurrency configuration
    for production workloads
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
        
        # Check if this is a production function (based on tags or naming)
        tags_response = lambda_client.list_tags(Resource=function_config['FunctionArn'])
        tags = tags_response.get('Tags', {})
        
        environment = tags.get('Environment', '').lower()
        
        # Only check production functions
        if environment != 'prod':
            return {
                'compliance_type': 'COMPLIANT',
                'annotation': 'Non-production function, concurrency validation not required'
            }
        
        # Check reserved concurrency configuration
        try:
            concurrency_response = lambda_client.get_function_concurrency(
                FunctionName=function_name
            )
            
            reserved_concurrency = concurrency_response.get('ReservedConcurrencyExecutions')
            
            if reserved_concurrency is None:
                return {
                    'compliance_type': 'NON_COMPLIANT',
                    'annotation': 'Production Lambda function must have reserved concurrency configured'
                }
            
            # Validate concurrency limits (between 10 and 1000 for production)
            if reserved_concurrency < 10:
                return {
                    'compliance_type': 'NON_COMPLIANT',
                    'annotation': f'Reserved concurrency too low for production: {reserved_concurrency} (minimum: 10)'
                }
            
            if reserved_concurrency > 1000:
                return {
                    'compliance_type': 'NON_COMPLIANT',
                    'annotation': f'Reserved concurrency too high: {reserved_concurrency} (maximum: 1000)'
                }
            
        except ClientError as e:
            if e.response['Error']['Code'] == 'ResourceNotFoundException':
                return {
                    'compliance_type': 'NON_COMPLIANT',
                    'annotation': 'Production Lambda function must have reserved concurrency configured'
                }
            raise
        
        # Check provisioned concurrency for critical functions
        function_criticality = tags.get('Criticality', '').lower()
        
        if function_criticality == 'critical':
            try:
                provisioned_response = lambda_client.get_provisioned_concurrency_config(
                    FunctionName=function_name,
                    Qualifier='$LATEST'
                )
                
                provisioned_concurrency = provisioned_response.get('AllocatedConcurrency', 0)
                
                if provisioned_concurrency == 0:
                    return {
                        'compliance_type': 'NON_COMPLIANT',
                        'annotation': 'Critical production function should have provisioned concurrency'
                    }
                
            except ClientError as e:
                if e.response['Error']['Code'] == 'ProvisionedConcurrencyConfigNotFoundException':
                    return {
                        'compliance_type': 'NON_COMPLIANT',
                        'annotation': 'Critical production function should have provisioned concurrency'
                    }
        
        return {
            'compliance_type': 'COMPLIANT',
            'annotation': f'Lambda concurrency properly configured - Reserved: {reserved_concurrency}'
        }
        
    except ClientError as e:
        return {
            'compliance_type': 'NON_COMPLIANT',
            'annotation': f'Error checking Lambda function concurrency: {str(e)}'
        }