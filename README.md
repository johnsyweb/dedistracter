# Dedistracter - Pi Hole Distraction Blocker

Automatically schedule blocking and unblocking of distracting websites using Pi Hole on a Raspberry Pi.

## What is it?

Dedistracter provides simple scheduling scripts to automatically disable distracting websites (like YouTube) during work hours and re-enable them during personal time. It works with [Pi Hole v6+](https://pi-hole.net/) to manage domain blocking via cron jobs.

## Features

- 🎯 Block/unblock specific domains on a schedule
- ⏰ Configurable blocking times via environment variables
- 📦 Debian package for easy installation on Raspbian
- 🔧 Minimal dependencies (bash, sqlite3, Pi Hole)
- 🚀 Purpose-built for Pi Hole v6+

## Installation

### Option 1: Using the Debian Package (Recommended)

**On macOS/Windows using Docker BuildKit:**

```bash
# Make the build script executable
chmod +x build-deb.sh

# Build the package
./build-deb.sh

# Output will be in ./build-output/
# Install on your Raspberry Pi
scp build-output/*.deb root@pi.hole:/tmp/
ssh root@pi.hole sudo dpkg -i /tmp/*.deb
```

**On Raspberry Pi or Debian directly:**

```bash
# Build the package
sudo apt-get install devscripts debhelper
dpkg-buildpackage -us -uc

# Install
sudo dpkg -i ../dedistracter_*.deb

# Configure scheduling times (see Configuration section)
sudo systemctl restart cron
```

### Option 2: Manual Installation

```bash
sudo mkdir -p /opt/dedistracter
sudo cp block-distractions.sh /opt/dedistracter/
sudo cp unblock-distractions.sh /opt/dedistracter/
sudo chmod +x /opt/dedistracter/*.sh
```

## Setup

### 1. Create domains to block in Pi Hole

In the Pi Hole admin panel, add the domains you want to block with the **comment** `scheduling`. For example:

```
youtube.com
youtu.be
m.youtube.com
```

Add these as adlists or via the API, ensuring each has the comment set to `scheduling`.

### 2. Configure scheduling

The package installs a cron job template. Configure the blocking/unblocking times using environment variables:

```bash
Edit `/etc/default/dedistracter` (created by the package) to set your schedule. For example:

BLOCK_HOUR=2
BLOCK_MINUTE=0
UNBLOCK_HOUR=20
UNBLOCK_MINUTE=0

After editing, run:
```bash
sudo /opt/dedistracter/dedistracter-cron-generator
```
Your new schedule will take effect automatically. **Note:** `/etc/default/dedistracter` is a Debian conffile, so your changes will be preserved during package upgrades.
```

Or manually add to crontab:

```crontab
# Block distractions at 2:00 AM
0 2 * * * /opt/dedistracter/block-distractions.sh

# Unblock distractions at 8:00 PM
0 20 * * * /opt/dedistracter/unblock-distractions.sh
```

### 3. Verify setup

Test the scripts with DNS queries:

```bash
# Full test: block, verify DNS, unblock, verify DNS
sudo /opt/dedistracter/test-dedistracter.sh --full

# Or test just blocking
sudo /opt/dedistracter/test-dedistracter.sh --block

# Check Pi Hole logs
sudo journalctl -u pihole-FTL -n 50
```

## Configuration

### Environment Variables

Both scripts support the following environment variables:

- `PIHOLE_DB_PATH` - Path to Pi Hole's gravity.db (default: `/etc/pihole/gravity.db`)

```bash
PIHOLE_DB_PATH=/custom/path/gravity.db /opt/dedistracter/block-distractions.sh
```

## What changed in Pi Hole v6?

Pi Hole v6 uses the same `gravity.db` SQLite database, but the scripts have been updated to:
- Include better error handling
- Support custom database paths
- Work reliably with v6+ schema

## Requirements

- Raspberry Pi (or any Debian-based system)
- Pi Hole v6 or later
- `sudo` access or root
- `sqlite3` command-line tool (usually pre-installed)
- `bash` 4.0+

## Troubleshooting

### Scripts don't run from cron

Ensure the full path is used and environment is set:

```crontab
0 2 * * * /bin/bash -lc '/opt/dedistracter/block-distractions.sh'
```

### "Database is locked" error

This usually means Pi Hole is updating the database. The scripts have retry logic, but if issues persist, check if Pi Hole is running:

```bash
sudo systemctl status pihole-FTL
```

### Changes don't take effect

Verify the domains have the `scheduling` comment in Pi Hole:

```bash
sqlite3 /etc/pihole/gravity.db "SELECT domain, comment, enabled FROM domainlist WHERE comment = 'scheduling';"
```

## License

MIT License - See LICENSE file for details

## Contributing

Contributions are welcome! Please submit issues and pull requests on [GitHub](https://github.com/johnsyweb/dedistracter).
