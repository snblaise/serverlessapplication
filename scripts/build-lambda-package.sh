#!/bin/bash

# Build script for Lambda function package
# This script creates a deployment-ready Lambda package

set -euo pipefail

# Configuration
PACKAGE_NAME="lambda-function.zip"
SOURCE_DIR="src"
BUILD_DIR="build"
MANIFEST_FILE="package-manifest.json"

echo "[INFO] 🏗️  Building Lambda deployment package..."

# Clean previous builds
if [[ -d "$BUILD_DIR" ]]; then
    echo "[INFO] Cleaning previous build directory..."
    rm -rf "$BUILD_DIR"
fi

if [[ -f "$PACKAGE_NAME" ]]; then
    echo "[INFO] Removing previous package..."
    rm -f "$PACKAGE_NAME"
fi

# Create build directory
mkdir -p "$BUILD_DIR"

# Copy source files
echo "[INFO] Copying source files..."
cp -r "$SOURCE_DIR"/* "$BUILD_DIR/"

# Install production dependencies in build directory
echo "[INFO] Installing production dependencies..."
cp package.json "$BUILD_DIR/"
if [[ -f "../package-lock.json" ]]; then
    cp ../package-lock.json "$BUILD_DIR/"
fi
cd "$BUILD_DIR"
npm install --only=production --silent

# Remove unnecessary files
echo "[INFO] Cleaning up unnecessary files..."
find . -name "*.test.js" -delete
find . -name "*.spec.js" -delete
find . -name "README.md" -delete
find . -name "*.md" -delete
rm -rf .git* 2>/dev/null || true

# Create the package
cd ..
echo "[INFO] Creating deployment package..."
cd "$BUILD_DIR"
zip -r "../$PACKAGE_NAME" . -q

# Generate package manifest
cd ..
echo "[INFO] Generating package manifest..."
PACKAGE_SIZE=$(stat -f%z "$PACKAGE_NAME" 2>/dev/null || stat -c%s "$PACKAGE_NAME")
PACKAGE_HASH=$(shasum -a 256 "$PACKAGE_NAME" | cut -d' ' -f1)

cat > "$MANIFEST_FILE" << EOF
{
  "packageName": "$PACKAGE_NAME",
  "packageSize": $PACKAGE_SIZE,
  "packageHash": "$PACKAGE_HASH",
  "buildTimestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "sourceFiles": [
$(find "$SOURCE_DIR" -name "*.js" | grep -v "\.test\." | sed 's/.*/"&"/' | paste -sd, -)
  ],
  "dependencies": $(cd "$BUILD_DIR" && npm list --json --only=production 2>/dev/null | jq -c '.dependencies // {}')
}
EOF

# Generate checksum file
echo "$PACKAGE_HASH  $PACKAGE_NAME" > "$PACKAGE_NAME.sha256"

# Clean up build directory
rm -rf "$BUILD_DIR"

echo "[INFO] ✅ Lambda package built successfully!"
echo "[INFO] 📦 Package: $PACKAGE_NAME ($PACKAGE_SIZE bytes)"
echo "[INFO] 🔐 SHA256: $PACKAGE_HASH"
echo "[INFO] 📋 Manifest: $MANIFEST_FILE"