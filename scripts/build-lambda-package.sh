#!/bin/bash

# Build script for TypeScript Lambda function package
# This script compiles TypeScript and creates a deployment-ready Lambda package

set -euo pipefail

# Configuration
PACKAGE_NAME="lambda-function.zip"
SOURCE_DIR="src"
DIST_DIR="dist"
BUILD_DIR="build"
MANIFEST_FILE="package-manifest.json"

echo "[INFO] 🏗️  Building TypeScript Lambda deployment package..."

# Clean previous builds
if [[ -d "$BUILD_DIR" ]]; then
    echo "[INFO] Cleaning previous build directory..."
    rm -rf "$BUILD_DIR"
fi

if [[ -d "$DIST_DIR" ]]; then
    echo "[INFO] Cleaning previous dist directory..."
    rm -rf "$DIST_DIR"
fi

if [[ -f "$PACKAGE_NAME" ]]; then
    echo "[INFO] Removing previous package..."
    rm -f "$PACKAGE_NAME"
fi

# Compile TypeScript
echo "[INFO] Compiling TypeScript..."
npm run build

# Verify compilation succeeded
if [[ ! -d "$DIST_DIR" ]]; then
    echo "[ERROR] TypeScript compilation failed - dist directory not found"
    exit 1
fi

# Create build directory
mkdir -p "$BUILD_DIR"

# Copy compiled JavaScript files
echo "[INFO] Copying compiled JavaScript files..."
cp -r "$DIST_DIR"/* "$BUILD_DIR/"

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
$(find "$SOURCE_DIR" -name "*.ts" | grep -v "\.test\." | grep -v "\.spec\." | sed 's/.*/"&"/' | paste -sd, -)
  ],
  "compiledFiles": [
$(find "$DIST_DIR" -name "*.js" 2>/dev/null | sed 's/.*/"&"/' | paste -sd, - || echo "")
  ],
  "dependencies": $(cd "$BUILD_DIR" && npm list --json --only=production 2>/dev/null | jq -c '.dependencies // {}')
}
EOF

# Generate checksum file
echo "$PACKAGE_HASH  $PACKAGE_NAME" > "$PACKAGE_NAME.sha256"

# Clean up build directory
rm -rf "$BUILD_DIR"

echo "[INFO] ✅ TypeScript Lambda package built successfully!"
echo "[INFO] 📦 Package: $PACKAGE_NAME ($PACKAGE_SIZE bytes)"
echo "[INFO] 🔐 SHA256: $PACKAGE_HASH"
echo "[INFO] 📋 Manifest: $MANIFEST_FILE"
echo "[INFO] 🎯 Runtime: Node.js with compiled TypeScript"