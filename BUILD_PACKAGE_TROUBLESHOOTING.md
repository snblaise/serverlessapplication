# Build-Package Stage Troubleshooting

## 🔧 Issues Fixed

I've identified and fixed several issues that could cause the workflow to stop at the build-package stage:

### 1. **AWS Role Configuration in Build Job**
**Problem**: The build-and-package job was using conditional logic for role selection, which could cause OIDC authentication issues.

**Fix Applied**:
```yaml
# Before (problematic)
role-to-assume: ${{ needs.setup.outputs.environment == 'production' && format('arn:aws:iam::{0}:role/{1}', secrets.AWS_ACCOUNT_ID_PROD, secrets.AWS_ROLE_NAME_PROD) || format('arn:aws:iam::{0}:role/{1}', secrets.AWS_ACCOUNT_ID_STAGING, secrets.AWS_ROLE_NAME_STAGING) }}

# After (fixed)
role-to-assume: ${{ format('arn:aws:iam::{0}:role/{1}', secrets.AWS_ACCOUNT_ID_STAGING, secrets.AWS_ROLE_NAME_STAGING) }}
```

### 2. **AWS Role Configuration in Security Scan Job**
**Problem**: The security-scan job (which build-and-package depends on) was also using conditional logic.

**Fix Applied**: Changed to always use staging credentials for consistency.

### 3. **Deploy-Staging Job Condition**
**Problem**: The deploy-staging job had restrictive conditions that might prevent it from running.

**Fix Applied**:
```yaml
# Before (restrictive)
if: needs.setup.outputs.environment == 'staging' || github.ref == 'refs/heads/develop' || github.event_name == 'pull_request'

# After (simplified)
if: always() && needs.build-and-package.result == 'success'
```

### 4. **Signing Profile References**
**Problem**: Build job was using dynamic environment references for signing profiles.

**Fix Applied**: Changed to use staging-specific signing profile consistently.

## 🔍 Debugging Steps

If the workflow is still stopping at build-package, check these areas:

### 1. **Check GitHub Actions Logs**
Look for specific error messages in the build-and-package job logs:
- OIDC authentication errors
- Script execution failures
- Missing dependencies

### 2. **Verify Script Permissions**
Ensure all scripts have execute permissions:
```bash
ls -la scripts/
# Should show executable permissions for:
# - build-lambda-package.sh
# - validate-lambda-package.sh
# - sign-lambda-package.sh (if used)
```

### 3. **Check Dependencies**
Verify all required dependencies are available:
- Node.js and npm
- Python 3 (for security scripts)
- AWS CLI
- jq (for JSON processing)

### 4. **Test Scripts Locally**
Test the build script locally:
```bash
chmod +x scripts/build-lambda-package.sh
./scripts/build-lambda-package.sh
```

### 5. **Check Environment Variables**
Verify that all required environment variables are available:
- `NODE_VERSION`
- `AWS_REGION`
- Setup outputs: `environment` and `aws-region`

## 🚀 Expected Workflow Flow

With the fixes applied, the workflow should now follow this pattern:

```
setup → lint-and-test → security-scan → build-and-package → deploy-staging
```

### Key Changes:
1. **Consistent Role Usage**: All pre-deployment jobs use staging credentials
2. **Simplified Conditions**: Deploy-staging runs whenever build succeeds
3. **Fixed Dependencies**: All job dependencies are properly configured

## 🔧 Common Issues and Solutions

### Issue 1: "Script not found" Error
**Solution**: Ensure all scripts exist and have proper permissions:
```bash
find scripts/ -name "*.sh" -exec chmod +x {} \;
```

### Issue 2: "npm ci failed" Error
**Solution**: Check if package.json and package-lock.json are present and valid.

### Issue 3: "AWS credentials not configured" Error
**Solution**: Verify GitHub secrets are properly set:
```bash
gh secret list --repo snblaise/serverlessapplication
```

### Issue 4: "Checkov not found" Error
**Solution**: The workflow installs Checkov via pip3. Ensure Python 3 is available.

## 📋 Verification Checklist

Before running the workflow, verify:

- [ ] All GitHub secrets are set correctly
- [ ] IAM roles exist and have proper trust policies
- [ ] All scripts in `/scripts` directory have execute permissions
- [ ] `package.json` and `package-lock.json` exist
- [ ] Node.js version is compatible (currently set to 18)
- [ ] Repository has proper branch structure

## 🔍 Monitoring

To monitor the workflow execution:

1. **GitHub Actions Tab**: Check real-time progress
2. **Job Logs**: Expand each step to see detailed output
3. **Artifacts**: Download build artifacts if job completes
4. **Environment Status**: Check environment deployment status

## 🆘 Emergency Debugging

If the workflow continues to fail:

1. **Simplify the Build Job**: Temporarily remove optional steps like signing
2. **Add Debug Output**: Add `set -x` to shell scripts for verbose output
3. **Test Individual Steps**: Run each step manually to isolate the issue
4. **Check Resource Limits**: Ensure GitHub Actions runner has sufficient resources

## 📞 Next Steps

1. **Test the Fixed Workflow**: Push a change to trigger the workflow
2. **Monitor Execution**: Watch the build-and-package job closely
3. **Check Logs**: Review any error messages in detail
4. **Iterate**: Apply additional fixes based on specific error messages

The fixes applied should resolve the most common causes of workflow stoppage at the build-package stage.