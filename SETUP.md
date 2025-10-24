# Traefik Local Development - Detailed Setup Guide

This guide provides detailed step-by-step instructions for setting up Traefik. For a quick overview, see [README.md](README.md).

**This guide covers:**
- Detailed DNS configuration with Cloudflare
- Certificate generation with Let's Encrypt
- Troubleshooting each step
- Platform-specific instructions

## Setup Scenarios

This guide covers two setup scenarios:

1. **Personal Setup**: You configure everything yourself (DNS, certificates, local environment)
2. **Team Setup**:
   - **Admin**: Configures DNS and generates certificates (once)
   - **Team Members**: Configure local environment and use shared certificates

**Note**: Steps marked with 🔐 **ADMIN ONLY** are required only for admins in team setups. Team members can skip these steps.

## Prerequisites

**All Users:**
- macOS, Linux, or Windows with WSL
- Docker and Docker Compose installed

**🔐 Admin Only (for team setup):**
- Domain name with DNS management access (Cloudflare recommended)
- Certbot installed: `brew install certbot` (macOS) or `apt install certbot` (Linux)

## Step 0: Configure Environment (All Users)

Before starting, configure your local environment:

```bash
# 1. Clone the repository
git clone <repository-url>
cd traefik

# 2. Copy environment template
cp .env.example .env

# 3. Edit configuration
nano .env
```

**Required settings:**
- `DOMAIN` - Your domain (get from admin if in team setup)
- `LOOPBACK_IP` - Loopback IP (default: `172.16.123.1`)
- `LETSENCRYPT_EMAIL` - Your email (for certificate expiry notifications)

**Optional settings:**
- `CLOUDFLARE_API_TOKEN` - For automated certificate renewal
- `TRAEFIK_DASHBOARD_SUBDOMAIN` - Dashboard subdomain (default: `traefik`)

```bash
# 4. Initialize project (generates configuration files)
make init
```

## Step 1: Configure DNS A Record 🔐 **ADMIN ONLY**

**Note for team members**: Skip this step. Your admin has already configured DNS.

You need to configure your domain's DNS to point to your local loopback IP.

### Using Cloudflare (Recommended)

1. Log in to your Cloudflare dashboard
2. Select your domain (e.g., `example.dev`)
3. Go to **DNS** → **Records**
4. Add a new **A** record:
   - **Type**: A
   - **Name**: `*` (wildcard for all subdomains)
   - **IPv4 address**: `172.16.123.1`
   - **TTL**: Auto or 3600 (1 hour)
   - **Proxy status**: DNS only (disable orange cloud)

Example DNS record:
```
*.example.dev.   3600  IN  A  172.16.123.1
```

**Important**: Disable Cloudflare proxy (orange cloud) for this record, as it needs to resolve to your local IP.

### Verification

Wait 1-5 minutes for DNS propagation, then verify:
```bash
dig traefik.example.dev
# Should return: 172.16.123.1
```

## Step 2: Generate Let's Encrypt Certificate 🔐 **ADMIN ONLY**

**Note for team members**: Skip this step. Your admin will provide certificates (see Step 3).

Let's Encrypt requires proof that you own the domain. Since `172.16.123.1` is a private IP, we must use DNS challenge (not HTTP challenge).

### Generate Certificate with DNS Challenge

Run certbot with manual DNS challenge:
```bash
sudo certbot certonly --manual --preferred-challenges dns \
  -d '*.example.dev' -d 'example.dev'
```

Follow the interactive prompts:

1. **Enter email address**: Your email for renewal notifications
2. **Agree to Terms of Service**: Yes
3. **Share email**: Your choice (optional)
4. **DNS Challenge**: Certbot will display a TXT record to add

Example output:
```
Please deploy a DNS TXT record under the name:
_acme-challenge.example.dev.

with the following value:
xYz123AbC456DeF789...
```

### Add DNS TXT Record

1. Go back to Cloudflare DNS management
2. Add a new **TXT** record:
   - **Type**: TXT
   - **Name**: `_acme-challenge`
   - **Content**: The value provided by certbot (e.g., `xYz123AbC456DeF789...`)
   - **TTL**: Auto or 300 (5 minutes)

3. Verify the TXT record is live:
```bash
dig TXT _acme-challenge.example.dev
```

4. Press Enter in certbot to continue

### Success!

If successful, certbot will save certificates to:
```
/etc/letsencrypt/live/example.dev/
  ├── fullchain.pem   (certificate + intermediate chain)
  ├── privkey.pem     (private key)
  ├── cert.pem        (certificate only)
  └── chain.pem       (intermediate chain)
```

## Step 3: Setup Certificates

Traefik needs the certificates in its `ssl/` directory with `.crt` and `.key` extensions.

### For Admins (Personal Setup or Team Admin)

Copy certificates from Let's Encrypt to Traefik:

### Automatic Method (Recommended)

Use the provided setup script:
```bash
sudo ./setup-certificates.sh
```

This script:
- Copies `fullchain.pem` → `ssl/example.dev.crt`
- Copies `privkey.pem` → `ssl/example.dev.key`
- Sets correct permissions (644)
- Changes ownership to your user

### Manual Method

If you prefer manual copying:
```bash
sudo cp /etc/letsencrypt/live/example.dev/fullchain.pem ssl/example.dev.crt
sudo cp /etc/letsencrypt/live/example.dev/privkey.pem ssl/example.dev.key
sudo chmod 644 ssl/example.dev.key ssl/example.dev.crt
sudo chown $USER:$(id -gn) ssl/example.dev.key ssl/example.dev.crt
```

**Important Notes:**
- Use `fullchain.pem` (not `cert.pem`) to include intermediate certificates
- The `.key` file must have `644` permissions (readable by Docker)
- Both `.pem` and `.crt`/`.key` files are the same format, just different extensions

**For Team Admins**: After copying certificates, distribute them to team members. See [guides/certificate-distribution.md](guides/certificate-distribution.md) for secure distribution methods.

### For Team Members

If you're joining a team where DNS and certificates are already configured:

1. **Get certificates from your admin**
   - Receive the `.crt` and `.key` files from your team admin
   - See [guides/certificate-distribution.md](guides/certificate-distribution.md) for details

2. **Place certificates in ssl/ directory**
   ```bash
   # Copy received files to ssl/ directory
   cp /path/to/received/example.dev.crt ssl/
   cp /path/to/received/example.dev.key ssl/

   # Set correct permissions
   chmod 644 ssl/example.dev.crt ssl/example.dev.key
   ```

3. **Continue to Step 4** (setup loopback alias)

## Step 4: Setup Loopback Alias (All Users)

Configure the `172.16.123.1` loopback alias so your system can route traffic to it.

### macOS
```bash
sudo make create-loopback
```

This installs a LaunchDaemon that persists across reboots.

### Linux
```bash
sudo make create-loopback
```

### Verify
```bash
ifconfig lo0 | grep 172.16.123.1  # macOS
ifconfig lo | grep 172.16.123.1   # Linux
```

## Step 5: Start Traefik (All Users)

### First Time Setup
```bash
make create
```

This will:
1. Create the `local` Docker network
2. Setup loopback alias (requires sudo)
3. Start Traefik

### Daily Usage
```bash
make start   # Start Traefik
make stop    # Stop Traefik
make destroy # Stop and remove everything
```

## Step 6: Verify Setup (All Users)

Test that everything is working:

```bash
# 1. Check DNS resolution
dig traefik.example.dev
# Expected: 172.16.123.1

# 2. Check loopback alias
ifconfig lo0 | grep 172.16.123.1
# Expected: inet 172.16.123.1 netmask 0xffff0000

# 3. Check Traefik is running
docker compose ps
# Expected: traefik Up (healthy)

# 4. Test HTTPS connection
curl -k https://traefik.example.dev
# Expected: <a href="/dashboard/">Found</a>.

# 5. Open in browser
open https://traefik.example.dev/dashboard/
```

## Step 7: Setup Automatic Renewal 🔐 **ADMIN ONLY** (Optional but Recommended)

**Note for team members**: Skip this step. Certificate renewal is managed by your admin.

Let's Encrypt certificates expire after 90 days. Set up automatic renewal.

### Install Renewal Hook

```bash
sudo mkdir -p /etc/letsencrypt/renewal-hooks/deploy
sudo cp renew-hook.sh /etc/letsencrypt/renewal-hooks/deploy/traefik-renew.sh
sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/traefik-renew.sh
```

Edit the script to update `TRAEFIK_DIR` to your installation path:
```bash
sudo nano /etc/letsencrypt/renewal-hooks/deploy/traefik-renew.sh
# Update: TRAEFIK_DIR="/path/to/your/traefik"
```

### Test Renewal

Test the renewal process (won't actually renew if cert is not near expiry):
```bash
sudo certbot renew --dry-run
```

### Automatic Renewal Setup

**Important**: Homebrew's certbot on macOS does NOT automatically configure renewal timers!

#### macOS Setup

Install the automatic renewal LaunchDaemon:

```bash
# Setup automatic renewal (runs twice daily)
make setup-auto-renewal

# Verify it's configured
make check-renewal-status
# OR
sudo launchctl list | grep certbot

# View renewal logs
tail -f /var/log/certbot-renew.log
```

This creates a LaunchDaemon that:
- Runs `certbot renew` twice daily (00:00 and 12:00)
- Checks all certificates
- Renews certificates expiring within 30 days
- Triggers post-renewal hooks automatically

#### Linux Setup

Linux packages usually set this up automatically via systemd timer:

```bash
# Check if enabled
systemctl list-timers | grep certbot

# If not present, enable it
sudo systemctl enable certbot-renew.timer
sudo systemctl start certbot-renew.timer
```

#### What Happens During Renewal

The renewal process automatically:
1. Checks all certificates in `/etc/letsencrypt/renewal/`
2. Renews certificates expiring within 30 days
3. Runs the post-renewal hook (`renew-hook.sh`) which:
   - Copies renewed certificates to `ssl/` directory
   - Sets correct permissions (644)
   - Restarts Traefik to load new certificates

### Manual Renewal

To manually renew before expiry:
```bash
sudo certbot renew --force-renewal --manual
```

**⚠️ Important**: Certificates generated with `--manual` **CANNOT be automatically renewed** without manual intervention. You'll need to update the TXT record again during each renewal.

**For production use, always use DNS automation plugins** (see below) to enable truly automatic renewals.

### Automated Renewal with DNS Plugins (Recommended)

For fully automated renewals without manual intervention, use DNS provider plugins:
- `certbot-dns-cloudflare` for Cloudflare → **See [guides/cloudflare-dns-plugin.md](guides/cloudflare-dns-plugin.md) for complete guide**
- `certbot-dns-route53` for AWS Route53
- `certbot-dns-google` for Google Cloud DNS
- [More providers](https://eff-certbot.readthedocs.io/en/stable/using.html#dns-plugins)

#### Quick Cloudflare DNS Plugin Setup:

#### macOS (Python 3.13+ / Homebrew certbot)
```bash
# If certbot installed via Homebrew, use --break-system-packages
python3 -m pip install --break-system-packages certbot-dns-cloudflare

# Verify plugin is installed
certbot plugins | grep cloudflare
# Should show: dns-cloudflare
```

**Note**: Modern macOS Python requires `--break-system-packages` flag due to PEP 668. This is safe for certbot plugins. See [guides/cloudflare-dns-plugin.md](guides/cloudflare-dns-plugin.md) for alternative installation methods (pipx, venv).

#### Linux
```bash
# Ubuntu/Debian
sudo apt install python3-certbot-dns-cloudflare

# RHEL/CentOS/Fedora
sudo dnf install python3-certbot-dns-cloudflare

# Or via pip
sudo pip3 install certbot-dns-cloudflare
```

#### Configure Cloudflare API Token
```bash
# 1. Create API token in Cloudflare dashboard:
#    - Go to: My Profile → API Tokens → Create Token
#    - Use template: "Edit zone DNS"
#    - Zone Resources: Include → Specific zone → example.dev
#    - Copy the generated token

# 2. Save token to file:
mkdir -p ~/.secrets
echo "dns_cloudflare_api_token = YOUR_API_TOKEN_HERE" > ~/.secrets/cloudflare.ini
chmod 600 ~/.secrets/cloudflare.ini
```

#### Generate Certificate (Fully Automated)
```bash
# No manual DNS changes needed!
sudo certbot certonly --dns-cloudflare \
  --dns-cloudflare-credentials ~/.secrets/cloudflare.ini \
  -d '*.example.dev' -d 'example.dev'

# Copy to Traefik
sudo ./setup-certificates.sh
```

**Benefits of DNS plugin:**
- No manual DNS TXT record updates
- Automatic renewals work without intervention
- Can run renewals via cron/timer unattended

## Troubleshooting

### Renewal Failures with Manual Certificates

If you see errors like:
```
Failed to renew certificate with error: The manual plugin is not working
PluginError('An authentication script must be provided with --manual-auth-hook...')
```

This means you have old certificates generated with `--manual` that can't auto-renew.

**Solution**: See [guides/certificate-renewal-issues.md](guides/certificate-renewal-issues.md) for detailed fixes.

**Quick fix**:
```bash
# Delete old manual certificates (if not needed)
sudo certbot delete --cert-name OLD_CERT_NAME

# Or migrate to DNS automation (recommended)
sudo certbot certonly --force-renewal --dns-cloudflare \
  --dns-cloudflare-credentials ~/.secrets/cloudflare.ini \
  -d '*.example.com' -d 'example.com'
```

### Other Issues

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) and [CLAUDE.md](CLAUDE.md) for detailed troubleshooting steps.

### Common Issues

**"Permission denied" on certificate files**
```bash
sudo chmod 644 ssl/example.dev.key
docker compose restart traefik
```

**DNS not resolving**
- Wait 5-10 minutes for DNS propagation
- Clear DNS cache: `sudo dscacheutil -flushcache` (macOS)
- Verify with: `dig traefik.example.dev`

**Certificate validation errors in browser**
- Make sure you're using `fullchain.pem` (not `cert.pem`)
- Verify certificate: `openssl x509 -in ssl/example.dev.crt -text -noout`

## Understanding File Formats

**PEM vs CRT/KEY**: They're the same format! PEM (Privacy Enhanced Mail) is a Base64-encoded format. The extensions are just conventions:
- `.pem` - Generic PEM file (can contain cert, key, or both)
- `.crt` - Certificate file (public key + metadata)
- `.key` - Private key file
- `.cert` - Alternative to `.crt`

Let's Encrypt provides:
- `fullchain.pem` = Your certificate + intermediate CA certificates (use this!)
- `cert.pem` = Only your certificate (missing intermediate chain)
- `privkey.pem` = Your private key
- `chain.pem` = Just the intermediate CA certificates

Traefik expects:
- Certificate file with intermediate chain → rename `fullchain.pem` to `.crt`
- Private key → rename `privkey.pem` to `.key`

## Team Distribution

Need to share certificates with team members? See [guides/certificate-distribution.md](guides/certificate-distribution.md) for secure distribution options:

- Private Git repository (recommended for small teams)
- Encrypted archives
- git-crypt (encrypted Git)
- Secret management tools (Vault, 1Password)
- Individual certificate generation

## Summary

You now have:
- ✓ Wildcard DNS: `*.example.dev → 172.16.123.1`
- ✓ Valid SSL certificate from Let's Encrypt
- ✓ Traefik reverse proxy running locally
- ✓ HTTPS access to local services
- ✓ Automatic certificate renewal (optional)

Add new services by connecting them to the `local` Docker network and adding Traefik labels!
