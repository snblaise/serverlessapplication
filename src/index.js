const { Logger } = require('@aws-lambda-powertools/logger');
const { Metrics, MetricUnits } = require('@aws-lambda-powertools/metrics');
const { Tracer } = require('@aws-lambda-powertools/tracer');

// Initialize Powertools
const logger = new Logger({
  serviceName: 'lambda-production-readiness',
  logLevel: process.env.LOG_LEVEL || 'INFO',
});

const metrics = new Metrics({
  namespace: 'LambdaProductionReadiness',
  serviceName: 'lambda-production-readiness',
});

const tracer = new Tracer({
  serviceName: 'lambda-production-readiness',
});

/**
 * Main Lambda handler function
 * Demonstrates production-ready patterns with observability
 */
exports.handler = async (event, context) => {
  // Add correlation ID for tracing
  const correlationId = context.awsRequestId;
  logger.addContext({ correlationId });

  // Start custom segment for business logic
  const segment = tracer.getSegment();
  const subsegment = segment.addNewSubsegment('business-logic');

  try {
    logger.info('Lambda function started', {
      event: JSON.stringify(event),
      context: {
        functionName: context.functionName,
        functionVersion: context.functionVersion,
        memoryLimitInMB: context.memoryLimitInMB,
        remainingTimeInMS: context.getRemainingTimeInMillis(),
      },
    });

    // Add custom metrics
    metrics.addMetric('InvocationCount', MetricUnits.Count, 1);

    // Validate input
    if (!event || typeof event !== 'object') {
      throw new Error('Invalid event object');
    }

    // Business logic simulation
    const result = await processEvent(event, correlationId);

    // Add success metrics
    metrics.addMetric('SuccessCount', MetricUnits.Count, 1);

    logger.info('Lambda function completed successfully', {
      result,
      correlationId,
    });

    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'X-Correlation-ID': correlationId,
      },
      body: JSON.stringify({
        success: true,
        data: result,
        correlationId,
      }),
    };
  } catch (error) {
    // Add error metrics
    metrics.addMetric('ErrorCount', MetricUnits.Count, 1);

    logger.error('Lambda function failed', {
      error: error.message,
      stack: error.stack,
      correlationId,
    });

    // Add error annotation to X-Ray
    subsegment.addAnnotation('error', true);
    subsegment.addMetadata('error', {
      message: error.message,
      stack: error.stack,
    });

    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json',
        'X-Correlation-ID': correlationId,
      },
      body: JSON.stringify({
        success: false,
        error: 'Internal server error',
        correlationId,
      }),
    };
  } finally {
    // Close subsegment
    subsegment.close();

    // Publish metrics
    metrics.publishStoredMetrics();
  }
};

/**
 * Process the incoming event
 * @param {Object} event - Lambda event object
 * @param {string} correlationId - Correlation ID for tracing
 * @returns {Object} Processing result
 */
async function processEvent(event, correlationId) {
  const processingSegment = tracer.getSegment().addNewSubsegment('process-event');

  try {
    logger.debug('Processing event', { event, correlationId });

    // Simulate processing time
    await new Promise(resolve => setTimeout(resolve, 100));

    // Extract and validate required fields
    const { action, data } = event;

    if (!action) {
      throw new Error('Missing required field: action');
    }

    // Process based on action type
    let result;
    switch (action) {
      case 'create':
        result = await handleCreate(data, correlationId);
        break;
      case 'update':
        result = await handleUpdate(data, correlationId);
        break;
      case 'delete':
        result = await handleDelete(data, correlationId);
        break;
      default:
        throw new Error(`Unsupported action: ${action}`);
    }

    processingSegment.addAnnotation('action', action);
    processingSegment.addMetadata('result', result);

    return result;
  } finally {
    processingSegment.close();
  }
}

/**
 * Handle create action
 */
async function handleCreate(data, correlationId) {
  logger.info('Handling create action', { data, correlationId });

  // Validate required fields for create
  if (!data || !data.name) {
    throw new Error('Missing required field for create: name');
  }

  // Simulate database operation
  await new Promise(resolve => setTimeout(resolve, 50));

  return {
    id: generateId(),
    name: data.name,
    status: 'created',
    timestamp: new Date().toISOString(),
  };
}

/**
 * Handle update action
 */
async function handleUpdate(data, correlationId) {
  logger.info('Handling update action', { data, correlationId });

  // Validate required fields for update
  if (!data || !data.id) {
    throw new Error('Missing required field for update: id');
  }

  // Simulate database operation
  await new Promise(resolve => setTimeout(resolve, 75));

  return {
    id: data.id,
    status: 'updated',
    timestamp: new Date().toISOString(),
  };
}

/**
 * Handle delete action
 */
async function handleDelete(data, correlationId) {
  logger.info('Handling delete action', { data, correlationId });

  // Validate required fields for delete
  if (!data || !data.id) {
    throw new Error('Missing required field for delete: id');
  }

  // Simulate database operation
  await new Promise(resolve => setTimeout(resolve, 25));

  return {
    id: data.id,
    status: 'deleted',
    timestamp: new Date().toISOString(),
  };
}

/**
 * Generate a unique ID
 */
function generateId() {
  return `id_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
}
