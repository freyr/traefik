# SSL Certificate Distribution for Teams

## Overview

You need to distribute the wildcard SSL certificate (`*.example.dev`) to team members for local development. This document explores secure distribution options for small teams.

## Security Considerations

### What You're Distributing

- **Certificate** (`example.dev.crt`) - ✅ Public, safe to share openly
- **Private Key** (`example.dev.key`) - ⚠️ **SENSITIVE**, must be protected

### Risk Assessment

**Risk Level**: Medium
- This is a **development certificate** for local environments
- Domain resolves to `172.16.123.1` (private loopback IP)
- Not used in production
- Limited blast radius if compromised

**However**, if the private key is leaked:
- ❌ Attacker could MITM `*.example.dev` traffic (if they control DNS/network)
- ❌ Could impersonate your services in development
- ⚠️ Let's Encrypt may rate-limit you if you need to revoke/reissue frequently

## Distribution Options

### Option 1: Private On-Premise Git Repository (Recommended for Small Teams)

**Best for**: 2-10 developers, existing Git infrastructure

#### Setup

```bash
# 1. Create a private repository (GitLab, Gitea, GitHub Enterprise, etc.)
git init ssl-certificates
cd ssl-certificates

# 2. Add certificates
mkdir example.dev
cp /etc/letsencrypt/live/example.dev/fullchain.pem example.dev/example.dev.crt
cp /etc/letsencrypt/live/example.dev/privkey.pem example.dev/example.dev.key

# 3. Add README
cat > README.md <<EOF
# Development SSL Certificates

## example.dev
- **Domain**: *.example.dev
- **Issued**: $(date)
- **Expires**: $(openssl x509 -in example.dev/example.dev.crt -noout -enddate)
- **Type**: Let's Encrypt wildcard certificate

## Usage

1. Clone this repository to your local machine
2. Copy certificate files to your project's ssl/ directory
3. Configure your reverse proxy (Traefik, nginx, etc.)

## Security

⚠️ This repository contains private keys. Do NOT:
- Make this repository public
- Commit to other repositories
- Share outside the development team
- Use in production environments
EOF

# 4. Commit and push
git add .
git commit -m "Add example.dev wildcard certificate"
git remote add origin git@your-server:team/ssl-certificates.git
git push -u origin main
```

#### Team Access

```bash
# Team members clone the repo
git clone git@your-server:team/ssl-certificates.git

# Update when certificates are renewed
cd ssl-certificates
git pull

# Automated script for team members
cat > update-certs.sh <<'EOF'
#!/bin/bash
cd ~/ssl-certificates
git pull
cp example.dev/* ~/code/freyr/traefik/ssl/
echo "✓ Certificates updated"
EOF
chmod +x update-certs.sh
```

**Pros**:
- ✅ Version controlled
- ✅ Easy to update (just `git pull`)
- ✅ Audit trail (git log shows who accessed)
- ✅ Can be automated
- ✅ Team already knows Git

**Cons**:
- ⚠️ Keys stored in plaintext in Git history
- ⚠️ Requires Git server with access control
- ⚠️ If repo is accidentally made public, keys are exposed

**Security Enhancements**:
- Enable Git repository access logs
- Restrict to specific users/groups
- Use SSH keys for authentication
- Enable 2FA on Git server
- Consider git-crypt (see Option 3)

---

### Option 2: Encrypted Archive with Shared Password

**Best for**: Very small teams (2-5), no shared infrastructure

#### Setup

```bash
# Create encrypted archive
cd /etc/letsencrypt/live/example.dev/
tar czf - fullchain.pem privkey.pem | \
  openssl enc -aes-256-cbc -pbkdf2 -out ~/freyr-dev-net-certs.tar.gz.enc

# This will prompt for a password
# Share this password via secure channel (1Password, Bitwarden, etc.)
```

#### Distribution

```bash
# Upload encrypted file to:
# - Company file share (SMB, NFS)
# - Internal web server
# - Shared cloud storage (with access controls)
# - Send via secure file transfer
```

#### Team Member Decryption

```bash
# Download and decrypt
openssl enc -aes-256-cbc -pbkdf2 -d \
  -in freyr-dev-net-certs.tar.gz.enc | tar xzf -

# Copy to project
cp fullchain.pem ~/code/freyr/traefik/ssl/example.dev.crt
cp privkey.pem ~/code/freyr/traefik/ssl/example.dev.key
```

**Pros**:
- ✅ Simple, no infrastructure needed
- ✅ Encrypted at rest
- ✅ Works with any file sharing method

**Cons**:
- ❌ Password must be shared separately
- ❌ Manual process for updates
- ❌ No audit trail
- ❌ Difficult to revoke access

---

### Option 3: Git-Crypt (Encrypted Git Repository)

**Best for**: Teams with Git, want transparency + encryption

#### Setup

```bash
# Install git-crypt
brew install git-crypt  # macOS
apt install git-crypt   # Linux

# Initialize repository
git init ssl-certificates
cd ssl-certificates

# Initialize encryption
git-crypt init

# Configure what to encrypt
cat > .gitattributes <<EOF
*.key filter=git-crypt diff=git-crypt
*.pem filter=git-crypt diff=git-crypt
*.p12 filter=git-crypt diff=git-crypt
EOF

# Add certificates
mkdir example.dev
cp /etc/letsencrypt/live/example.dev/fullchain.pem example.dev/
cp /etc/letsencrypt/live/example.dev/privkey.pem example.dev/

git add .
git commit -m "Add encrypted certificates"
```

#### Grant Team Access

```bash
# Export team members' GPG keys
git-crypt add-gpg-user john@example.com
git-crypt add-gpg-user alice@example.com

# OR create a shared symmetric key
git-crypt export-key ~/ssl-certificates-key

# Share the key file via secure channel
# Team members use: git-crypt unlock ~/ssl-certificates-key
```

#### Team Member Access

```bash
# Clone repository
git clone git@your-server:team/ssl-certificates.git
cd ssl-certificates

# Unlock with shared key
git-crypt unlock ~/ssl-certificates-key

# OR unlock with GPG (if added as GPG user)
git-crypt unlock  # Uses their GPG key automatically

# Files are now decrypted locally
ls example.dev/
# fullchain.pem  privkey.pem
```

**Pros**:
- ✅ Encrypted in Git (even in history)
- ✅ Transparent encryption/decryption
- ✅ Version controlled
- ✅ Git workflow familiar to developers

**Cons**:
- ⚠️ Requires git-crypt installed
- ⚠️ GPG key management (if using GPG mode)
- ⚠️ Shared symmetric key must still be distributed securely

---

### Option 4: Secret Management Tools

**Best for**: Teams already using secret management, larger teams

#### Options

**HashiCorp Vault**
```bash
# Store certificate
vault kv put secret/certs/example.dev \
  certificate=@example.dev.crt \
  private_key=@example.dev.key

# Retrieve
vault kv get -field=certificate secret/certs/example.dev > example.dev.crt
vault kv get -field=private_key secret/certs/example.dev > example.dev.key
```

**1Password CLI**
```bash
# Store (via 1Password GUI or CLI)
op item create --category=server \
  --title="example.dev SSL Certificate" \
  certificate[file]=example.dev.crt \
  private_key[file]=example.dev.key

# Retrieve
op document get "example.dev certificate" --output example.dev.crt
op document get "example.dev private key" --output example.dev.key
```

**Bitwarden Send**
```bash
# Upload securely with expiration
bw send create --file freyr-dev-net-certs.tar.gz \
  --name "SSL Certificates" \
  --deletionDate "2025-12-31"
```

**Pros**:
- ✅ Enterprise-grade security
- ✅ Access controls and audit logs
- ✅ Automatic encryption
- ✅ Can integrate with CI/CD

**Cons**:
- ❌ Requires infrastructure/subscription
- ❌ Learning curve
- ❌ Overkill for very small teams

---

### Option 5: Generate Certificates Individually (Alternative Approach)

**Best for**: Ultimate security, team members comfortable with certbot

Instead of distributing certificates, each team member generates their own:

```bash
# Each team member runs:
python3 -m pip install --break-system-packages certbot-dns-cloudflare

# Create credentials file
mkdir -p ~/.secrets
cat > ~/.secrets/cloudflare.ini <<EOF
dns_cloudflare_api_token = SHARED_CLOUDFLARE_TOKEN
EOF
chmod 600 ~/.secrets/cloudflare.ini

# Generate certificate
sudo certbot certonly --dns-cloudflare \
  --dns-cloudflare-credentials ~/.secrets/cloudflare.ini \
  -d '*.example.dev' -d 'example.dev'

# Copy to project
cd ~/code/freyr/traefik
make setup-certs
```

**Pros**:
- ✅ No private key distribution needed!
- ✅ Each developer has their own certificate
- ✅ Revocation doesn't affect others
- ✅ Follows security best practices

**Cons**:
- ⚠️ Cloudflare API token must be shared (less sensitive than private key)
- ⚠️ Cloudflare API token has broader permissions (DNS edit)
- ⚠️ Let's Encrypt rate limits (50 certs/week per domain)
- ⚠️ Each dev must set up certbot

---

## Security Best Practices

Regardless of chosen method:

1. **Access Control**
   - Limit access to team members only
   - Use SSH keys or strong authentication
   - Enable 2FA where possible

2. **Audit Trail**
   - Log who accesses certificates
   - Review logs periodically
   - Track certificate versions

3. **Secure Channels**
   - Always use encrypted transport (HTTPS, SSH, SFTP)
   - Don't send via unencrypted email
   - Don't paste in Slack/chat without encryption

4. **Documentation**
   - Document distribution process
   - Include expiry date and renewal process
   - Add security warnings

5. **Rotation**
   - Certificates auto-renew every 60-90 days
   - Plan distribution of renewed certificates
   - Consider automation (git-crypt makes this easy)

6. **Incident Response**
   - Know how to revoke certificate if compromised
   - Document who to contact
   - Have backup plan

## Comparison Matrix

| Method | Security | Ease of Use | Updates | Infrastructure | Best For |
|--------|----------|-------------|---------|----------------|----------|
| Private Git | Medium | Easy | Easy (git pull) | Git server | Small teams with Git |
| Encrypted Archive | Medium | Medium | Manual | File share | Very small teams |
| git-crypt | High | Medium | Easy (git pull) | Git + git-crypt | Security-conscious teams |
| Vault/1Password | Very High | Hard | Easy (API) | Secret manager | Larger teams, existing infra |
| Individual Certs | Highest | Medium | Automatic | Certbot | Security-first approach |

## Conclusion

**For 2-10 developers**: Use **private Git repository with git-crypt**
- Good balance of security and convenience
- Easy updates via git pull
- Encryption at rest
- Familiar Git workflow

**For quick setup**: Use **private Git repository** (no encryption)
- Acceptable for development certificates
- Very simple to set up
- Easy to understand

**For maximum security**: Have each developer **generate their own certificates**
- No key distribution needed
- Best security posture
- Requires Cloudflare API token sharing
