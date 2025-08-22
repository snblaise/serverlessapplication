from checkov.common.models import CheckResult, CheckCategories
from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck

class LambdaTracingCheck(BaseResourceCheck):
    def __init__(self):
        name = "Ensure Lambda function has X-Ray tracing enabled"
        id = "CKV_CUSTOM_LAMBDA_3"
        supported_resources = ['aws_lambda_function']
        categories = [CheckCategories.LOGGING]
        super().__init__(name=name, id=id, categories=categories, supported_resources=supported_resources)

    def scan_resource_conf(self, conf):
        """
        Looks for tracing configuration in Lambda function:
        tracing_config {
          mode = "Active"
        }
        """
        if 'tracing_config' in conf:
            tracing_config = conf['tracing_config'][0]
            if isinstance(tracing_config, dict):
                mode = tracing_config.get('mode', [])
                if isinstance(mode, list) and len(mode) > 0:
                    mode_value = mode[0]
                    if isinstance(mode_value, str) and mode_value.lower() == 'active':
                        return CheckResult.PASSED
        
        return CheckResult.FAILED

check = LambdaTracingCheck()