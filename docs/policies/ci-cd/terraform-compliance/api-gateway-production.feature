Feature: API Gateway Production Readiness Compliance
  As a DevOps engineer
  I want to ensure API Gateway configurations meet production standards
  So that APIs are secure and performant

  @apigateway @security
  Scenario: API Gateway stages must have WAF association for public endpoints
    Given I have aws_api_gateway_stage defined
    When it contains deployment_id
    Then it must contain web_acl_arn

  @apigateway @monitoring
  Scenario: API Gateway stages must have X-Ray tracing enabled
    Given I have aws_api_gateway_stage defined
    Then it must contain xray_tracing_enabled
    And its xray_tracing_enabled must be true

  @apigateway @logging
  Scenario: API Gateway stages must have access logging enabled
    Given I have aws_api_gateway_stage defined
    Then it must contain access_log_destination_arn

  @apigateway @throttling
  Scenario: API Gateway methods must have throttling configured
    Given I have aws_api_gateway_method defined
    Then it must contain throttle_settings
    And it must contain rate_limit
    And it must contain burst_limit

  @apigateway @validation
  Scenario: API Gateway methods must have request validation
    Given I have aws_api_gateway_method defined
    When its http_method is POST or PUT or PATCH
    Then it must contain request_validator_id

  @apigateway @caching
  Scenario: Production API Gateway stages should have caching enabled
    Given I have aws_api_gateway_stage defined
    When it contains tags
    And its tags contain Environment
    And its tags.Environment is prod
    Then it must contain cache_cluster_enabled
    And its cache_cluster_enabled must be true

  @apigateway @security
  Scenario: API Gateway domain names must use TLS 1.2 or higher
    Given I have aws_api_gateway_domain_name defined
    Then it must contain security_policy
    And its security_policy must be TLS_1_2

  @apigateway @cors
  Scenario: API Gateway methods with CORS must be properly configured
    Given I have aws_api_gateway_method defined
    When its http_method is OPTIONS
    Then it must contain method_response
    And it must contain integration_response