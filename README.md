# Serverless Lambda Application

A production-ready TypeScript Lambda function with automated CI/CD deployment.

## Quick Start

### Prerequisites
- AWS CLI configured with appropriate permissions
- Node.js 22+ installed
- GitHub repository with admin access

### Deploy

1. **Install dependencies**:
   ```bash
   npm install
   ```

2. **Build and test locally**:
   ```bash
   npm run build
   npm test
   ```

3. **One-time setup** (create GitHub OIDC provider):
   ```bash
   ./setup-oidc.sh
   ```

4. **Deploy to AWS**:
   ```bash
   # Deploy to staging
   ./deploy.sh staging
   
   # Or deploy to production
   ./deploy.sh production
   
   # Or push to GitHub for automatic deployment
   git push origin main
   ```

### GitHub Actions Setup

The repository includes a complete CI/CD pipeline that:
- Runs tests and linting
- Builds the TypeScript code
- Deploys infrastructure via CloudFormation
- Updates Lambda function code
- Monitors deployment health

### Architecture

- **Runtime**: Node.js 22.x
- **Language**: TypeScript
- **Observability**: AWS Lambda Powertools
- **Infrastructure**: CloudFormation
- **CI/CD**: GitHub Actions with OIDC

### Local Development

```bash
# Install dependencies
npm install

# Run tests
npm test

# Build TypeScript
npm run build

# Lint code
npm run lint
```

## Project Structure

```
├── src/
│   ├── index.ts          # Lambda handler
│   └── index.test.ts     # Unit tests
├── cloudformation/
│   ├── lambda-infrastructure.yml  # AWS resources
│   └── parameters/       # Environment configs
├── .github/workflows/    # CI/CD pipeline
├── setup-oidc.sh        # One-time OIDC setup
├── deploy.sh            # Deployment script
└── package.json         # Dependencies and scripts
```