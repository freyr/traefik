# Certificate Management Scripts

Scripts for managing Let's Encrypt SSL certificates for Traefik.

## Files

### Certificate Installation
- **`setup-certificates.sh`** - Copy Let's Encrypt certificates to Traefik
  - Copies from `/etc/letsencrypt/live/` to `ssl/` directory
  - Sets correct permissions (644)
  - Converts PEM to CRT/KEY naming

### Automatic Renewal
- **`setup-auto-renewal.sh`** - Install automatic renewal LaunchDaemon (macOS)
  - Creates LaunchDaemon that runs `certbot renew` twice daily
  - Schedules at 00:00 and 12:00
  - Logs to `/var/log/certbot-renew.log`

- **`remove-auto-renewal.sh`** - Remove automatic renewal
  - Unloads LaunchDaemon
  - Removes plist file
  - Keeps log file

- **`com.certbot.renew.plist`** - LaunchDaemon configuration for automatic renewal

### Post-Renewal Hook
- **`renew-hook.sh`** - Runs after successful certificate renewal
  - Automatically copies new certificates to Traefik
  - Sets permissions
  - Restarts Traefik container
  - Install to: `/etc/letsencrypt/renewal-hooks/deploy/`

## Usage

### Initial Certificate Setup
```bash
# 1. Generate certificate (first time)
sudo certbot certonly --dns-cloudflare \
  --dns-cloudflare-credentials ~/.secrets/cloudflare.ini \
  -d '*.example.dev' -d 'example.dev'

# 2. Copy to Traefik
make setup-certs
# OR
sudo ./scripts/certificates/setup-certificates.sh

# 3. Restart Traefik
docker compose restart traefik
```

### Setup Automatic Renewal
```bash
# 1. Install post-renewal hook
make install-renew-hook

# 2. Setup automatic renewal scheduler (macOS)
make setup-auto-renewal
# OR
sudo ./scripts/certificates/setup-auto-renewal.sh

# 3. Verify
make check-renewal-status
tail -f /var/log/certbot-renew.log
```

### Manual Renewal
```bash
# Test renewal (dry run)
make test-renewal
# OR
sudo certbot renew --dry-run

# Force renewal
sudo certbot renew --force-renewal
```

## How It Works

### Automatic Renewal Flow (macOS)
1. **LaunchDaemon** runs twice daily (00:00, 12:00)
2. Executes: `certbot renew --quiet`
3. Certbot checks all certificates in `/etc/letsencrypt/renewal/`
4. If certificate expires within 30 days, renews it
5. After successful renewal, runs **post-hook**
6. Post-hook:
   - Copies `fullchain.pem` → `ssl/example.dev.crt`
   - Copies `privkey.pem` → `ssl/example.dev.key`
   - Sets permissions to 644
   - Restarts Traefik container

### Certificate File Mapping
```
Let's Encrypt:              Traefik:
/etc/letsencrypt/live/      ssl/
├── fullchain.pem    →      ├── example.dev.crt
└── privkey.pem      →      └── example.dev.key
```

**Important**: Use `fullchain.pem` (not `cert.pem`) to include intermediate certificates.

## Monitoring

### Check Renewal Status
```bash
# macOS: Check if LaunchDaemon is running
sudo launchctl list | grep certbot

# View renewal logs
tail -f /var/log/certbot-renew.log

# Check certificate expiry
openssl x509 -in ssl/example.dev.crt -noout -dates

# List all certificates
sudo certbot certificates
```

### Manual Testing
```bash
# Test renewal process
sudo certbot renew --dry-run

# Force immediate renewal
sudo certbot renew --force-renewal --cert-name example.dev
```

## Troubleshooting

### Renewal fails
```bash
# View detailed logs
sudo cat /var/log/letsencrypt/letsencrypt.log

# Check renewal configuration
sudo cat /etc/letsencrypt/renewal/example.dev.conf

# Verify certbot plugins
certbot plugins
```

### Post-hook not running
```bash
# Verify hook is installed
ls -la /etc/letsencrypt/renewal-hooks/deploy/

# Check hook permissions
sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/traefik-renew.sh

# Test hook manually
sudo /etc/letsencrypt/renewal-hooks/deploy/traefik-renew.sh
```

### Permission errors
```bash
# Fix certificate permissions
sudo chmod 644 ssl/example.dev.key ssl/example.dev.crt
sudo chown $USER:$(id -gn) ssl/example.dev.*

# Restart Traefik
docker compose restart traefik
```

## Security Notes

- Private keys (`*.key`) are sensitive - do not commit to git
- Automatic renewal requires root privileges (LaunchDaemon runs as root)
- Renewal logs contain no sensitive information
- Post-hook runs with certbot's privileges (root)

## Platform Differences

### macOS
- Uses LaunchDaemon for scheduling
- Manual setup required (Homebrew doesn't auto-configure)
- Scripts provided in this directory

### Linux
- Usually uses systemd timer
- Automatically configured by package manager
- May not need these scripts (but renewal hook is still useful)
