import { handler } from './index';
import { Context } from 'aws-lambda';

// Mock AWS Lambda Powertools
jest.mock('@aws-lambda-powertools/logger');
jest.mock('@aws-lambda-powertools/metrics');
jest.mock('@aws-lambda-powertools/tracer');

describe('Lambda Handler', () => {
  const mockContext: Context = {
    callbackWaitsForEmptyEventLoop: false,
    functionName: 'test-function',
    functionVersion: '1',
    invokedFunctionArn: 'arn:aws:lambda:us-east-1:123456789012:function:test-function',
    memoryLimitInMB: '256',
    awsRequestId: 'test-request-id',
    logGroupName: '/aws/lambda/test-function',
    logStreamName: '2023/01/01/[$LATEST]test-stream',
    getRemainingTimeInMillis: () => 30000,
    done: jest.fn(),
    fail: jest.fn(),
    succeed: jest.fn(),
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('Create Action', () => {
    it('should handle create action successfully', async () => {
      const event = {
        action: 'create' as const,
        data: { name: 'test-item' },
        source: 'test',
      };

      const result = await handler(event, mockContext);

      expect(result.statusCode).toBe(200);
      expect(result.headers?.['Content-Type']).toBe('application/json');
      expect(result.headers?.['X-Correlation-ID']).toBe('test-request-id');

      const body = JSON.parse(result.body);
      expect(body.success).toBe(true);
      expect(body.data.status).toBe('created');
      expect(body.data.name).toBe('test-item');
      expect(body.correlationId).toBe('test-request-id');
    });

    it('should fail create action without name', async () => {
      const event = {
        action: 'create' as const,
        data: {},
        source: 'test',
      };

      const result = await handler(event, mockContext);

      expect(result.statusCode).toBe(500);
      const body = JSON.parse(result.body);
      expect(body.success).toBe(false);
      expect(body.error).toBe('Internal server error');
    });
  });

  describe('Update Action', () => {
    it('should handle update action successfully', async () => {
      const event = {
        action: 'update' as const,
        data: { id: 'test-id-123' },
        source: 'test',
      };

      const result = await handler(event, mockContext);

      expect(result.statusCode).toBe(200);
      const body = JSON.parse(result.body);
      expect(body.success).toBe(true);
      expect(body.data.status).toBe('updated');
      expect(body.data.id).toBe('test-id-123');
    });

    it('should fail update action without id', async () => {
      const event = {
        action: 'update' as const,
        data: {},
        source: 'test',
      };

      const result = await handler(event, mockContext);

      expect(result.statusCode).toBe(500);
      const body = JSON.parse(result.body);
      expect(body.success).toBe(false);
    });
  });

  describe('Delete Action', () => {
    it('should handle delete action successfully', async () => {
      const event = {
        action: 'delete' as const,
        data: { id: 'test-id-456' },
        source: 'test',
      };

      const result = await handler(event, mockContext);

      expect(result.statusCode).toBe(200);
      const body = JSON.parse(result.body);
      expect(body.success).toBe(true);
      expect(body.data.status).toBe('deleted');
      expect(body.data.id).toBe('test-id-456');
    });
  });

  describe('Error Handling', () => {
    it('should handle invalid action', async () => {
      const event = {
        action: 'invalid' as any,
        data: { test: true },
        source: 'test',
      };

      const result = await handler(event, mockContext);

      expect(result.statusCode).toBe(500);
      const body = JSON.parse(result.body);
      expect(body.success).toBe(false);
      expect(body.error).toBe('Internal server error');
    });

    it('should handle missing action', async () => {
      const event = {
        data: { test: true },
        source: 'test',
      } as any;

      const result = await handler(event, mockContext);

      expect(result.statusCode).toBe(500);
      const body = JSON.parse(result.body);
      expect(body.success).toBe(false);
    });

    it('should handle invalid event object', async () => {
      const event = null as any;

      const result = await handler(event, mockContext);

      expect(result.statusCode).toBe(500);
      const body = JSON.parse(result.body);
      expect(body.success).toBe(false);
    });
  });

  describe('Response Format', () => {
    it('should return proper response structure', async () => {
      const event = {
        action: 'create' as const,
        data: { name: 'test' },
        source: 'test',
      };

      const result = await handler(event, mockContext);

      expect(result).toHaveProperty('statusCode');
      expect(result).toHaveProperty('headers');
      expect(result).toHaveProperty('body');
      expect(result.headers).toHaveProperty('Content-Type');
      expect(result.headers).toHaveProperty('X-Correlation-ID');

      const body = JSON.parse(result.body);
      expect(body).toHaveProperty('success');
      expect(body).toHaveProperty('correlationId');
    });
  });
});