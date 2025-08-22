# Staging-to-Production Deployment Workflow

This document explains the updated CI/CD pipeline that implements a staging-to-production promotion workflow with manual approval and automatic rollback capabilities.

## 🔄 Workflow Overview

The pipeline now follows this flow:

```
Code Push/PR → Build & Test → Deploy to Staging → Manual Approval → Deploy to Production
                    ↓              ↓                                        ↓
                Rollback        Rollback                                Rollback
               (if fails)      (if fails)                             (if fails)
```

## 🚀 Deployment Flow

### 1. **Automatic Staging Deployment**
- **Triggers**: 
  - Push to `develop` branch
  - Pull requests to `main`
  - Manual workflow dispatch with `staging` environment
- **Process**:
  - Builds and packages the Lambda function
  - Runs security scans and tests
  - Deploys to staging environment
  - Performs health checks
  - **Auto-rollback** if deployment fails

### 2. **Manual Production Approval**
- **Triggers**: After successful staging deployment on `main` branch
- **Process**:
  - Requires manual approval via GitHub Environment protection
  - Sends notification (can be extended with email integration)
  - Blocks production deployment until approved

### 3. **Production Deployment**
- **Triggers**: After manual approval is granted
- **Process**:
  - Uses the same artifacts from staging
  - Deploys to production environment
  - Performs health checks
  - **Auto-rollback** if deployment fails

## 🛡️ Rollback Strategy

### Automatic Rollback Scenarios:
1. **Staging Deployment Failure** → Automatic staging rollback
2. **Production Deployment Failure** → Automatic production rollback

### Manual Rollback:
- Can be triggered via workflow dispatch for any environment
- Useful for emergency situations or planned rollbacks

## 🔧 Environment Configuration

### GitHub Environments Required:
1. `staging` - For staging deployments
2. `production-approval` - For manual approval gate
3. `production` - For production deployments (with protection rules)
4. `staging-rollback` - For staging rollback operations
5. `production-rollback` - For production rollback operations

### Environment Protection Rules:
```yaml
# production-approval environment
required_reviewers: ["team-lead", "devops-admin"]
wait_timer: 0 # No wait time, just approval

# production environment  
required_reviewers: ["team-lead", "devops-admin"]
wait_timer: 0
```

## 📧 Setting Up Email Notifications

To enable email notifications for production approvals, you can integrate with:

### Option 1: GitHub Notifications (Built-in)
- Configure in repository settings
- Environment protection rules automatically notify reviewers

### Option 2: External Email Service
Add to the `request-production-approval` job:

```yaml
- name: Send approval email
  uses: dawidd6/action-send-mail@v3
  with:
    server_address: smtp.gmail.com
    server_port: 465
    username: ${{ secrets.EMAIL_USERNAME }}
    password: ${{ secrets.EMAIL_PASSWORD }}
    subject: "Production Deployment Approval Required"
    to: team-lead@company.com,devops@company.com
    from: github-actions@company.com
    body: |
      Production deployment approval is required.
      
      Commit: ${{ github.sha }}
      Branch: ${{ github.ref }}
      Actor: ${{ github.actor }}
      
      Please review and approve at:
      https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}
```

### Option 3: Slack Integration
```yaml
- name: Send Slack notification
  uses: 8398a7/action-slack@v3
  with:
    status: custom
    custom_payload: |
      {
        "text": "Production deployment approval required",
        "attachments": [{
          "color": "warning",
          "fields": [{
            "title": "Repository",
            "value": "${{ github.repository }}",
            "short": true
          }, {
            "title": "Commit",
            "value": "${{ github.sha }}",
            "short": true
          }]
        }]
      }
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

## 🎯 Branch Strategy

### Development Flow:
1. **Feature Development**: Work on feature branches
2. **Staging Testing**: Merge to `develop` → Auto-deploy to staging
3. **Production Release**: Merge to `main` → Deploy to staging → Manual approval → Deploy to production

### Hotfix Flow:
1. Create hotfix branch from `main`
2. Test via manual workflow dispatch to staging
3. Merge to `main` → Follow normal production flow

## 🔍 Monitoring and Alerts

### Deployment Status:
- Check GitHub Actions tab for real-time status
- Artifacts contain deployment reports and health check results

### Rollback Alerts:
- Automatic rollbacks generate detailed reports
- Critical production rollbacks are highlighted in logs

### Health Checks:
- Post-deployment Lambda function invocation tests
- Response validation and error detection
- Environment-specific test payloads

## 🛠️ Troubleshooting

### Common Issues:

#### 1. Staging Deployment Fails
- Check build artifacts and security scan results
- Review Lambda function logs
- Automatic rollback should restore previous version

#### 2. Production Approval Timeout
- Check environment protection settings
- Ensure reviewers have proper permissions
- Review notification settings

#### 3. Production Deployment Fails
- Automatic rollback will trigger
- Check production-specific configurations
- Review IAM permissions for production role

#### 4. Rollback Fails
- Check rollback script logs
- Verify previous version availability
- May require manual intervention

### Manual Intervention:
If automatic rollback fails, you can:
1. Trigger manual rollback via workflow dispatch
2. Use AWS Console to manually revert Lambda function
3. Check CloudWatch logs for detailed error information

## 📋 Setup Checklist

- [ ] Configure GitHub environments with protection rules
- [ ] Set up required reviewers for production approval
- [ ] Test staging deployment flow
- [ ] Test production approval process
- [ ] Test rollback scenarios
- [ ] Configure notification preferences
- [ ] Document emergency procedures
- [ ] Train team on new workflow

## 🔗 Related Documentation

- [GitHub OIDC Setup](./GITHUB_OIDC_SETUP.md)
- [GitHub Secrets Setup](./GITHUB_SECRETS_SETUP.md)
- [CI/CD Pipeline Overview](./CICD_PIPELINE.md)
- [GitHub Environments Documentation](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)