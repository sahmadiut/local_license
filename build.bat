@echo off
setlocal

REM Build script for local_license
REM Builds for Linux AMD64 and ARM64 architectures

set VERSION=%1
if "%VERSION%"=="" set VERSION=0.0.1

echo Building local_license version %VERSION%...

REM Create build directory if it doesn't exist
if not exist build mkdir build

REM Set common environment variables
set CGO_ENABLED=0

REM Build for Linux AMD64
echo Building for Linux AMD64...
set GOOS=linux
set GOARCH=amd64
go build -ldflags "-X main.version=%VERSION%" -o "build/local_license_linux_amd64" main.go

if %errorlevel% equ 0 (
    echo ✓ Linux AMD64 build successful
) else (
    echo ✗ Linux AMD64 build failed
    exit /b 1
)

REM Build for Linux ARM64
echo Building for Linux ARM64...
set GOOS=linux
set GOARCH=arm64
go build -ldflags "-X main.version=%VERSION%" -o "build/local_license_linux_arm64" main.go

if %errorlevel% equ 0 (
    echo ✓ Linux ARM64 build successful
) else (
    echo ✗ Linux ARM64 build failed
    exit /b 1
)

echo Build completed successfully!
echo Binaries created in build/ directory:
dir build\

endlocal
