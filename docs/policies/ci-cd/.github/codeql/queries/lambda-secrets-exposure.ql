/**
 * @name Lambda function exposes secrets in logs
 * @description Detects potential secret exposure in Lambda function logging
 * @kind path-problem
 * @problem.severity error
 * @security-severity 8.5
 * @precision high
 * @id lambda/secrets-in-logs
 * @tags security
 *       lambda
 *       secrets
 */

import javascript

/**
 * A call to a logging function that might expose secrets
 */
class LoggingCall extends CallExpr {
  LoggingCall() {
    this.getCalleeName() in ["log", "info", "warn", "error", "debug", "trace"] or
    this.getCallee().(PropAccess).getPropertyName() in ["log", "info", "warn", "error", "debug", "trace"]
  }
}

/**
 * An expression that might contain secrets
 */
class PotentialSecret extends Expr {
  PotentialSecret() {
    // Environment variables that might contain secrets
    this.(PropAccess).getBase().(PropAccess).getPropertyName() = "env" and
    this.(PropAccess).getPropertyName().toLowerCase().matches("%password%") or
    this.(PropAccess).getPropertyName().toLowerCase().matches("%secret%") or
    this.(PropAccess).getPropertyName().toLowerCase().matches("%key%") or
    this.(PropAccess).getPropertyName().toLowerCase().matches("%token%") or
    
    // Variables with secret-like names
    this.(VarAccess).getName().toLowerCase().matches("%password%") or
    this.(VarAccess).getName().toLowerCase().matches("%secret%") or
    this.(VarAccess).getName().toLowerCase().matches("%apikey%") or
    this.(VarAccess).getName().toLowerCase().matches("%token%")
  }
}

from LoggingCall log, PotentialSecret secret
where secret = log.getAnArgument().getAChildExpr*()
select log, "Logging call may expose secret: $@", secret, secret.toString()