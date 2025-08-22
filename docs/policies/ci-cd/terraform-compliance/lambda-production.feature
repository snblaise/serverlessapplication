Feature: Lambda Production Readiness Compliance
  As a DevOps engineer
  I want to ensure Lambda functions meet production standards
  So that they can be safely deployed to production

  @lambda @security
  Scenario: Lambda functions must have code signing enabled
    Given I have aws_lambda_function defined
    Then it must contain code_signing_config_arn

  @lambda @versioning
  Scenario: Lambda functions must be published for alias support
    Given I have aws_lambda_function defined
    Then it must contain publish
    And its value must be true

  @lambda @monitoring
  Scenario: Lambda functions must have X-Ray tracing enabled
    Given I have aws_lambda_function defined
    Then it must contain tracing_config
    And it must contain mode
    And its value must be Active

  @lambda @reliability
  Scenario: Lambda functions must have dead letter queue configured
    Given I have aws_lambda_function defined
    Then it must contain dead_letter_config
    And it must contain target_arn

  @lambda @performance
  Scenario: Production Lambda functions must have reserved concurrency
    Given I have aws_lambda_function defined
    When it contains tags
    And its tags contain Environment
    And its tags.Environment is prod
    Then it must contain reserved_concurrent_executions

  @lambda @security
  Scenario: Lambda functions must use CMK encryption for environment variables
    Given I have aws_lambda_function defined
    When it contains environment
    Then it must contain kms_key_arn
    And its kms_key_arn must not be alias/aws/lambda

  @lambda @networking
  Scenario: Production Lambda functions should be in VPC for data access
    Given I have aws_lambda_function defined
    When it contains tags
    And its tags contain Environment
    And its tags.Environment is prod
    And its tags contain DataAccess
    And its tags.DataAccess is true
    Then it must contain vpc_config

  @lambda @timeout
  Scenario: Lambda functions must have appropriate timeout settings
    Given I have aws_lambda_function defined
    Then it must contain timeout
    And its timeout must be less than 900
    And its timeout must be greater than 3

  @lambda @memory
  Scenario: Lambda functions must have appropriate memory settings
    Given I have aws_lambda_function defined
    Then it must contain memory_size
    And its memory_size must be greater than 128
    And its memory_size must be less than 10240

  @lambda @logs
  Scenario: Lambda functions must have log retention configured
    Given I have aws_cloudwatch_log_group defined
    When its name contains /aws/lambda/
    Then it must contain retention_in_days
    And its retention_in_days must be one of [7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653]