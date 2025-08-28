# Resource Management with Lifecycle Rules and Existing Resource Adoption
# This file handles existing AWS resources gracefully to prevent conflicts

# Locals to determine resource creation strategy
# Note: We use the adoption script to import existing resources instead of data sources
# This avoids errors when resources don't exist yet
locals {
  # For new deployments, create all resources
  # For existing deployments, run the adoption script first
  codedeploy_role_exists = false  # Will be imported by adoption script if exists
  s3_bucket_exists       = false  # Will be imported by adoption script if exists
  codedeploy_app_exists  = false  # Will be imported by adoption script if exists
  
  # Resource ARNs/names to use
  codedeploy_role_arn = aws_iam_role.codedeploy_service_role[0].arn
  s3_bucket_name      = aws_s3_bucket.lambda_artifacts[0].bucket
  codedeploy_app_name = "lambda-app-${var.environment}"  # Use consistent naming
}

# Import instructions for manual resource adoption:
# Run the adoption script: ./scripts/adopt-existing-resources.sh staging us-east-1
# Or manually import resources:
# terraform import aws_iam_role.codedeploy_service_role[0] CodeDeployServiceRole-staging
# terraform import aws_s3_bucket.lambda_artifacts[0] lambda-artifacts-staging-snblaise-serverless-2025
# terraform import aws_codedeploy_app.lambda_app[0] lambda-app-staging