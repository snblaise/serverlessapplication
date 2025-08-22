# GitHub OIDC Authentication Fix

## Issue
"Could not load credentials from any providers" error in GitHub Actions when using OIDC.

## Root Cause
The `aws-actions/configure-aws-credentials@v4` action was missing the required `audience` parameter for OIDC authentication in multiple jobs.

## Fix Applied

### 1. Added `audience` parameter to ALL AWS credential configurations:
```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ needs.setup.outputs.aws-role-arn }}
    role-session-name: GitHubActions-Build
    aws-region: ${{ needs.setup.outputs.aws-region }}
    audience: sts.amazonaws.com  # ← This was missing
```

**Fixed in these jobs:**
- ✅ `security-scan` job
- ✅ `build-and-package` job  
- ✅ `deploy` job
- ✅ `rollback` job

### 2. Created diagnostic tools:
- `scripts/diagnose-oidc.sh` - Comprehensive OIDC troubleshooting script
- `.github/workflows/test-oidc-simple.yml` - Minimal OIDC test workflow

### 3. Enhanced workflow permissions:
```yaml
permissions:
  id-token: write  # Required for OIDC
  contents: read
  security-events: write
  pull-requests: write
```

## Verification

### Current OIDC Setup:
- ✅ OIDC Provider: `arn:aws:iam::948572562675:oidc-provider/token.actions.githubusercontent.com`
- ✅ IAM Role: `arn:aws:iam::948572562675:role/GitHubActions-Lambda-Staging`
- ✅ GitHub Secret: `AWS_ACCOUNT_ID_STAGING = 948572562675`
- ✅ Trust Policy: Configured for `snblaise/serverlessapplication`

### Test Commands:
```bash
# Run diagnostic script
./scripts/diagnose-oidc.sh snblaise serverlessapplication staging

# Trigger simple test workflow
gh workflow run test-oidc-simple.yml --repo snblaise/serverlessapplication

# Check workflow status
gh run list --workflow=test-oidc-simple.yml --repo snblaise/serverlessapplication
```

### Troubleshooting:
If still failing, run the diagnostic script:
```bash
chmod +x scripts/diagnose-oidc.sh
./scripts/diagnose-oidc.sh
```

This will check:
- OIDC provider existence
- IAM role configuration
- Trust policy conditions
- Repository permissions
- Account ID setup

## Expected Result
GitHub Actions should now successfully authenticate with AWS using OIDC without the credentials error.

## Next Steps
1. Push changes to trigger workflows
2. Run the simple test workflow first
3. Monitor GitHub Actions for successful OIDC authentication
4. Remove test files after verification

Fixed on: $(date)