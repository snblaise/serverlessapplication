import json
import boto3
from botocore.exceptions import ClientError

def lambda_handler(event, context):
    """
    Custom Config rule to check if public API Gateway stages
    have WAF association
    """
    
    # Initialize AWS clients
    config_client = boto3.client('config')
    apigateway_client = boto3.client('apigateway')
    wafv2_client = boto3.client('wafv2')
    
    # Get the configuration item from the event
    configuration_item = event['configurationItem']
    
    # Check if this is an API Gateway stage
    if configuration_item['resourceType'] != 'AWS::ApiGateway::Stage':
        return {
            'compliance_type': 'NOT_APPLICABLE',
            'annotation': 'Resource is not an API Gateway stage'
        }
    
    try:
        # Parse resource ID to get REST API ID and stage name
        resource_id = configuration_item['resourceId']
        rest_api_id, stage_name = resource_id.split('/')
        
        # Get API Gateway stage configuration
        stage_response = apigateway_client.get_stage(
            restApiId=rest_api_id,
            stageName=stage_name
        )
        
        # Get REST API configuration to check endpoint type
        api_response = apigateway_client.get_rest_api(restApiId=rest_api_id)
        
        # Check if this is a public endpoint (EDGE or REGIONAL with public access)
        endpoint_configuration = api_response.get('endpointConfiguration', {})
        endpoint_types = endpoint_configuration.get('types', [])
        
        # If it's a private endpoint, it's compliant
        if 'PRIVATE' in endpoint_types:
            return {
                'compliance_type': 'COMPLIANT',
                'annotation': 'Private API Gateway endpoint does not require WAF'
            }
        
        # For public endpoints, check WAF association
        stage_arn = f"arn:aws:apigateway:{context.invoked_function_arn.split(':')[3]}::/restapis/{rest_api_id}/stages/{stage_name}"
        
        # Check WAFv2 associations
        try:
            waf_response = wafv2_client.get_web_acl_for_resource(
                ResourceArn=stage_arn
            )
            
            if waf_response.get('WebACL'):
                return {
                    'compliance_type': 'COMPLIANT',
                    'annotation': f'API Gateway stage has WAF association: {waf_response["WebACL"]["Name"]}'
                }
        except ClientError as e:
            if e.response['Error']['Code'] != 'WAFNonexistentItemException':
                raise
        
        return {
            'compliance_type': 'NON_COMPLIANT',
            'annotation': 'Public API Gateway stage does not have WAF association'
        }
        
    except ClientError as e:
        return {
            'compliance_type': 'NON_COMPLIANT',
            'annotation': f'Error checking API Gateway stage: {str(e)}'
        }
    except Exception as e:
        return {
            'compliance_type': 'NON_COMPLIANT',
            'annotation': f'Unexpected error: {str(e)}'
        }