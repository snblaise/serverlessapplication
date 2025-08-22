# Script Cleanup Plan

## Scripts to Keep (Essential for CI/CD Pipeline)

### Core Workflow Scripts (Referenced in .github/workflows/lambda-cicd.yml)
- `scripts/build-lambda-package.sh` - Used in build-and-package job
- `scripts/validate-lambda-package.sh` - Used for package validation
- `scripts/sign-lambda-package.sh` - Used for code signing
- `scripts/deploy-lambda-canary.sh` - Used for deployment
- `scripts/rollback-lambda-deployment.sh` - Used for rollback
- `scripts/upload-security-findings.py` - Used for Security Hub integration

### Setup and Diagnostic Scripts (Useful for troubleshooting)
- `scripts/setup-github-secrets.sh` - For setting up GitHub secrets
- `scripts/diagnose-oidc.sh` - For troubleshooting OIDC issues
- `scripts/validate-workflow.sh` - For workflow validation

### Documentation and Compliance Scripts (Referenced in docs)
- `scripts/generate-docs.py` - For documentation generation
- `scripts/validate-production-readiness.py` - For overall validation
- `scripts/validate-checklist-compliance.py` - For checklist automation
- `scripts/generate-checklist-evidence.py` - For evidence collection
- `scripts/generate-control-matrix.py` - For control matrix generation
- `scripts/validate-control-matrix.py` - For matrix validation

## Scripts to Remove (Unnecessary/Redundant)

### Duplicate/Redundant OIDC Scripts
- `scripts/check-github-oidc.sh` - Redundant with diagnose-oidc.sh
- `scripts/setup-github-oidc.sh` - Functionality covered by setup-github-secrets.sh

### CodeBuild/CodePipeline Scripts (Not used in current GitHub Actions workflow)
- `scripts/trigger-codebuild.sh` - Not needed with GitHub Actions
- `scripts/trigger-pipeline.sh` - Not needed with GitHub Actions
- `scripts/deploy-pipeline-infrastructure.sh` - Not needed with GitHub Actions

### Testing/Development Scripts
- `scripts/test-github-actions-terraform.sh` - Development/testing only
- `scripts/deploy-github-actions.sh` - Development helper, not needed
- `scripts/validate-complete-integration.py` - Redundant with other validation scripts

### AWS Resource Management Scripts (Manual operations)
- `scripts/setup-aws-resources.sh` - Manual setup, not automated
- `scripts/teardown-aws-resources.sh` - Manual teardown, not automated

## Summary
- **Keep**: 15 scripts (essential for CI/CD and compliance)
- **Remove**: 9 scripts (redundant, unused, or development-only)