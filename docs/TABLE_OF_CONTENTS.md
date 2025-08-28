# Documentation Table of Contents

Complete navigation guide for the Serverless Lambda Application documentation.

## 📋 **Quick Navigation**

| Document | Purpose | Audience |
|----------|---------|----------|
| [README.md](../README.md) | Project overview and quick start | Everyone |
| [DEPLOYMENT.md](../DEPLOYMENT.md) | Deployment guide and troubleshooting | DevOps, Developers |
| [DEVELOPMENT.md](../DEVELOPMENT.md) | Local development and contribution | Developers |
| [ARCHITECTURE.md](../ARCHITECTURE.md) | Technical architecture and design | Architects, Senior Developers |
| [CHANGELOG.md](../CHANGELOG.md) | Version history and changes | Everyone |

## 🚀 **Getting Started Path**

### For New Users
1. **[README.md](../README.md)** - Start here for project overview
2. **[DEPLOYMENT.md](../DEPLOYMENT.md)** - Deploy your first Lambda function
3. **[DEVELOPMENT.md](../DEVELOPMENT.md)** - Set up local development

### For Developers
1. **[DEVELOPMENT.md](../DEVELOPMENT.md)** - Development environment setup
2. **[README.md](../README.md)** - Project structure and features
3. **[ARCHITECTURE.md](../ARCHITECTURE.md)** - Technical deep dive

### For DevOps/Platform Engineers
1. **[DEPLOYMENT.md](../DEPLOYMENT.md)** - Deployment strategies
2. **[ARCHITECTURE.md](../ARCHITECTURE.md)** - Infrastructure components
3. **[README.md](../README.md)** - Monitoring and observability

## 📖 **Detailed Content Guide**

### [README.md](../README.md) - Project Overview
- **Quick Start** - Get running in minutes
- **Features** - Production-ready capabilities
- **Project Structure** - File organization
- **Local Development** - Basic development workflow
- **GitHub Actions Setup** - CI/CD configuration
- **Monitoring** - Observability features

### [DEPLOYMENT.md](../DEPLOYMENT.md) - Deployment Guide
- **Quick Deployment** - Fastest path to production
- **Deployment Methods** - GitHub Actions vs Local vs Manual
- **Environment Configuration** - Staging vs Production settings
- **Pipeline Details** - CI/CD workflow explanation
- **Troubleshooting** - Common issues and solutions
- **Rollback Procedures** - Recovery strategies
- **Monitoring Deployments** - Validation and health checks

### [DEVELOPMENT.md](../DEVELOPMENT.md) - Development Guide
- **Environment Setup** - Prerequisites and tools
- **Project Structure** - Code organization deep dive
- **Development Workflow** - Daily development process
- **Lambda Function Development** - Handler patterns and best practices
- **Testing Strategy** - Unit testing and integration testing
- **Code Style** - Standards and conventions
- **Debugging** - Local and remote debugging techniques
- **Contributing** - Pull request process and guidelines

### [ARCHITECTURE.md](../ARCHITECTURE.md) - Technical Architecture
- **System Overview** - High-level architecture diagrams
- **Infrastructure Components** - AWS resources and configuration
- **Application Architecture** - Lambda handler design patterns
- **Security Architecture** - Authentication, authorization, and data security
- **Performance Architecture** - Optimization strategies and scalability
- **Deployment Architecture** - Multi-environment and pipeline design
- **Monitoring Architecture** - Observability strategy
- **Cost Architecture** - Cost optimization and monitoring

### [CHANGELOG.md](../CHANGELOG.md) - Version History
- **Release Notes** - What's new in each version
- **Breaking Changes** - Important migration notes
- **Bug Fixes** - Resolved issues
- **Feature Additions** - New capabilities

## 🎯 **Use Case Scenarios**

### "I want to deploy this quickly"
1. [README.md - Quick Start](../README.md#quick-start)
2. [DEPLOYMENT.md - Quick Deployment](../DEPLOYMENT.md#quick-deployment)

### "I want to understand the architecture"
1. [ARCHITECTURE.md - System Overview](../ARCHITECTURE.md#system-overview)
2. [ARCHITECTURE.md - Infrastructure Components](../ARCHITECTURE.md#infrastructure-components)

### "I want to contribute code"
1. [DEVELOPMENT.md - Environment Setup](../DEVELOPMENT.md#development-environment-setup)
2. [DEVELOPMENT.md - Contributing Guidelines](../DEVELOPMENT.md#contributing-guidelines)

### "I'm having deployment issues"
1. [DEPLOYMENT.md - Troubleshooting](../DEPLOYMENT.md#troubleshooting)
2. [DEPLOYMENT.md - Rollback Procedures](../DEPLOYMENT.md#rollback-procedures)

### "I want to optimize performance"
1. [ARCHITECTURE.md - Performance Architecture](../ARCHITECTURE.md#performance-architecture)
2. [DEVELOPMENT.md - Performance Optimization](../DEVELOPMENT.md#performance-optimization)

### "I need to set up monitoring"
1. [README.md - Monitoring & Troubleshooting](../README.md#monitoring--troubleshooting)
2. [ARCHITECTURE.md - Monitoring Architecture](../ARCHITECTURE.md#monitoring-and-observability-architecture)

## 🔍 **Topic Index**

### AWS Services
- **Lambda**: [README](../README.md), [ARCHITECTURE](../ARCHITECTURE.md#core-lambda-infrastructure)
- **CloudFormation**: [DEPLOYMENT](../DEPLOYMENT.md#manual-cloudformation), [ARCHITECTURE](../ARCHITECTURE.md#infrastructure-components)
- **IAM**: [ARCHITECTURE](../ARCHITECTURE.md#security-architecture)
- **CloudWatch**: [README](../README.md#monitoring--troubleshooting), [ARCHITECTURE](../ARCHITECTURE.md#monitoring-infrastructure)
- **X-Ray**: [DEVELOPMENT](../DEVELOPMENT.md#debugging), [ARCHITECTURE](../ARCHITECTURE.md#monitoring-infrastructure)
- **S3**: [ARCHITECTURE](../ARCHITECTURE.md#storage-infrastructure)
- **SQS**: [ARCHITECTURE](../ARCHITECTURE.md#core-lambda-infrastructure)

### Development Topics
- **TypeScript**: [DEVELOPMENT](../DEVELOPMENT.md#lambda-function-development)
- **Testing**: [DEVELOPMENT](../DEVELOPMENT.md#testing-strategy)
- **Debugging**: [DEVELOPMENT](../DEVELOPMENT.md#debugging)
- **Code Style**: [DEVELOPMENT](../DEVELOPMENT.md#code-style-and-standards)
- **Local Development**: [DEVELOPMENT](../DEVELOPMENT.md#development-workflow)

### Deployment Topics
- **GitHub Actions**: [DEPLOYMENT](../DEPLOYMENT.md#github-actions-recommended)
- **Local Deployment**: [DEPLOYMENT](../DEPLOYMENT.md#local-deployment)
- **Environment Configuration**: [DEPLOYMENT](../DEPLOYMENT.md#environment-configuration)
- **Rollback**: [DEPLOYMENT](../DEPLOYMENT.md#rollback-procedures)
- **Troubleshooting**: [DEPLOYMENT](../DEPLOYMENT.md#troubleshooting)

### Architecture Topics
- **Security**: [ARCHITECTURE](../ARCHITECTURE.md#security-architecture)
- **Performance**: [ARCHITECTURE](../ARCHITECTURE.md#performance-architecture)
- **Scalability**: [ARCHITECTURE](../ARCHITECTURE.md#scalability-design)
- **Cost Optimization**: [ARCHITECTURE](../ARCHITECTURE.md#cost-architecture)
- **Multi-Environment**: [ARCHITECTURE](../ARCHITECTURE.md#multi-environment-strategy)

## 📱 **Quick Reference Cards**

### Essential Commands
```bash
# Setup
./setup-oidc.sh
npm install

# Development
npm test
npm run build
npm run lint

# Deployment
./deploy.sh staging
./deploy.sh production
git push origin main
```

### Key Files
```
src/index.ts              # Main Lambda handler
cloudformation/           # Infrastructure templates
.github/workflows/        # CI/CD pipeline
package.json             # Dependencies and scripts
```

### Important URLs
- **AWS Console**: https://console.aws.amazon.com/lambda/
- **GitHub Actions**: https://github.com/{repo}/actions
- **CloudWatch**: https://console.aws.amazon.com/cloudwatch/

---

**Need help finding something?** Use your browser's search function (Ctrl/Cmd + F) to search across all documentation files.