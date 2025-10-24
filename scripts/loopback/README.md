# Loopback Alias Scripts

Scripts for managing the loopback alias on different operating systems. The IP address is configured via the `LOOPBACK_IP` variable in `.env` file.

## Files

### macOS
- **`add-alias.sh`** - Install loopback alias via LaunchDaemon
  - Generates LaunchDaemon from template using `.env` configuration
  - Creates persistent alias that survives reboots
  - Installs to `/Library/LaunchDaemons/`
  - Logs to `/var/log/loopback-alias.log`

- **`remove-alias.sh`** - Remove loopback alias
  - Unloads LaunchDaemon
  - Removes plist file
  - Removes active alias

- **`loopback-alias.plist.template`** - LaunchDaemon template
  - Used to generate the actual plist with configured IP
  - Variables: `{{LABEL}}`, `{{LOOPBACK_IP}}`

### Linux
- **`add-alias-linux.sh`** - Setup loopback alias on Linux
  - Generates systemd service from template using `.env` configuration
  - Creates persistent alias that survives reboots
  - Installs to `/etc/systemd/system/`

- **`loopback-alias.service.template`** - Systemd service template
  - Used to generate the actual service with configured IP
  - Variables: `{{LOOPBACK_IP}}`, `{{LOOPBACK_NETMASK}}`

## Usage

### macOS
```bash
# Ensure .env is configured first
cp .env.example .env
nano .env  # Set LOOPBACK_IP

# Setup (via Makefile - recommended)
make create-loopback

# Setup (direct)
sudo ./scripts/loopback/add-alias.sh

# Remove
sudo make remove-loopback
# OR
sudo ./scripts/loopback/remove-alias.sh

# Verify (replace with your LOOPBACK_IP)
ifconfig lo0 | grep 172.16.123.1
```

### Linux
```bash
# Ensure .env is configured first
cp .env.example .env
nano .env  # Set LOOPBACK_IP

# Setup
sudo ./scripts/loopback/add-alias-linux.sh

# Verify (replace with your LOOPBACK_IP)
ifconfig lo | grep 172.16.123.1
```

## How It Works

### macOS LaunchDaemon
1. Script reads `LOOPBACK_IP` from `.env` file
2. Generates plist from template with configured IP
3. Copies generated plist to `/Library/LaunchDaemons/com.runlevel1.lo0.{IP}.plist`
4. Sets ownership to root:wheel
5. Loads via `launchctl bootstrap`
6. LaunchDaemon runs at boot time
7. Executes: `ifconfig lo0 alias {LOOPBACK_IP}`

### Linux Systemd Service
1. Script reads `LOOPBACK_IP` and `LOOPBACK_NETMASK` from `.env` file
2. Generates service file from template
3. Copies to `/etc/systemd/system/loopback-alias.service`
4. Enables and starts via systemd
5. Service runs at boot time
6. Executes: `ifconfig lo:0 {LOOPBACK_IP} netmask {LOOPBACK_NETMASK} up`

### Default IP Configuration
- Default `LOOPBACK_IP`: `172.16.123.1`
- Default `LOOPBACK_NETMASK`: `255.240.0.0`
- `172.16.123.1` is in RFC1918 private range (172.16.0.0/12)
- Chosen to avoid conflicts with common private networks:
  - Not in 10.0.0.0/8 (common for home routers)
  - Not in 192.168.0.0/16 (most common home range)
  - Not in 172.17.0.0/16 (Docker default)
- Used by DNS to resolve `*.example.dev` for local development
- **You can change this** by editing `LOOPBACK_IP` in `.env`

## Troubleshooting

### macOS: LaunchDaemon not loading
```bash
# Check if already loaded
sudo launchctl list | grep runlevel1

# Check system logs
tail -f /var/log/loopback-alias.log

# Find the generated plist file
ls -la /Library/LaunchDaemons/com.runlevel1*

# Manual load (replace with actual plist name)
sudo launchctl bootstrap system /Library/LaunchDaemons/com.runlevel1.lo0.172_16_123_1.plist
```

### Alias not persisting after reboot
- Verify LaunchDaemon is loaded: `sudo launchctl list | grep runlevel1`
- Check plist file exists: `ls -la /Library/LaunchDaemons/com.runlevel1*`
- Check plist permissions: should be `644 root:wheel`
- Verify `.env` file is configured correctly

### Linux: Service not starting
```bash
# Check service status
sudo systemctl status loopback-alias

# Check systemd logs
sudo journalctl -u loopback-alias

# Restart service
sudo systemctl restart loopback-alias
```

### IP already in use or conflicts with network
If the default `172.16.123.1` conflicts with your network:

1. **Choose a different IP** from RFC1918 private ranges:
   - `10.0.0.0/8` (avoid common router IPs like 10.0.0.1)
   - `172.16.0.0/12` (avoid 172.17.0.0/16 used by Docker)
   - `192.168.0.0/16` (avoid common home ranges)

2. **Update `.env` file**:
   ```bash
   nano .env
   # Change: LOOPBACK_IP=172.20.123.1  # or your chosen IP
   ```

3. **Update DNS A record** to point to the new IP

4. **Remove old alias and reinstall**:
   ```bash
   sudo make remove-loopback
   sudo make create-loopback
   ```

5. **Regenerate configs**:
   ```bash
   make check-env
   ```
