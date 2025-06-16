# Local License Server

A simple HTTPS/HTTP license validation server written in Go.

## Features

- HTTPS support with automatic certificate loading
- Multi-domain certificate support with SNI
- License validation endpoints
- Command-line version flag
- Cross-platform builds (Linux AMD64/ARM64)

## Usage

### Command Line Options

```bash
# Show version
./local_license -version
./local_license -v

# Run with license key
./local_license [license_key] [port]

# Examples
./local_license ABC123 8080
./local_license ABC123        # Uses default port 444
./local_license               # No license key, uses default port
```

### Endpoints

- `/license-validation2` - License validation endpoint
- `/renew-license` - License renewal endpoint  
- `/heartbeat` - Health check endpoint
- `/` - Default endpoint (returns VALID status)

## Building

### Local Development

**On Windows:**
```cmd
build.bat [version]
```

**On Linux/macOS:**
```bash
chmod +x build.sh
./build.sh [version]
```

This will create binaries in the `bin/` directory:
- `local_license_linux_amd64`
- `local_license_linux_arm64`

### GitHub Releases

To create a release:

1. Tag your commit with a version:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

2. GitHub Actions will automatically:
   - Build for Linux AMD64 and ARM64
   - Create a GitHub release
   - Upload the binaries as release assets

## Certificate Configuration

Place your SSL certificates in `/root/back_certs/` directory:
- Certificate files: `domain.crt`
- Private key files: `domain.key`

The server will automatically load all certificate pairs and use SNI for multi-domain support.

## API Response Format

```json
{
  "status": "VALID",
  "message": "License is valid"
}
```

For license validation endpoints, the response format depends on the license key provided.
