# Contributing to Traefik Local Development

Thank you for your interest in contributing! This document provides guidelines for contributing code, bug fixes, and improvements to this project.

**Note**: If you're looking for setup instructions, see [README.md](README.md) or [SETUP.md](SETUP.md).

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How to Contribute](#how-to-contribute)
- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Project Structure](#project-structure)
- [Coding Guidelines](#coding-guidelines)

## Code of Conduct

- Be respectful and constructive in discussions
- Focus on the technical merits of contributions
- Welcome newcomers and help them get started
- Follow the code style and conventions of the project

## How to Contribute

### Reporting Issues

Before opening an issue:
1. Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for known issues
2. Search existing issues to avoid duplicates
3. Collect relevant information (OS, Docker version, error messages)

When reporting:
- **Bug reports**: Describe what you expected vs. what happened
- **Feature requests**: Explain the use case and why it's valuable
- **Questions**: First check documentation, then ask

### Suggesting Enhancements

We welcome enhancements! Before implementing:
1. Open an issue to discuss the change
2. Wait for feedback from maintainers
3. If approved, proceed with implementation

Good enhancements:
- Improve existing features
- Add platform support (e.g., Windows)
- Better error messages
- Performance improvements
- Documentation improvements

## Development Setup

### Prerequisites

- Docker & Docker Compose
- macOS or Linux (for testing)
- Git
- Basic knowledge of Bash, Docker, and Traefik

### Fork and Clone

```bash
# Fork the repository on GitHub, then:
git clone https://github.com/YOUR_USERNAME/traefik.git
cd traefik
git remote add upstream https://github.com/ORIGINAL_OWNER/traefik.git
```

### Local Setup

```bash
# Configure your environment
cp .env.example .env
nano .env  # Use a test domain

# Initialize
make init

# You'll need test certificates - see SETUP.md for details
```

## Making Changes

### Branch Strategy

```bash
# Create a feature branch from main
git checkout main
git pull upstream main
git checkout -b feature/your-feature-name
```

Branch naming:
- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation updates
- `refactor/` - Code refactoring

### Development Workflow

1. **Make your changes** in a focused, logical manner
2. **Test thoroughly** on your platform
3. **Update documentation** if needed
4. **Commit with clear messages** (see below)

### Commit Messages

Follow this format:

```
<type>: <short summary>

<optional detailed description>

<optional footer>
```

Types:
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation changes
- `refactor:` - Code refactoring
- `test:` - Adding/updating tests
- `chore:` - Maintenance tasks

Examples:
```
feat: add Windows support for loopback alias

Added PowerShell scripts for configuring loopback alias on Windows.
Tested on Windows 11 with Docker Desktop.

fix: handle spaces in domain names correctly

The generate-configs.sh script failed when DOMAIN contained spaces.
Added proper quoting in sed commands.

docs: improve certificate troubleshooting section

Added more specific error messages and solutions for common
certificate permission issues on macOS.
```

### Code Guidelines

#### Shell Scripts

```bash
#!/bin/bash
# Always use bash shebang

# Use set -e for error handling
set -e

# Load configuration consistently
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../common/load-config.sh"

# Use meaningful variable names
CERT_FILE="${DOMAIN}.crt"
KEY_FILE="${DOMAIN}.key"

# Quote variables to handle spaces
cp "${CERT_DIR}/${CERT_FILE}" "${TARGET_DIR}/"

# Provide helpful error messages
if [ ! -f "$CERT_FILE" ]; then
    echo "Error: Certificate file not found: $CERT_FILE"
    echo "Please run: make setup-certs"
    exit 1
fi
```

#### Configuration Templates

```toml
# Use {{VARIABLE}} syntax for substitutions
[[tls.certificates]]
certFile = "/etc/ssl/{{CERT_FILE}}"
keyFile = "/etc/ssl/{{KEY_FILE}}"
```

#### Documentation

- Use clear, concise language
- Provide examples for complex concepts
- Mark admin-only steps with 🔐 **ADMIN ONLY**
- Test all commands before documenting

### Testing

#### Manual Testing Checklist

Test your changes on:
- [ ] macOS (if applicable)
- [ ] Linux (if applicable)
- [ ] Fresh clone of the repository
- [ ] With different domain configurations

#### Test Scenarios

1. **Fresh Setup**
   ```bash
   make destroy
   make create
   # Verify everything works
   ```

2. **Configuration Changes**
   ```bash
   # Change DOMAIN in .env
   make check-env
   # Verify configs regenerated correctly
   ```

3. **Error Handling**
   ```bash
   # Test with missing .env
   # Test with invalid domain
   # Verify error messages are helpful
   ```

## Submitting Changes

### Before Submitting

- [ ] Code follows project conventions
- [ ] All scripts are executable (`chmod +x`)
- [ ] Documentation is updated
- [ ] Tested on at least one platform
- [ ] Commits have clear messages
- [ ] No sensitive data (tokens, personal domains) in commits

### Pull Request Process

1. **Update your branch**
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

3. **Create Pull Request**
   - Go to GitHub and create a PR from your branch
   - Fill out the PR template
   - Link related issues

4. **PR Title Format**
   ```
   <type>: <short description>
   ```
   Example: `feat: add Windows PowerShell scripts for loopback alias`

5. **PR Description Should Include**
   - What problem does this solve?
   - How did you solve it?
   - What platforms did you test on?
   - Screenshots (if UI changes)
   - Related issues

### Review Process

- Maintainers will review your PR
- Be responsive to feedback
- Make requested changes in new commits
- Don't force-push after review starts
- Once approved, maintainer will merge

## Project Structure

### Key Directories

```
traefik/
├── scripts/
│   ├── common/          # Shared utilities (IMPORTANT: all scripts should use)
│   ├── loopback/        # Platform-specific loopback management
│   ├── certificates/    # Certificate management
│   └── setup/           # Configuration generation
├── configs/             # Traefik configuration templates
├── guides/              # Detailed guides (topic-specific)
└── [documentation]      # README, SETUP, CONTRIBUTING, etc.
```

### Adding New Scripts

1. **Use common config loader**
   ```bash
   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
   source "${SCRIPT_DIR}/../common/load-config.sh"
   ```

2. **Add to Makefile** if user-facing

3. **Document in appropriate README**
   - `scripts/loopback/README.md`
   - `scripts/certificates/README.md`
   - `scripts/setup/README.md`

### Adding New Configuration

1. **Create template** in `configs/` or relevant directory
   - Use `{{VARIABLE}}` syntax
   - Add `.template` extension

2. **Update generate-configs.sh** to generate it

3. **Add to .gitignore** (generated file)

4. **Document** in README.md and SETUP.md

## Platform-Specific Contributions

### macOS

- Use LaunchDaemons for persistence
- Test on both Intel and Apple Silicon if possible
- Handle Homebrew vs. system paths

### Linux

- Use systemd for persistence
- Test on Ubuntu/Debian and RHEL/Fedora if possible
- Handle different package managers

### Windows

- Use PowerShell for scripts
- Test with Docker Desktop
- Handle Windows-specific path formats

## Getting Help

- **Questions**: Open a discussion or issue
- **Stuck**: Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **Setup**: See [SETUP.md](SETUP.md)

## Recognition

Contributors will be:
- Listed in release notes
- Credited in commits
- Appreciated for their time and effort!

Thank you for contributing! 🙏
