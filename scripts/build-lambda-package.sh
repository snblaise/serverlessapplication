#!/bin/bash
set -euo pipefail

# Lambda package build script with production optimizations
# This script creates an optimized Lambda deployment package

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PROJECT_ROOT}/dist"
PACKAGE_NAME="lambda-function.zip"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check Node.js version
    if ! command -v node &> /dev/null; then
        log_error "Node.js is not installed"
        exit 1
    fi
    
    NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_VERSION" -lt 18 ]; then
        log_error "Node.js version 18 or higher is required"
        exit 1
    fi
    
    # Check npm
    if ! command -v npm &> /dev/null; then
        log_error "npm is not installed"
        exit 1
    fi
    
    # Check zip utility
    if ! command -v zip &> /dev/null; then
        log_error "zip utility is not installed"
        exit 1
    fi
    
    log_info "Prerequisites check passed"
}

# Function to clean build directory
clean_build_dir() {
    log_info "Cleaning build directory..."
    
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
    fi
    
    mkdir -p "$BUILD_DIR"
    log_info "Build directory cleaned"
}

# Function to install production dependencies
install_dependencies() {
    log_info "Installing production dependencies..."
    
    cd "$PROJECT_ROOT"
    
    # Clean install with only production dependencies
    npm ci --only=production --no-audit --no-fund
    
    # Verify critical dependencies are installed
    if [ ! -d "node_modules/@aws-lambda-powertools" ]; then
        log_error "AWS Lambda Powertools not found in production dependencies"
        exit 1
    fi
    
    log_info "Production dependencies installed"
}

# Function to copy source files
copy_source_files() {
    log_info "Copying source files..."
    
    # Copy main source files
    cp -r "$PROJECT_ROOT/src"/* "$BUILD_DIR/"
    
    # Copy package.json (needed for runtime)
    cp "$PROJECT_ROOT/package.json" "$BUILD_DIR/"
    
    # Copy production node_modules
    cp -r "$PROJECT_ROOT/node_modules" "$BUILD_DIR/"
    
    log_info "Source files copied"
}

# Function to optimize package
optimize_package() {
    log_info "Optimizing package..."
    
    cd "$BUILD_DIR"
    
    # Remove unnecessary files from node_modules
    find node_modules -name "*.md" -type f -delete
    find node_modules -name "*.txt" -type f -delete
    find node_modules -name "LICENSE*" -type f -delete
    find node_modules -name "CHANGELOG*" -type f -delete
    find node_modules -name "*.map" -type f -delete
    find node_modules -name "*.ts" -type f -delete
    find node_modules -name "*.d.ts" -type f -delete
    
    # Remove test and example directories
    find node_modules -name "test" -type d -exec rm -rf {} + 2>/dev/null || true
    find node_modules -name "tests" -type d -exec rm -rf {} + 2>/dev/null || true
    find node_modules -name "example" -type d -exec rm -rf {} + 2>/dev/null || true
    find node_modules -name "examples" -type d -exec rm -rf {} + 2>/dev/null || true
    find node_modules -name "docs" -type d -exec rm -rf {} + 2>/dev/null || true
    find node_modules -name ".github" -type d -exec rm -rf {} + 2>/dev/null || true
    
    # Remove development-only files
    rm -f package-lock.json
    rm -f yarn.lock
    rm -f .npmrc
    
    log_info "Package optimization completed"
}

# Function to validate package structure
validate_package() {
    log_info "Validating package structure..."
    
    cd "$BUILD_DIR"
    
    # Check for required files
    if [ ! -f "index.js" ]; then
        log_error "Main handler file (index.js) not found"
        exit 1
    fi
    
    if [ ! -f "package.json" ]; then
        log_error "package.json not found"
        exit 1
    fi
    
    if [ ! -d "node_modules" ]; then
        log_error "node_modules directory not found"
        exit 1
    fi
    
    # Check for AWS Lambda Powertools
    if [ ! -d "node_modules/@aws-lambda-powertools" ]; then
        log_error "AWS Lambda Powertools not found in package"
        exit 1
    fi
    
    # Validate Node.js syntax
    if ! node -c index.js; then
        log_error "Syntax error in main handler file"
        exit 1
    fi
    
    log_info "Package structure validation passed"
}

# Function to create ZIP package
create_zip_package() {
    log_info "Creating ZIP package..."
    
    cd "$BUILD_DIR"
    
    # Create ZIP with optimal compression
    zip -r9 "../$PACKAGE_NAME" . -x "*.git*" "*.DS_Store*" "*Thumbs.db*"
    
    # Move back to project root
    cd "$PROJECT_ROOT"
    
    # Verify ZIP was created
    if [ ! -f "$PACKAGE_NAME" ]; then
        log_error "Failed to create ZIP package"
        exit 1
    fi
    
    # Get package size
    PACKAGE_SIZE=$(stat -f%z "$PACKAGE_NAME" 2>/dev/null || stat -c%s "$PACKAGE_NAME" 2>/dev/null)
    PACKAGE_SIZE_MB=$((PACKAGE_SIZE / 1024 / 1024))
    
    log_info "ZIP package created: $PACKAGE_NAME (${PACKAGE_SIZE_MB}MB)"
    
    # Check Lambda size limits
    if [ "$PACKAGE_SIZE" -gt 52428800 ]; then  # 50MB
        log_error "Package size (${PACKAGE_SIZE_MB}MB) exceeds Lambda limit (50MB)"
        exit 1
    fi
    
    if [ "$PACKAGE_SIZE" -gt 10485760 ]; then  # 10MB
        log_warn "Package size (${PACKAGE_SIZE_MB}MB) is large. Consider optimization."
    fi
}

# Function to generate package manifest
generate_manifest() {
    log_info "Generating package manifest..."
    
    cd "$PROJECT_ROOT"
    
    # Create manifest with package information
    cat > "package-manifest.json" << EOF
{
  "packageName": "$PACKAGE_NAME",
  "buildTimestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "packageSize": $(stat -f%z "$PACKAGE_NAME" 2>/dev/null || stat -c%s "$PACKAGE_NAME" 2>/dev/null),
  "nodeVersion": "$(node --version)",
  "npmVersion": "$(npm --version)",
  "gitCommit": "$(git rev-parse HEAD 2>/dev/null || echo 'unknown')",
  "gitBranch": "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')",
  "dependencies": $(cd "$BUILD_DIR" && npm list --json --prod 2>/dev/null | jq '.dependencies // {}'),
  "files": [
$(cd "$BUILD_DIR" && find . -type f | sed 's/^/    "/' | sed 's/$/"/' | paste -sd ',' -)
  ]
}
EOF
    
    log_info "Package manifest generated: package-manifest.json"
}

# Function to verify package integrity
verify_package_integrity() {
    log_info "Verifying package integrity..."
    
    cd "$PROJECT_ROOT"
    
    # Test ZIP integrity
    if ! unzip -t "$PACKAGE_NAME" > /dev/null 2>&1; then
        log_error "ZIP package integrity check failed"
        exit 1
    fi
    
    # Generate checksums
    if command -v sha256sum &> /dev/null; then
        SHA256=$(sha256sum "$PACKAGE_NAME" | cut -d' ' -f1)
    elif command -v shasum &> /dev/null; then
        SHA256=$(shasum -a 256 "$PACKAGE_NAME" | cut -d' ' -f1)
    else
        log_warn "SHA256 checksum utility not available"
        SHA256="unavailable"
    fi
    
    # Save checksums
    echo "$SHA256  $PACKAGE_NAME" > "${PACKAGE_NAME}.sha256"
    
    log_info "Package integrity verified (SHA256: ${SHA256:0:16}...)"
}

# Main execution
main() {
    log_info "Starting Lambda package build process..."
    
    check_prerequisites
    clean_build_dir
    install_dependencies
    copy_source_files
    optimize_package
    validate_package
    create_zip_package
    generate_manifest
    verify_package_integrity
    
    log_info "Lambda package build completed successfully!"
    log_info "Package: $PACKAGE_NAME"
    log_info "Manifest: package-manifest.json"
    log_info "Checksum: ${PACKAGE_NAME}.sha256"
}

# Execute main function
main "$@"