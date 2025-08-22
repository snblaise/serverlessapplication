from checkov.common.models import CheckResult, CheckCategories
from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck

class LambdaCodeSigningCheck(BaseResourceCheck):
    def __init__(self):
        name = "Ensure Lambda function has code signing configuration"
        id = "CKV_CUSTOM_LAMBDA_1"
        supported_resources = ['aws_lambda_function']
        categories = [CheckCategories.GENERAL_SECURITY]
        super().__init__(name=name, id=id, categories=categories, supported_resources=supported_resources)

    def scan_resource_conf(self, conf):
        """
        Looks for code signing configuration in Lambda function:
        https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function
        """
        if 'code_signing_config_arn' in conf:
            code_signing_arn = conf['code_signing_config_arn'][0]
            if isinstance(code_signing_arn, str) and code_signing_arn.strip():
                return CheckResult.PASSED
        
        return CheckResult.FAILED

check = LambdaCodeSigningCheck()