# Scripts Directory

This directory contains all automation scripts for the Traefik development environment.

## Directory Structure

```
scripts/
├── loopback/          # Loopback alias management (172.16.123.1)
├── certificates/      # SSL certificate management
└── setup/            # Initial setup scripts (reserved for future use)
```

## Usage

Scripts are organized by functionality. Use the provided Makefile targets instead of running scripts directly:

```bash
# Loopback management
make create-loopback    # Setup loopback alias
make remove-loopback    # Remove loopback alias

# Certificate management
make setup-certs            # Copy certificates to Traefik
make install-renew-hook     # Install renewal hook
make setup-auto-renewal     # Setup automatic renewal
make remove-auto-renewal    # Remove automatic renewal
make test-renewal           # Test renewal process
```

## Direct Script Execution

If you need to run scripts directly:

```bash
# Loopback
sudo ./scripts/loopback/add-alias.sh
sudo ./scripts/loopback/remove-alias.sh

# Certificates
sudo ./scripts/certificates/setup-certificates.sh
sudo ./scripts/certificates/setup-auto-renewal.sh
```

## Adding New Scripts

When adding new scripts:
1. Place in appropriate subdirectory (loopback, certificates, or setup)
2. Make executable: `chmod +x scripts/category/script-name.sh`
3. Add Makefile target in root Makefile
4. Update this README
5. Document in main CLAUDE.md or SETUP.md
