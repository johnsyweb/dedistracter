# Dedistracter Build and Installation Guide

This document explains how to build and install dedistracter as a Debian package.

## Prerequisites

You'll need `devscripts` and `debhelper` to build the package:

```bash
sudo apt-get update
sudo apt-get install devscripts debhelper
```

## Building the Package

### On macOS/Windows using Docker BuildKit (Recommended):

Docker BuildKit provides efficient cross-platform builds with direct file export.

```bash
# Navigate to the dedistracter directory
cd /path/to/dedistracter

# Make the build script executable
chmod +x build-deb.sh

# Build the package
./build-deb.sh

# Output will be in ./build-output/
ls -la build-output/
```

**Build for specific architectures:**

```bash
# 64-bit Raspberry Pi (Pi 4/5)
./build-deb.sh --arm64

# 32-bit Raspberry Pi (Pi 0/1/2/3)
./build-deb.sh --armhf
```

**Note:** BuildKit automatically handles cross-compilation based on the target platform specified.

**Other build options:**

```bash
./build-deb.sh --help       # Show all options
./build-deb.sh --clean      # Remove Docker image and build artifacts
```

### On Raspbian/Debian directly:

If you're building on a Raspberry Pi or Debian system:

```bash
# Clone or navigate to the dedistracter directory
cd /path/to/dedistracter

# Ensure build dependencies are installed
sudo apt-get install devscripts debhelper

# Build the package (unsigned, for local installation)
dpkg-buildpackage -us -uc

# The .deb file will be created in the parent directory
cd ..
ls -la dedistracter_*.deb
```

### Cross-compiling on Debian/Raspbian:

```bash
# For a different architecture
dpkg-buildpackage -a arm64 -us -uc  # For 64-bit Pi
# or
dpkg-buildpackage -a armhf -us -uc  # For 32-bit Pi
```

## Installation

### Install the Package

```bash
sudo dpkg -i dedistracter_1.0.0_all.deb
```

The package will:
1. Create `/opt/dedistracter/` with the scripts
2. Create `/etc/default/dedistracter` with default configuration
3. Automatically add cron entries to run the scripts at configured times

### Verify Installation

```bash
# Check if scripts are installed
ls -la /opt/dedistracter/

# Check the configuration file
cat /etc/default/dedistracter

# View installed cron jobs
crontab -l
```

## Configuration

### Setting Up Scheduled Domains

1. **Via Pi Hole Web Interface:**
   - Go to Admin Panel → Adlists
   - Add your distraction domains individually or as blocklists
   - For each domain/list, add the comment: `scheduling`
   - Save and update the gravity database

2. **Via Command Line:**

   ```bash
   # Add a domain with the 'scheduling' comment
   sqlite3 /etc/pihole/gravity.db <<EOF
   INSERT INTO domainlist (domain, type, enabled, comment)
   VALUES ('youtube.com', 1, 1, 'scheduling');
   EOF
   ```

### Changing Blocking Times

Edit `/etc/default/dedistracter` and set your desired times:

```bash
sudo nano /etc/default/dedistracter
```

Modify these variables:
- `BLOCK_HOUR` - 24-hour format (0-23)
- `BLOCK_MINUTE` - Minutes (0-59)
- `UNBLOCK_HOUR` - 24-hour format (0-23)
- `UNBLOCK_MINUTE` - Minutes (0-59)

For example, to block at 9 AM and unblock at 5 PM:

```bash
BLOCK_HOUR=9
BLOCK_MINUTE=0
UNBLOCK_HOUR=17
UNBLOCK_MINUTE=0
```

Then reinstall or manually update crontab:

```bash
sudo crontab -e
```

Update the times in the cron entries accordingly.

## Reinstalling with New Configuration

If you've modified `/etc/default/dedistracter` and want to regenerate cron entries:

```bash
# Remove old entries manually or reinstall
sudo apt-get install --reinstall dedistracter
```

## Uninstallation

```bash
sudo apt-get remove dedistracter

# This will:
# - Remove the scripts from /opt/dedistracter/
# - Remove cron entries
# - Keep /etc/default/dedistracter for reference
```

To completely remove all traces:

```bash
sudo apt-get purge dedistracter
sudo rm -rf /opt/dedistracter /etc/default/dedistracter
```

## Testing

### Test the scripts with DNS queries:

The best way to verify the scripts work is to use `dig` to query domains through Pi Hole:

```bash
# Install dnsutils if needed
sudo apt-get install dnsutils

# Full test: block, verify, unblock, verify
sudo /opt/dedistracter/test-dedistracter.sh --full

# Test just blocking
sudo /opt/dedistracter/test-dedistracter.sh --block

# Test just unblocking
sudo /opt/dedistracter/test-dedistracter.sh --unblock

# Test a specific domain
sudo /opt/dedistracter/test-dedistracter.sh --domain youtube.com --full

# Show current status without running tests
sudo /opt/dedistracter/test-dedistracter.sh
```

### Manual testing:

If you prefer to test manually:

```bash
# Test blocking
sudo /opt/dedistracter/block-distractions.sh

# Query a domain through Pi Hole (should get no response or 0.0.0.0)
dig @127.0.0.1 youtube.com +short

# Check database status
sqlite3 /etc/pihole/gravity.db "SELECT domain, enabled FROM domainlist WHERE comment = 'scheduling';"

# Test unblocking
sudo /opt/dedistracter/unblock-distractions.sh

# Query the same domain (should resolve normally)
dig @127.0.0.1 youtube.com +short
```

### Monitor Pi Hole:

Check the Pi Hole logs to verify domains are being blocked:

```bash
# View real-time logs
tail -f /var/log/pihole/pihole.log

# Or check the gravity log
sudo journalctl -u pihole-FTL -f
```

### Check cron execution:

```bash
# View cron logs
sudo grep CRON /var/log/syslog | tail -20

# Or on systems with journalctl
sudo journalctl -u cron -n 50
```

## Troubleshooting

### "command not found" errors

Ensure the full path is used in crontab. The package handles this, but if you're setting up manually:

```crontab
0 2 * * * /bin/bash -lc '/opt/dedistracter/block-distractions.sh'
```

### Cron jobs not running

1. Verify cron is enabled: `sudo systemctl status cron`
2. Check logs: `sudo grep CRON /var/log/syslog`
3. Verify paths exist: `ls -la /opt/dedistracter/`

### Database permission errors

The scripts need to be run as root (or with sudo) because Pi Hole's database requires elevated privileges:

```bash
sudo crontab -e  # Edit root's crontab
```

### Changes not taking effect

1. Verify domains have the correct comment in the database:
   ```bash
   sqlite3 /etc/pihole/gravity.db "SELECT domain, comment FROM domainlist WHERE comment = 'scheduling';"
   ```

2. Manually run the script to check for errors:
   ```bash
   sudo /opt/dedistracter/block-distractions.sh
   ```

3. Check if Pi Hole DNS is running:
   ```bash
   sudo systemctl status pihole-FTL
   ```

## Building Packages for Different Architectures

From a Raspberry Pi, the default `dpkg-buildpackage -us -uc` will build for the current architecture.

To build explicitly:

```bash
# 64-bit (Pi 4/5)
dpkg-buildpackage -a arm64 -us -uc

# 32-bit (Pi 0/1/2/3/3B+)
dpkg-buildpackage -a armhf -us -uc
```

## Advanced: Manual Cron Configuration

If you prefer to manage cron entries manually:

```bash
# Edit root's crontab
sudo crontab -e

# Add entries like:
0 2 * * * /bin/bash -lc '/opt/dedistracter/block-distractions.sh'
0 20 * * * /bin/bash -lc '/opt/dedistracter/unblock-distractions.sh'
```

The times are specified as:
- Minute (0-59)
- Hour (0-23)
- Day of month (1-31)
- Month (1-12)
- Day of week (0-6, Sunday is 0)
