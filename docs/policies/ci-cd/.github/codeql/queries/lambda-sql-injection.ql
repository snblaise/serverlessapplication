/**
 * @name Lambda function vulnerable to SQL injection
 * @description Detects potential SQL injection vulnerabilities in Lambda functions
 * @kind path-problem
 * @problem.severity error
 * @security-severity 9.0
 * @precision high
 * @id lambda/sql-injection
 * @tags security
 *       lambda
 *       sql-injection
 */

import javascript

/**
 * A source of user input in Lambda context
 */
class LambdaUserInput extends DataFlow::SourceNode {
  LambdaUserInput() {
    // Lambda event parameters
    this = DataFlow::parameterNode(any(Function f).getParameter(0)).getAPropertyRead("body") or
    this = DataFlow::parameterNode(any(Function f).getParameter(0)).getAPropertyRead("queryStringParameters") or
    this = DataFlow::parameterNode(any(Function f).getParameter(0)).getAPropertyRead("pathParameters") or
    this = DataFlow::parameterNode(any(Function f).getParameter(0)).getAPropertyRead("headers") or
    
    // API Gateway proxy integration
    this = DataFlow::parameterNode(any(Function f).getParameter(0)).getAPropertyRead("requestContext").getAPropertyRead("identity")
  }
}

/**
 * A SQL query construction that might be vulnerable
 */
class SqlQuery extends DataFlow::SinkNode {
  SqlQuery() {
    // Direct string concatenation with SQL keywords
    exists(AddExpr add |
      add.getAnOperand().getStringValue().regexpMatch("(?i).*(SELECT|INSERT|UPDATE|DELETE|DROP|CREATE).*") and
      this = DataFlow::valueNode(add)
    ) or
    
    // Template literals with SQL
    exists(TemplateLiteral tl |
      tl.getAnElement().getStringValue().regexpMatch("(?i).*(SELECT|INSERT|UPDATE|DELETE|DROP|CREATE).*") and
      this = DataFlow::valueNode(tl)
    ) or
    
    // Database query methods
    exists(MethodCallExpr call |
      call.getMethodName() in ["query", "execute", "run"] and
      this = DataFlow::valueNode(call.getArgument(0))
    )
  }
}

from LambdaUserInput source, SqlQuery sink
where DataFlow::hasFlow(source, sink)
select sink, "SQL query uses unsanitized user input from $@", source, "Lambda event"