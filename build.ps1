# Build script for local_license
# Builds for Linux AMD64 and ARM64 architectures

param(
    [string]$Version = "0.0.1"
)

Write-Host "Building local_license version $Version..." -ForegroundColor Green

# Create build directory if it doesn't exist
if (!(Test-Path "build")) {
    New-Item -ItemType Directory -Name "build"
}

# Set common environment variables
$env:CGO_ENABLED = "0"

# Build for Linux AMD64
Write-Host "Building for Linux AMD64..." -ForegroundColor Yellow
$env:GOOS = "linux"
$env:GOARCH = "amd64"
go build -ldflags "-X main.version=$Version" -o "build/local_license_linux_amd64" main.go

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Linux AMD64 build successful" -ForegroundColor Green
} else {
    Write-Host "✗ Linux AMD64 build failed" -ForegroundColor Red
    exit 1
}

# Build for Linux ARM64
Write-Host "Building for Linux ARM64..." -ForegroundColor Yellow
$env:GOOS = "linux"
$env:GOARCH = "arm64"
go build -ldflags "-X main.version=$Version" -o "build/local_license_linux_arm64" main.go

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Linux ARM64 build successful" -ForegroundColor Green
} else {
    Write-Host "✗ Linux ARM64 build failed" -ForegroundColor Red
    exit 1
}

# Reset environment variables
Remove-Item Env:GOOS -ErrorAction SilentlyContinue
Remove-Item Env:GOARCH -ErrorAction SilentlyContinue
Remove-Item Env:CGO_ENABLED -ErrorAction SilentlyContinue

Write-Host "Build completed successfully!" -ForegroundColor Green
Write-Host "Binaries created in build/ directory:" -ForegroundColor Cyan
Get-ChildItem "build" | Format-Table Name, Length, LastWriteTime
