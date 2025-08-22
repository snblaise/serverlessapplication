const { handler } = require('./index');

// Mock AWS Lambda Powertools
jest.mock('@aws-lambda-powertools/logger');
jest.mock('@aws-lambda-powertools/metrics');
jest.mock('@aws-lambda-powertools/tracer');

// Mock context object
const createMockContext = (overrides = {}) => ({
  awsRequestId: 'test-request-id-123',
  functionName: 'test-function',
  functionVersion: '1',
  memoryLimitInMB: 128,
  getRemainingTimeInMillis: () => 30000,
  ...overrides,
});

describe('Lambda Handler', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('Successful Operations', () => {
    test('should handle create action successfully', async () => {
      const event = {
        action: 'create',
        data: {
          name: 'test-item',
        },
      };

      const context = createMockContext();
      const result = await handler(event, context);

      expect(result.statusCode).toBe(200);
      expect(JSON.parse(result.body).success).toBe(true);
      expect(JSON.parse(result.body).data.name).toBe('test-item');
      expect(JSON.parse(result.body).data.status).toBe('created');
      expect(result.headers['X-Correlation-ID']).toBe(context.awsRequestId);
    });

    test('should handle update action successfully', async () => {
      const event = {
        action: 'update',
        data: {
          id: 'test-id-123',
        },
      };

      const context = createMockContext();
      const result = await handler(event, context);

      expect(result.statusCode).toBe(200);
      expect(JSON.parse(result.body).success).toBe(true);
      expect(JSON.parse(result.body).data.id).toBe('test-id-123');
      expect(JSON.parse(result.body).data.status).toBe('updated');
    });

    test('should handle delete action successfully', async () => {
      const event = {
        action: 'delete',
        data: {
          id: 'test-id-456',
        },
      };

      const context = createMockContext();
      const result = await handler(event, context);

      expect(result.statusCode).toBe(200);
      expect(JSON.parse(result.body).success).toBe(true);
      expect(JSON.parse(result.body).data.id).toBe('test-id-456');
      expect(JSON.parse(result.body).data.status).toBe('deleted');
    });
  });

  describe('Error Handling', () => {
    test('should handle invalid event object', async () => {
      const event = null;
      const context = createMockContext();

      const result = await handler(event, context);

      expect(result.statusCode).toBe(500);
      expect(JSON.parse(result.body).success).toBe(false);
      expect(JSON.parse(result.body).error).toBe('Internal server error');
    });

    test('should handle missing action field', async () => {
      const event = {
        data: { name: 'test' },
      };
      const context = createMockContext();

      const result = await handler(event, context);

      expect(result.statusCode).toBe(500);
      expect(JSON.parse(result.body).success).toBe(false);
    });

    test('should handle unsupported action', async () => {
      const event = {
        action: 'unsupported',
        data: {},
      };
      const context = createMockContext();

      const result = await handler(event, context);

      expect(result.statusCode).toBe(500);
      expect(JSON.parse(result.body).success).toBe(false);
    });

    test('should handle missing required fields for create', async () => {
      const event = {
        action: 'create',
        data: {},
      };
      const context = createMockContext();

      const result = await handler(event, context);

      expect(result.statusCode).toBe(500);
      expect(JSON.parse(result.body).success).toBe(false);
    });

    test('should handle missing required fields for update', async () => {
      const event = {
        action: 'update',
        data: {},
      };
      const context = createMockContext();

      const result = await handler(event, context);

      expect(result.statusCode).toBe(500);
      expect(JSON.parse(result.body).success).toBe(false);
    });

    test('should handle missing required fields for delete', async () => {
      const event = {
        action: 'delete',
        data: {},
      };
      const context = createMockContext();

      const result = await handler(event, context);

      expect(result.statusCode).toBe(500);
      expect(JSON.parse(result.body).success).toBe(false);
    });
  });

  describe('Response Format', () => {
    test('should return proper response structure for success', async () => {
      const event = {
        action: 'create',
        data: { name: 'test' },
      };
      const context = createMockContext();

      const result = await handler(event, context);

      expect(result).toHaveProperty('statusCode');
      expect(result).toHaveProperty('headers');
      expect(result).toHaveProperty('body');
      expect(result.headers).toHaveProperty('Content-Type', 'application/json');
      expect(result.headers).toHaveProperty('X-Correlation-ID');

      const body = JSON.parse(result.body);
      expect(body).toHaveProperty('success');
      expect(body).toHaveProperty('data');
      expect(body).toHaveProperty('correlationId');
    });

    test('should return proper response structure for error', async () => {
      const event = null;
      const context = createMockContext();

      const result = await handler(event, context);

      expect(result).toHaveProperty('statusCode', 500);
      expect(result).toHaveProperty('headers');
      expect(result).toHaveProperty('body');
      expect(result.headers).toHaveProperty('Content-Type', 'application/json');
      expect(result.headers).toHaveProperty('X-Correlation-ID');

      const body = JSON.parse(result.body);
      expect(body).toHaveProperty('success', false);
      expect(body).toHaveProperty('error');
      expect(body).toHaveProperty('correlationId');
    });
  });

  describe('Context Handling', () => {
    test('should use correlation ID from context', async () => {
      const event = {
        action: 'create',
        data: { name: 'test' },
      };
      const context = createMockContext({
        awsRequestId: 'custom-correlation-id',
      });

      const result = await handler(event, context);

      expect(result.headers['X-Correlation-ID']).toBe('custom-correlation-id');
      expect(JSON.parse(result.body).correlationId).toBe('custom-correlation-id');
    });

    test('should handle different function versions', async () => {
      const event = {
        action: 'create',
        data: { name: 'test' },
      };
      const context = createMockContext({
        functionVersion: '$LATEST',
      });

      const result = await handler(event, context);

      expect(result.statusCode).toBe(200);
    });
  });
});
