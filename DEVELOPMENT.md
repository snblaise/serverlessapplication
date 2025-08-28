# Development Guide

This guide covers local development, testing, and contribution guidelines for the Lambda application.

## Development Environment Setup

### Prerequisites
- **Node.js 22+** (LTS recommended)
- **npm** (comes with Node.js)
- **AWS CLI v2** (for local testing)
- **Git** (for version control)
- **VS Code** (recommended IDE)

### Initial Setup
```bash
# Clone repository
git clone <your-repo-url>
cd serverlessapplication

# Install dependencies
npm install

# Verify setup
npm run validate
npm test
```

### VS Code Extensions (Recommended)
```json
{
  "recommendations": [
    "ms-vscode.vscode-typescript-next",
    "dbaeumer.vscode-eslint",
    "esbenp.prettier-vscode",
    "ms-vscode.vscode-json",
    "amazonwebservices.aws-toolkit-vscode"
  ]
}
```

## Project Structure Deep Dive

### Source Code Organization
```
src/
├── index.ts              # Main Lambda handler
└── index.test.ts         # Unit tests for handler
```

### Configuration Files
```
├── package.json          # Dependencies and scripts
├── tsconfig.json         # TypeScript configuration
├── .eslintrc.js          # ESLint rules
├── jest.config.js        # Jest test configuration (in package.json)
└── .gitignore           # Git ignore patterns
```

### Infrastructure Code
```
cloudformation/
├── lambda-infrastructure.yml    # Complete AWS infrastructure
└── parameters/
    ├── staging.json            # Staging environment config
    └── production.json         # Production environment config
```

## Development Workflow

### Daily Development
```bash
# Start development
npm install                    # Install/update dependencies
npm run build                 # Compile TypeScript
npm test                      # Run tests
npm run lint                  # Check code style

# During development
npm run build:watch           # Auto-compile on changes
npm run test:watch           # Auto-test on changes
```

### Code Quality Checks
```bash
# Type checking only (no compilation)
npm run validate

# Fix linting issues automatically
npm run lint:fix

# Generate test coverage report
npm run test:coverage
```

## Lambda Function Development

### Handler Structure
The main handler in `src/index.ts` follows this pattern:

```typescript
export const handler = async (event: LambdaEvent, context: Context): Promise<APIGatewayProxyResult> => {
  // 1. Initialize observability tools
  // 2. Add correlation ID for tracing
  // 3. Validate input
  // 4. Process business logic
  // 5. Handle errors gracefully
  // 6. Return structured response
}
```

### Key Components

#### 1. AWS Lambda Powertools Integration
```typescript
import { Logger } from '@aws-lambda-powertools/logger';
import { Metrics, MetricUnits } from '@aws-lambda-powertools/metrics';
import { Tracer } from '@aws-lambda-powertools/tracer';

// Initialize with service name
const logger = new Logger({ serviceName: 'lambda-production-readiness' });
const metrics = new Metrics({ namespace: 'LambdaProductionReadiness' });
const tracer = new Tracer({ serviceName: 'lambda-production-readiness' });
```

#### 2. Error Handling Pattern
```typescript
try {
  // Business logic
  const result = await processEvent(event, correlationId);
  
  // Success metrics
  metrics.addMetric('SuccessCount', MetricUnits.Count, 1);
  
  return {
    statusCode: 200,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ success: true, data: result })
  };
} catch (error) {
  // Error metrics
  metrics.addMetric('ErrorCount', MetricUnits.Count, 1);
  
  // Structured error logging
  logger.error('Lambda function failed', { error: error.message });
  
  return {
    statusCode: 500,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ success: false, error: 'Internal server error' })
  };
}
```

#### 3. Input Validation
```typescript
interface LambdaEvent {
  action: 'create' | 'update' | 'delete';
  data: EventData;
  source?: string;
}

// Validate required fields
if (!event || typeof event !== 'object') {
  throw new Error('Invalid event object');
}

if (!event.action) {
  throw new Error('Missing required field: action');
}
```

### Adding New Functionality

#### 1. Add New Action Type
```typescript
// Update interface
interface LambdaEvent {
  action: 'create' | 'update' | 'delete' | 'list'; // Add 'list'
  data: EventData;
}

// Add handler function
async function handleList(data: EventData, correlationId: string): Promise<ProcessResult> {
  logger.info('Handling list action', { data, correlationId });
  
  // Implementation here
  
  return {
    id: 'list-result',
    status: 'listed',
    timestamp: new Date().toISOString(),
  };
}

// Update switch statement
switch (action) {
  case 'create':
    result = await handleCreate(data, correlationId);
    break;
  case 'list':
    result = await handleList(data, correlationId);
    break;
  // ... other cases
}
```

#### 2. Add New Dependencies
```bash
# Install runtime dependency
npm install aws-sdk

# Install dev dependency
npm install --save-dev @types/aws-sdk

# Update imports in code
import { DynamoDB } from 'aws-sdk';
```

## Testing Strategy

### Unit Testing with Jest

#### Test Structure
```typescript
describe('Lambda Handler', () => {
  const mockContext: Context = {
    // Mock context object
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('Create Action', () => {
    it('should handle create action successfully', async () => {
      // Arrange
      const event = { action: 'create', data: { name: 'test' } };
      
      // Act
      const result = await handler(event, mockContext);
      
      // Assert
      expect(result.statusCode).toBe(200);
      expect(JSON.parse(result.body).success).toBe(true);
    });
  });
});
```

#### Running Tests
```bash
# Run all tests
npm test

# Run tests in watch mode
npm run test:watch

# Run tests with coverage
npm run test:coverage

# Run specific test file
npm test -- index.test.ts

# Run tests matching pattern
npm test -- --testNamePattern="Create Action"
```

#### Test Coverage Requirements
- **Minimum 80%** overall coverage
- **All functions** must have tests
- **Error scenarios** must be tested
- **Edge cases** should be covered

### Integration Testing

#### Local Lambda Testing
```bash
# Install SAM CLI for local testing
pip install aws-sam-cli

# Create test event
cat > test-event.json << EOF
{
  "action": "create",
  "data": {
    "name": "test-item"
  }
}
EOF

# Test locally (if SAM template exists)
sam local invoke -e test-event.json
```

#### Manual Testing
```bash
# Deploy to staging
./deploy.sh staging

# Test deployed function
aws lambda invoke \
  --function-name lambda-function-staging \
  --payload '{"action":"create","data":{"name":"test"}}' \
  response.json

# Check response
cat response.json
```

## Code Style and Standards

### TypeScript Configuration
```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "commonjs",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "outDir": "./dist",
    "rootDir": "./src"
  }
}
```

### ESLint Rules
Key rules enforced:
- **Strict TypeScript** checking
- **No unused variables**
- **Consistent naming** conventions
- **Proper error handling**
- **Import organization**

### Code Formatting
```bash
# Check formatting
npm run lint

# Auto-fix formatting issues
npm run lint:fix
```

### Naming Conventions
- **Functions**: camelCase (`handleCreate`)
- **Interfaces**: PascalCase (`LambdaEvent`)
- **Constants**: UPPER_SNAKE_CASE (`MAX_RETRIES`)
- **Files**: kebab-case (`index.test.ts`)

## Debugging

### Local Debugging

#### VS Code Debug Configuration
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Debug Lambda Handler",
      "type": "node",
      "request": "launch",
      "program": "${workspaceFolder}/dist/index.js",
      "preLaunchTask": "npm: build",
      "env": {
        "NODE_ENV": "development"
      }
    }
  ]
}
```

#### Console Debugging
```typescript
// Add debug logging
logger.debug('Processing event', { event, context });

// Add breakpoints in VS Code
// Use console.log for quick debugging (remove before commit)
console.log('Debug:', { variable });
```

### Remote Debugging

#### CloudWatch Logs
```bash
# Tail logs in real-time
aws logs tail /aws/lambda/lambda-function-staging --follow

# Filter for errors
aws logs filter-log-events \
  --log-group-name /aws/lambda/lambda-function-staging \
  --filter-pattern "ERROR"

# Search for specific correlation ID
aws logs filter-log-events \
  --log-group-name /aws/lambda/lambda-function-staging \
  --filter-pattern "correlation-id-123"
```

#### X-Ray Tracing
```bash
# Get trace summaries
aws xray get-trace-summaries \
  --time-range-type TimeRangeByStartTime \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T23:59:59Z

# Get specific trace
aws xray batch-get-traces --trace-ids <trace-id>
```

## Performance Optimization

### Memory and Timeout Tuning
1. **Monitor CloudWatch metrics**
2. **Adjust memory** in parameter files
3. **Test with realistic payloads**
4. **Find optimal cost/performance balance**

### Cold Start Optimization
```typescript
// Initialize outside handler
const logger = new Logger({ serviceName: 'my-service' });
const metrics = new Metrics({ namespace: 'MyNamespace' });

// Minimize imports
import { Logger } from '@aws-lambda-powertools/logger';
// Don't import entire AWS SDK if only using specific services
```

### Bundle Size Optimization
```bash
# Analyze bundle size
npm run build
ls -la dist/

# Check dependencies
npm ls --depth=0

# Remove unused dependencies
npm uninstall <unused-package>
```

## Environment Variables

### Local Development
```bash
# Create .env file (don't commit)
echo "LOG_LEVEL=debug" > .env
echo "NODE_ENV=development" >> .env

# Load in code (for local testing)
import dotenv from 'dotenv';
if (process.env.NODE_ENV === 'development') {
  dotenv.config();
}
```

### Lambda Environment Variables
Set in CloudFormation template:
```yaml
Environment:
  Variables:
    ENVIRONMENT: !Ref Environment
    NODE_ENV: !Ref Environment
    LOG_LEVEL: !If [IsProduction, info, debug]
```

## Contributing Guidelines

### Branch Strategy
```bash
# Create feature branch
git checkout -b feature/new-functionality

# Make changes and commit
git add .
git commit -m "feat: add new functionality"

# Push and create PR
git push origin feature/new-functionality
```

### Commit Message Format
```
type(scope): description

feat: add new feature
fix: resolve bug in handler
docs: update README
test: add unit tests
refactor: improve error handling
```

### Pull Request Process
1. **Create feature branch** from `main`
2. **Make changes** with tests
3. **Run validation** locally
4. **Create pull request**
5. **Address review feedback**
6. **Merge after approval**

### Code Review Checklist
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] Error handling implemented
- [ ] Performance considered
- [ ] Security reviewed
- [ ] TypeScript types correct

## Troubleshooting Development Issues

### Common Issues

#### 1. TypeScript Compilation Errors
```bash
# Check TypeScript configuration
npx tsc --noEmit

# Fix common issues
npm run lint:fix
```

#### 2. Test Failures
```bash
# Run specific test
npm test -- --testNamePattern="specific test"

# Debug test
npm test -- --verbose
```

#### 3. Import/Export Issues
```typescript
// Use consistent import style
import { handler } from './index';

// Avoid default exports for better tree-shaking
export const handler = async () => {};
```

#### 4. AWS SDK Issues
```bash
# Check AWS credentials
aws sts get-caller-identity

# Update AWS SDK
npm update aws-sdk
```

### Getting Help
1. **Check documentation** in this repository
2. **Review CloudWatch logs** for runtime issues
3. **Use GitHub issues** for bugs/features
4. **Check AWS documentation** for service-specific issues

---

**Happy coding!** 🚀