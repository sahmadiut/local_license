#!/bin/bash

# Build script for local_license
# Builds for Linux AMD64 and ARM64 architectures

VERSION=${1:-"0.0.1"}

echo "Building local_license version $VERSION..."

# Create build directory if it doesn't exist
mkdir -p build

# Set common environment variables
export CGO_ENABLED=0

# Build for Linux AMD64
echo "Building for Linux AMD64..."
GOOS=linux GOARCH=amd64 go build -ldflags "-X main.version=$VERSION" -o "build/local_license_linux_amd64" main.go

if [ $? -eq 0 ]; then
    echo "✓ Linux AMD64 build successful"
else
    echo "✗ Linux AMD64 build failed"
    exit 1
fi

# Build for Linux ARM64
echo "Building for Linux ARM64..."
GOOS=linux GOARCH=arm64 go build -ldflags "-X main.version=$VERSION" -o "build/local_license_linux_arm64" main.go

if [ $? -eq 0 ]; then
    echo "✓ Linux ARM64 build successful"
else
    echo "✗ Linux ARM64 build failed"
    exit 1
fi

echo "Build completed successfully!"
echo "Binaries created in build/ directory:"
ls -la build/
