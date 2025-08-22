#!/bin/bash
set -euo pipefail

# Lambda package validation script
# Validates package structure, dependencies, and security requirements

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default values
PACKAGE_FILE="lambda-function.zip"
VALIDATION_MODE="full"  # full, basic, security
TEMP_DIR=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    if [ "${DEBUG:-false}" = "true" ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Validate Lambda deployment package

OPTIONS:
    -f, --file FILE         Lambda package file (default: lambda-function.zip)
    -m, --mode MODE         Validation mode: full, basic, security (default: full)
    -h, --help             Show this help message

VALIDATION MODES:
    basic                  Basic structure and size validation
    security              Security-focused validation (dependencies, signatures)
    full                  Complete validation (basic + security + runtime)

EXAMPLES:
    $0 -f my-function.zip
    $0 -m security -f lambda-function-signed.zip

ENVIRONMENT VARIABLES:
    DEBUG                  Enable debug logging (true/false)
EOF
}

# Function to parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--file)
                PACKAGE_FILE="$2"
                shift 2
                ;;
            -m|--mode)
                VALIDATION_MODE="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Validate mode
    case "$VALIDATION_MODE" in
        basic|security|full)
            ;;
        *)
            log_error "Invalid validation mode: $VALIDATION_MODE"
            exit 1
            ;;
    esac
}

# Function to setup temporary directory
setup_temp_dir() {
    TEMP_DIR=$(mktemp -d)
    log_debug "Created temporary directory: $TEMP_DIR"
}

# Function to cleanup temporary directory
cleanup_temp_dir() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
        log_debug "Cleaned up temporary directory: $TEMP_DIR"
    fi
}

# Function to validate package file exists
validate_package_exists() {
    log_info "Validating package file exists..."
    
    if [ ! -f "$PROJECT_ROOT/$PACKAGE_FILE" ]; then
        log_error "Package file not found: $PACKAGE_FILE"
        exit 1
    fi
    
    log_info "Package file found: $PACKAGE_FILE"
}

# Function to validate package size
validate_package_size() {
    log_info "Validating package size..."
    
    cd "$PROJECT_ROOT"
    
    PACKAGE_SIZE=$(stat -f%z "$PACKAGE_FILE" 2>/dev/null || stat -c%s "$PACKAGE_FILE" 2>/dev/null)
    PACKAGE_SIZE_MB=$((PACKAGE_SIZE / 1024 / 1024))
    
    log_info "Package size: ${PACKAGE_SIZE_MB}MB (${PACKAGE_SIZE} bytes)"
    
    # Check Lambda limits
    if [ "$PACKAGE_SIZE" -gt 52428800 ]; then  # 50MB
        log_error "Package size exceeds Lambda limit (50MB)"
        return 1
    fi
    
    if [ "$PACKAGE_SIZE" -gt 10485760 ]; then  # 10MB
        log_warn "Package size is large (${PACKAGE_SIZE_MB}MB). Consider optimization."
    fi
    
    if [ "$PACKAGE_SIZE" -lt 1024 ]; then  # 1KB
        log_warn "Package size is very small (${PACKAGE_SIZE} bytes). May be incomplete."
    fi
    
    log_info "Package size validation passed"
}

# Function to validate ZIP integrity
validate_zip_integrity() {
    log_info "Validating ZIP integrity..."
    
    cd "$PROJECT_ROOT"
    
    if ! unzip -t "$PACKAGE_FILE" > /dev/null 2>&1; then
        log_error "ZIP file is corrupted or invalid"
        return 1
    fi
    
    log_info "ZIP integrity validation passed"
}

# Function to extract and validate package structure
validate_package_structure() {
    log_info "Validating package structure..."
    
    cd "$PROJECT_ROOT"
    
    # Extract package to temp directory
    unzip -q "$PACKAGE_FILE" -d "$TEMP_DIR"
    
    cd "$TEMP_DIR"
    
    # Check for required files
    local errors=0
    
    if [ ! -f "index.js" ]; then
        log_error "Main handler file (index.js) not found"
        errors=$((errors + 1))
    fi
    
    if [ ! -f "package.json" ]; then
        log_error "package.json not found"
        errors=$((errors + 1))
    fi
    
    if [ ! -d "node_modules" ]; then
        log_error "node_modules directory not found"
        errors=$((errors + 1))
    fi
    
    # Validate Node.js syntax if handler exists
    if [ -f "index.js" ]; then
        if ! node -c "index.js" 2>/dev/null; then
            log_error "Syntax error in main handler file"
            errors=$((errors + 1))
        fi
    fi
    
    # Check for common issues
    if [ -f ".env" ]; then
        log_warn "Environment file (.env) found in package - may contain secrets"
    fi
    
    if [ -d ".git" ]; then
        log_warn "Git directory found in package - should be excluded"
    fi
    
    # Check for test files (should not be in production package)
    if find . -name "*.test.js" -o -name "*.spec.js" | grep -q .; then
        log_warn "Test files found in package - should be excluded from production"
    fi
    
    if [ $errors -gt 0 ]; then
        log_error "Package structure validation failed with $errors errors"
        return 1
    fi
    
    log_info "Package structure validation passed"
}

# Function to validate dependencies
validate_dependencies() {
    log_info "Validating dependencies..."
    
    cd "$TEMP_DIR"
    
    # Check if package.json is valid JSON
    if ! jq . package.json > /dev/null 2>&1; then
        log_error "package.json is not valid JSON"
        return 1
    fi
    
    # Check for required AWS Lambda Powertools
    if [ ! -d "node_modules/@aws-lambda-powertools" ]; then
        log_warn "AWS Lambda Powertools not found - recommended for production"
    fi
    
    # Check for common security issues in dependencies
    if [ -d "node_modules" ]; then
        # Look for known problematic packages
        local problematic_packages=("lodash" "moment" "request")
        
        for package in "${problematic_packages[@]}"; do
            if [ -d "node_modules/$package" ]; then
                log_warn "Found potentially problematic package: $package (consider alternatives)"
            fi
        done
        
        # Check for excessive number of dependencies
        local dep_count=$(find node_modules -maxdepth 1 -type d | wc -l)
        if [ "$dep_count" -gt 100 ]; then
            log_warn "Large number of dependencies ($dep_count) - consider optimization"
        fi
    fi
    
    log_info "Dependencies validation completed"
}

# Function to validate security aspects
validate_security() {
    log_info "Validating security aspects..."
    
    cd "$TEMP_DIR"
    
    local security_issues=0
    
    # Check for hardcoded secrets patterns
    log_debug "Scanning for hardcoded secrets..."
    
    # Common secret patterns
    local secret_patterns=(
        "password\s*=\s*['\"][^'\"]+['\"]"
        "api[_-]?key\s*=\s*['\"][^'\"]+['\"]"
        "secret\s*=\s*['\"][^'\"]+['\"]"
        "token\s*=\s*['\"][^'\"]+['\"]"
        "AKIA[0-9A-Z]{16}"  # AWS Access Key
        "-----BEGIN.*PRIVATE KEY-----"
    )
    
    for pattern in "${secret_patterns[@]}"; do
        if grep -r -i -E "$pattern" . --include="*.js" --include="*.json" 2>/dev/null | grep -v node_modules; then
            log_warn "Potential hardcoded secret found (pattern: ${pattern:0:20}...)"
            security_issues=$((security_issues + 1))
        fi
    done
    
    # Check for dangerous functions
    log_debug "Scanning for dangerous functions..."
    
    local dangerous_functions=(
        "eval\s*\("
        "Function\s*\("
        "setTimeout\s*\(\s*['\"]"
        "setInterval\s*\(\s*['\"]"
        "exec\s*\("
        "spawn\s*\("
    )
    
    for func in "${dangerous_functions[@]}"; do
        if grep -r -E "$func" . --include="*.js" 2>/dev/null | grep -v node_modules | grep -v test; then
            log_warn "Potentially dangerous function found: ${func}"
            security_issues=$((security_issues + 1))
        fi
    done
    
    # Check file permissions
    log_debug "Checking file permissions..."
    
    if find . -type f -perm -002 2>/dev/null | grep -q .; then
        log_warn "World-writable files found in package"
        security_issues=$((security_issues + 1))
    fi
    
    if [ $security_issues -gt 0 ]; then
        log_warn "Security validation completed with $security_issues potential issues"
    else
        log_info "Security validation passed"
    fi
}

# Function to validate runtime requirements
validate_runtime() {
    log_info "Validating runtime requirements..."
    
    cd "$TEMP_DIR"
    
    # Check Node.js version compatibility
    if [ -f "package.json" ]; then
        local node_version=$(jq -r '.engines.node // "unknown"' package.json)
        if [ "$node_version" != "unknown" ] && [ "$node_version" != "null" ]; then
            log_info "Required Node.js version: $node_version"
            
            # Basic version check (simplified)
            if echo "$node_version" | grep -q ">=18"; then
                log_info "Node.js version requirement compatible with Lambda"
            elif echo "$node_version" | grep -q "<18"; then
                log_warn "Node.js version requirement may be outdated for Lambda"
            fi
        fi
    fi
    
    # Check for Lambda-specific configurations
    if [ -f "package.json" ]; then
        local main_file=$(jq -r '.main // "index.js"' package.json)
        if [ "$main_file" != "index.js" ] && [ ! -f "$main_file" ]; then
            log_error "Main file specified in package.json not found: $main_file"
            return 1
        fi
    fi
    
    # Check for common Lambda patterns
    if [ -f "index.js" ]; then
        if ! grep -q "exports\.handler" index.js; then
            log_warn "Standard Lambda handler export pattern not found"
        fi
        
        if grep -q "async.*handler" index.js; then
            log_info "Async handler pattern detected"
        fi
    fi
    
    log_info "Runtime validation completed"
}

# Function to generate validation report
generate_validation_report() {
    log_info "Generating validation report..."
    
    cd "$PROJECT_ROOT"
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local package_size=$(stat -f%z "$PACKAGE_FILE" 2>/dev/null || stat -c%s "$PACKAGE_FILE" 2>/dev/null)
    
    cat > "validation-report.json" << EOF
{
  "packageFile": "$PACKAGE_FILE",
  "validationMode": "$VALIDATION_MODE",
  "timestamp": "$timestamp",
  "packageSize": $package_size,
  "validationResults": {
    "packageExists": true,
    "sizeValid": $([ $package_size -le 52428800 ] && echo "true" || echo "false"),
    "zipIntegrity": "passed",
    "structureValid": "passed",
    "dependenciesChecked": true,
    "securityScanned": $([ "$VALIDATION_MODE" = "security" ] || [ "$VALIDATION_MODE" = "full" ] && echo "true" || echo "false"),
    "runtimeValidated": $([ "$VALIDATION_MODE" = "full" ] && echo "true" || echo "false")
  },
  "gitCommit": "$(git rev-parse HEAD 2>/dev/null || echo 'unknown')",
  "gitBranch": "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')"
}
EOF
    
    log_info "Validation report generated: validation-report.json"
}

# Main execution
main() {
    log_info "Starting Lambda package validation..."
    
    parse_args "$@"
    setup_temp_dir
    
    # Basic validations (always performed)
    validate_package_exists
    validate_package_size
    validate_zip_integrity
    validate_package_structure
    validate_dependencies
    
    # Mode-specific validations
    case "$VALIDATION_MODE" in
        security|full)
            validate_security
            ;;
    esac
    
    case "$VALIDATION_MODE" in
        full)
            validate_runtime
            ;;
    esac
    
    generate_validation_report
    
    log_info "Lambda package validation completed successfully!"
    log_info "Validation mode: $VALIDATION_MODE"
    log_info "Report: validation-report.json"
}

# Trap for cleanup on exit
trap cleanup_temp_dir EXIT

# Execute main function
main "$@"