# Troubleshooting Guide

Common issues and solutions for the Traefik local development environment.

## Certificate Issues

### Manual Certificate Renewal Failures

**Symptom**: Renewal fails with error:
```
Failed to renew certificate with error: The manual plugin is not working
PluginError('An authentication script must be provided with --manual-auth-hook...')
```

**Cause**: Certificates generated with `certbot --manual` cannot auto-renew.

**Solution**: See [guides/certificate-renewal-issues.md](guides/certificate-renewal-issues.md) for detailed fixes.

**Quick fix**:
```bash
# Delete old manual certificates
sudo certbot delete --cert-name OLD_CERT_NAME

# OR migrate to DNS automation
sudo certbot certonly --force-renewal --dns-cloudflare \
  --dns-cloudflare-credentials ~/.secrets/cloudflare.ini \
  -d '*.example.dev' -d 'example.dev'
```

### TLS Certificate Store Not Found

**Symptom**: Traefik logs show:
```
TLS: No certificate store found with this name: "default"
Error: open /etc/ssl/example.dev.key: permission denied
```

**Cause**: SSL key file has incorrect permissions.

**Solution**:
```bash
# Fix permissions
sudo chmod 644 ssl/example.dev.key ssl/example.dev.crt

# Restart Traefik
docker compose restart traefik
```

### Certificate Validation Errors in Browser

**Symptom**: Browser shows "NET::ERR_CERT_INVALID" or similar.

**Solutions**:
1. **Check you're using fullchain**: Must use `fullchain.pem`, not `cert.pem`
   ```bash
   openssl x509 -in ssl/example.dev.crt -text -noout | grep "Issuer:"
   ```

2. **Verify certificate is valid**:
   ```bash
   openssl x509 -in ssl/example.dev.crt -noout -dates
   ```

3. **Check certificate matches domain**:
   ```bash
   openssl x509 -in ssl/example.dev.crt -noout -text | grep DNS:
   # Should show: DNS:*.example.dev
   ```

## DNS Resolution Issues

### ERR_NAME_NOT_RESOLVED

**Symptom**: Browser cannot resolve `*.example.dev` domains.

**Check DNS resolution**:
```bash
# Test DNS
dig traefik.example.dev
# Should return: 172.16.123.1

# Check system DNS cache
dscacheutil -q host -a name traefik.example.dev
```

**Solutions**:

1. **Wait for DNS propagation** (5-10 minutes after DNS changes)

2. **Flush DNS cache**:
   ```bash
   # macOS
   sudo dscacheutil -flushcache
   sudo killall -HUP mDNSResponder

   # Linux
   sudo systemd-resolve --flush-caches
   ```

3. **Check VPN interference**: Disconnect VPN or configure split-DNS

4. **Verify DNS A record**: Should be `*.example.dev → 172.16.123.1`

### VPN Blocking Local Resolution

**Symptom**: Works without VPN, fails with VPN connected.

**Check**:
```bash
# View DNS configuration
scutil --dns | head -20

# Test with VPN DNS
dig @127.0.0.1 traefik.example.dev
```

**Solution**: VPN is configured correctly if corporate DNS can resolve public domains. No action needed.

## Loopback Alias Issues

### Alias Not Active

**Symptom**: `ifconfig` doesn't show `172.16.123.1`.

**Check**:
```bash
# macOS
ifconfig lo0 | grep 172.16.123.1

# Linux
ifconfig lo | grep 172.16.123.1
```

**Solutions**:

**macOS**:
```bash
# Check LaunchDaemon status
sudo launchctl list | grep runlevel1

# Reinstall
sudo make remove-loopback
sudo make create-loopback

# Check logs
tail -f /var/log/loopback-alias.log
```

**Linux**:
```bash
# Check systemd service (if configured)
systemctl status loopback-alias

# Manual setup
sudo ifconfig lo:0 172.16.123.1 netmask 255.240.0.0 up
```

### Alias Doesn't Persist After Reboot

**macOS**:
```bash
# Verify LaunchDaemon is loaded
sudo launchctl list | grep runlevel1
# Should show com.runlevel1.lo0.172.16.123.1

# Check plist exists
ls -la /Library/LaunchDaemons/com.runlevel1*

# Reinstall if needed
sudo make create-loopback
```

**Linux**:
```bash
# Check if systemd service is enabled
systemctl is-enabled loopback-alias

# Enable if not
sudo systemctl enable loopback-alias
```

## Traefik Issues

### Traefik Not Starting

**Check container status**:
```bash
docker compose ps
docker compose logs traefik --tail=50
```

**Common causes**:

1. **Port already in use**:
   ```bash
   # Check what's using port 80/443
   sudo lsof -i :80
   sudo lsof -i :443
   ```

2. **Configuration error**:
   ```bash
   # Validate config
   docker compose config
   ```

3. **Missing network**:
   ```bash
   # Create external network
   make create-network
   ```

### Cannot Access Dashboard

**URL**: https://traefik.example.dev/dashboard/

**Checks**:
```bash
# 1. Verify Traefik is running
docker compose ps

# 2. Test direct connection
curl -k https://traefik.example.dev

# 3. Check Traefik router configuration
docker compose logs traefik | grep dashboard
```

### Services Not Accessible Through Traefik

**Symptom**: Traefik dashboard works, but application services don't.

**Check**:
1. **Service connected to `local` network**:
   ```yaml
   networks:
     local:
       external: true
   ```

2. **Traefik labels configured**:
   ```yaml
   labels:
     traefik.enable: true
     traefik.http.routers.myapp.rule: "Host(`myapp.example.dev`)"
     traefik.http.routers.myapp.tls: true
   ```

3. **Service is running**:
   ```bash
   docker compose ps
   ```

## Platform-Specific Issues

### macOS: Permission Denied Errors

Most scripts require `sudo` on macOS:
```bash
# Correct usage
sudo make create-loopback
sudo make setup-certs
sudo make setup-auto-renewal

# NOT: make create-loopback (will fail)
```

### macOS: Homebrew Python PEP 668 Error

**Symptom**: `pip install` blocked with "externally-managed-environment" error.

**Solution**:
```bash
# Use --break-system-packages for certbot plugins
python3 -m pip install --break-system-packages certbot-dns-cloudflare
```

See [guides/cloudflare-dns-plugin.md](guides/cloudflare-dns-plugin.md) for details.

### Linux: Systemd Service Not Found

Some scripts are macOS-specific (LaunchDaemons). Linux equivalents TBD.

**Current workaround**: Use manual setup or cron jobs.

## Getting Help

1. **Check logs**:
   ```bash
   # Traefik logs
   docker compose logs traefik --tail=100 -f

   # Loopback LaunchDaemon logs (macOS)
   tail -f /var/log/loopback-alias.log

   # Certificate renewal logs (macOS)
   tail -f /var/log/certbot-renew.log

   # Let's Encrypt logs
   sudo cat /var/log/letsencrypt/letsencrypt.log
   ```

2. **Verify setup**:
   ```bash
   # DNS
   dig traefik.example.dev

   # Loopback
   ifconfig lo0 | grep 172.16.123.1  # macOS
   ifconfig lo | grep 172.16.123.1   # Linux

   # Certificates
   openssl x509 -in ssl/example.dev.crt -noout -dates

   # Docker
   docker compose ps
   docker network ls | grep local
   ```

3. **Check documentation**:
   - [SETUP.md](SETUP.md) - Initial setup guide
   - [CLAUDE.md](CLAUDE.md) - Development reference
   - [guides/](guides/) - Detailed guides

4. **Reset and start fresh**:
   ```bash
   make destroy
   make create
   ```
