// Jest setup file for global test configuration

// Set test environment variables
process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'ERROR'; // Reduce log noise during tests
process.env.AWS_REGION = 'us-east-1';

// Mock AWS SDK globally
jest.mock('aws-sdk', () => ({
  config: {
    update: jest.fn()
  },
  CloudWatch: jest.fn(() => ({
    putMetricData: jest.fn().mockReturnValue({
      promise: jest.fn().mockResolvedValue({})
    })
  })),
  XRay: jest.fn(() => ({
    captureAWS: jest.fn(),
    captureHTTPs: jest.fn()
  }))
}));

// Mock Lambda Powertools
jest.mock('@aws-lambda-powertools/logger', () => ({
  Logger: jest.fn().mockImplementation(() => ({
    info: jest.fn(),
    error: jest.fn(),
    warn: jest.fn(),
    debug: jest.fn(),
    addContext: jest.fn()
  }))
}));

jest.mock('@aws-lambda-powertools/metrics', () => ({
  Metrics: jest.fn().mockImplementation(() => ({
    addMetric: jest.fn(),
    publishStoredMetrics: jest.fn()
  })),
  MetricUnits: {
    Count: 'Count',
    Seconds: 'Seconds',
    Milliseconds: 'Milliseconds'
  }
}));

jest.mock('@aws-lambda-powertools/tracer', () => ({
  Tracer: jest.fn().mockImplementation(() => ({
    getSegment: jest.fn().mockReturnValue({
      addNewSubsegment: jest.fn().mockReturnValue({
        addAnnotation: jest.fn(),
        addMetadata: jest.fn(),
        close: jest.fn()
      })
    }),
    captureAWS: jest.fn(),
    captureHTTPs: jest.fn()
  }))
}));

// Global test utilities
global.createMockLambdaContext = (overrides = {}) => ({
  awsRequestId: 'test-request-id',
  functionName: 'test-function',
  functionVersion: '1',
  invokedFunctionArn: 'arn:aws:lambda:us-east-1:123456789012:function:test-function',
  memoryLimitInMB: 128,
  getRemainingTimeInMillis: () => 30000,
  logGroupName: '/aws/lambda/test-function',
  logStreamName: '2023/01/01/[$LATEST]test',
  identity: undefined,
  clientContext: undefined,
  ...overrides
});

// Increase timeout for integration tests
jest.setTimeout(30000);

// Console override for cleaner test output
const originalConsole = console;
global.console = {
  ...originalConsole,
  // Suppress console.log during tests unless explicitly needed
  log: process.env.VERBOSE_TESTS ? originalConsole.log : jest.fn(),
  info: process.env.VERBOSE_TESTS ? originalConsole.info : jest.fn(),
  warn: originalConsole.warn,
  error: originalConsole.error
};