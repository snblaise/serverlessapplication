from checkov.common.models import CheckResult, CheckCategories
from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck

class LambdaAliasCheck(BaseResourceCheck):
    def __init__(self):
        name = "Ensure Lambda function has alias for production deployment"
        id = "CKV_CUSTOM_LAMBDA_2"
        supported_resources = ['aws_lambda_function']
        categories = [CheckCategories.GENERAL_SECURITY]
        super().__init__(name=name, id=id, categories=categories, supported_resources=supported_resources)

    def scan_resource_conf(self, conf):
        """
        Checks if Lambda function is deployed with versioning strategy
        by looking for publish = true or version configuration
        """
        # Check if publish is enabled (required for aliases)
        if 'publish' in conf:
            publish_value = conf['publish'][0]
            if isinstance(publish_value, bool) and publish_value:
                return CheckResult.PASSED
            if isinstance(publish_value, str) and publish_value.lower() == 'true':
                return CheckResult.PASSED
        
        return CheckResult.FAILED

check = LambdaAliasCheck()