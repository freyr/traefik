# Cloudflare DNS Plugin Setup for Certbot

This guide shows how to setup automated certificate renewal using the Cloudflare DNS plugin.

## Benefits

- ✅ No manual DNS TXT record updates during renewal
- ✅ Fully automated renewals via cron/systemd timer
- ✅ No need to pause and update DNS during certificate issuance

## Installation

### macOS

**Important**: If you installed certbot via Homebrew (`brew install certbot`), Python plugins are tricky due to PEP 668. Choose one method:

#### Method 1: Use --break-system-packages (Simplest)
```bash
# Install plugin breaking Python environment protection
# This works with Homebrew's certbot but is not ideal
python3 -m pip install --break-system-packages certbot-dns-cloudflare
```

**Pros**: Simple, works immediately with `brew`-installed certbot
**Cons**: Bypasses Python environment protection

#### Method 2: Reinstall everything via pipx (Cleanest)
```bash
# Remove Homebrew certbot
brew uninstall certbot

# Install pipx
brew install pipx
pipx ensurepath

# Restart shell or run: source ~/.zshrc  (or ~/.bash_profile)

# Install certbot via pipx
pipx install certbot

# Add cloudflare plugin
pipx inject certbot certbot-dns-cloudflare
```

**Pros**: Proper isolated environment, no conflicts
**Cons**: Requires removing Homebrew certbot

#### Method 3: Virtual environment (Most isolated)
```bash
# Create isolated environment
python3 -m venv ~/certbot-venv
source ~/certbot-venv/bin/activate

# Install both certbot and plugin
pip install certbot certbot-dns-cloudflare

# Use full path to certbot
~/certbot-venv/bin/certbot --version
```

**Pros**: Completely isolated, no system changes
**Cons**: Must use full path or activate venv each time

#### Recommended Approach

For most users with Homebrew certbot already installed:
```bash
# Use --break-system-packages flag (yes, it's okay in this case)
python3 -m pip install --break-system-packages certbot-dns-cloudflare
```

This is acceptable because:
- You're only adding a plugin, not replacing system packages
- Certbot manages its own dependencies
- Easier than reinstalling everything

### Linux (Ubuntu/Debian)

```bash
sudo apt update
sudo apt install python3-certbot-dns-cloudflare
```

### Linux (RHEL/CentOS/Fedora)

```bash
sudo dnf install python3-certbot-dns-cloudflare
```

### Verify Installation

```bash
# If using pipx
pipx list | grep certbot

# Verify plugin is available
certbot plugins | grep cloudflare
# Should show: dns-cloudflare

# If cloudflare plugin not showing, ensure it's injected into certbot:
pipx inject certbot certbot-dns-cloudflare
```

## Create Cloudflare API Token

1. Log in to [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Go to: **My Profile** → **API Tokens** → **Create Token**
3. Use the **"Edit zone DNS"** template
4. Configure:
   - **Zone Resources**: Include → Specific zone → `example.dev`
   - **Client IP Address Filtering**: (optional) Add your IP for extra security
5. Click **Continue to summary** → **Create Token**
6. **Copy the token** (you won't see it again!)

## Configure Credentials File

```bash
# Create secure directory
mkdir -p ~/.secrets

# Save API token to file
cat > ~/.secrets/cloudflare.ini <<EOF
# Cloudflare API token
dns_cloudflare_api_token = YOUR_API_TOKEN_HERE
EOF

# Set restrictive permissions (certbot requires this)
chmod 600 ~/.secrets/cloudflare.ini
```

**Important**: Replace `YOUR_API_TOKEN_HERE` with your actual token!

## Generate Certificate (First Time)

```bash
sudo certbot certonly --dns-cloudflare \
  --dns-cloudflare-credentials ~/.secrets/cloudflare.ini \
  --dns-cloudflare-propagation-seconds 20 \
  -d '*.example.dev' \
  -d 'example.dev' \
  --email your-email@example.com \
  --agree-tos
```

**Parameters explained:**
- `--dns-cloudflare`: Use Cloudflare DNS plugin
- `--dns-cloudflare-credentials`: Path to credentials file
- `--dns-cloudflare-propagation-seconds`: Wait time for DNS propagation (default: 10, increase if needed)
- `-d`: Domains to include (can use multiple `-d` flags)
- `--email`: Your email for renewal notifications
- `--agree-tos`: Accept Let's Encrypt Terms of Service

## Copy Certificates to Traefik

After successful generation:

```bash
sudo ./setup-certificates.sh
docker compose restart traefik
```

## Test Automatic Renewal

```bash
# Dry run (doesn't actually renew)
sudo certbot renew --dry-run

# Check renewal configuration
sudo cat /etc/letsencrypt/renewal/example.dev.conf
```

## Setup Automatic Renewal Hook

```bash
make install-renew-hook
```

This installs a hook that automatically:
1. Copies renewed certificates to `ssl/` directory
2. Sets correct permissions
3. Restarts Traefik

## Setup Automatic Renewal

### macOS

Homebrew's certbot doesn't auto-configure renewal. Set it up manually:

```bash
# Install automatic renewal LaunchDaemon
cd /path/to/traefik
make setup-auto-renewal

# Verify it's running
make check-renewal-status
# OR
sudo launchctl list | grep certbot

# View logs
tail -f /var/log/certbot-renew.log
```

### Linux

Should be automatic via systemd, but verify:

```bash
# Check renewal timer
systemctl list-timers | grep certbot

# If not found, enable it
sudo systemctl enable certbot-renew.timer
sudo systemctl start certbot-renew.timer
```

## Verify Everything Works

```bash
# Check certificate expiry
openssl x509 -in ssl/example.dev.crt -noout -dates

# Test HTTPS
curl -k https://traefik.example.dev

# Test renewal (dry run)
sudo certbot renew --dry-run

# Check automatic renewal is configured
# macOS:
sudo launchctl list | grep certbot
# Linux:
systemctl list-timers | grep certbot
```

## Troubleshooting

### "Plugin not found"

```bash
# Verify plugin is installed
certbot plugins | grep cloudflare

# If not found, reinstall
sudo python3 -m pip install --force-reinstall certbot-dns-cloudflare
```

### "API token does not have permission"

- Verify token has **Zone:DNS:Edit** permission
- Verify zone is set to your domain (`example.dev`)
- Token may have expired - create a new one

### "DNS propagation timeout"

Increase propagation wait time:
```bash
sudo certbot certonly --dns-cloudflare \
  --dns-cloudflare-credentials ~/.secrets/cloudflare.ini \
  --dns-cloudflare-propagation-seconds 60 \
  -d '*.example.dev' -d 'example.dev'
```

### "Permission denied" on credentials file

```bash
chmod 600 ~/.secrets/cloudflare.ini
# Make sure only root can read it when running with sudo
```

## Manual Renewal

To force renewal before expiry (e.g., after revoking a certificate):

```bash
sudo certbot renew --force-renewal --cert-name example.dev
sudo ./setup-certificates.sh
docker compose restart traefik
```

## Uninstall

```bash
# Remove plugin
sudo python3 -m pip uninstall certbot-dns-cloudflare

# Remove credentials (if desired)
rm ~/.secrets/cloudflare.ini

# Revoke and delete certificates (if desired)
sudo certbot revoke --cert-name example.dev
sudo certbot delete --cert-name example.dev
```

## Security Notes

- ✅ Keep your API token secure - it has DNS edit permissions
- ✅ Use a dedicated token (not Global API Key)
- ✅ Set `chmod 600` on credentials file
- ✅ Consider IP restrictions on the API token
- ✅ Regularly rotate tokens (Cloudflare doesn't enforce expiry)
- ❌ Never commit credentials files to git

## Additional Resources

- [Certbot Cloudflare Plugin Docs](https://certbot-dns-cloudflare.readthedocs.io/)
- [Cloudflare API Token Guide](https://developers.cloudflare.com/fundamentals/api/get-started/create-token/)
- [Let's Encrypt Rate Limits](https://letsencrypt.org/docs/rate-limits/)
