# Dedistracter Development

This document provides information for developers and contributors.

## Project Structure

```
dedistracter/
├── block-distractions.sh          # Enable distraction domains
├── unblock-distractions.sh        # Disable distraction domains
├── dedistracter-cron-generator    # Utility to generate cron entries
├── README.md                       # User documentation
├── INSTALL.md                      # Build and installation guide
├── LICENSE                         # MIT License
├── debian/                         # Debian packaging
│   ├── control                    # Package metadata
│   ├── rules                      # Build rules
│   ├── postinst                   # Post-installation script
│   ├── prerm                      # Pre-removal script
│   ├── copyright                  # Copyright information
│   ├── changelog                  # Version history
│   ├── compat                     # debhelper compatibility version
│   └── dedistracter.default       # Default configuration
└── DEVELOP.md                      # This file
```

## Design Decisions

### Why Shell Scripts?

- Minimal dependencies
- Works directly on Raspberry Pi
- Easy to audit and understand
- Directly integrates with cron
- No need for Python or other interpreters

### Database Approach

The scripts use SQLite directly instead of Pi Hole's API because:
- More reliable in cron context
- Simpler error handling
- Guaranteed atomicity
- Works offline if needed

### Comment-based Filtering

We use a `scheduling` comment in the domainlist to identify which domains should be affected:
- Easy to identify in the UI
- Allows mixed manual and scheduled domains
- Survives gravity updates
- Clear intent

## Pi Hole v6 Database Schema

Dedistracter is designed from the ground up for Pi Hole v6:
- Uses `gravity.db` SQLite database
- Interacts with `domainlist` table
- Relies on `enabled` column (1 = blocked, 0 = unblocked)
- Uses `comment` field for domain filtering

Our scripts are built with Pi Hole v6 in mind:
- Explicit error checking
- Path configuration via env variables
- Proper error messages
- Handles database locking gracefully

## Testing

### Manual Testing

```bash
# Add test domains
sqlite3 /etc/pihole/gravity.db <<EOF
INSERT INTO domainlist (domain, type, enabled, comment)
VALUES 
  ('example-block.local', 1, 1, 'scheduling'),
  ('example-unblock.local', 1, 0, 'scheduling');
EOF

# Test blocking
./block-distractions.sh

# Verify
sqlite3 /etc/pihole/gravity.db "SELECT domain, enabled FROM domainlist WHERE comment = 'scheduling';"

# Test unblocking
./unblock-distractions.sh

# Verify
sqlite3 /etc/pihole/gravity.db "SELECT domain, enabled FROM domainlist WHERE comment = 'scheduling';"
```

### Integration Testing

```bash
# Build the package
dpkg-buildpackage -us -uc

# Install in a test environment or VM
sudo dpkg -i ../dedistracter_*.deb

# Verify installation
sudo /opt/dedistracter/block-distractions.sh
sudo /opt/dedistracter/unblock-distractions.sh

# Check cron entries
crontab -l

# Simulate cron execution (as root)
sudo bash -lc '/opt/dedistracter/block-distractions.sh'
```

## Contributing

### Areas for Improvement

1. **Systemd service integration**
   - Create a systemd timer instead of cron

2. **Configuration UI**
   - Web interface to set times and domains

3. **Logging**
   - Better logging to syslog

4. **Testing framework**
   - Automated test suite
   - CI/CD pipeline

5. **Documentation**
   - Video tutorials
   - Troubleshooting guide expansion

6. **Multiple schedule sets**
   - Different schedules for different days
   - Holiday exceptions

### Code Style

- Bash scripts use `set -e` for error handling
- Explicit error messages to stderr (`>&2`)
- Double-quoted variables
- Comments for non-obvious code
- No fancy bash features (maintain compatibility)

### Testing Changes

Before submitting changes:

```bash
# Lint shell scripts
shellcheck block-distractions.sh
shellcheck unblock-distractions.sh
shellcheck dedistracter-cron-generator

# Test on Raspberry Pi if possible
# Build package and test installation
```

## Version History

### v1.0.0 (Current)
- Initial release
- Pi Hole v6 support
- Debian package
- Environment variable configuration

### Future Versions

- v1.1.0: Systemd timer support
- v2.0.0: Configuration API
- v2.1.0: Advanced scheduling (e.g., per-day configuration)

## Contact

For issues, questions, or contributions, please visit:
https://github.com/johnsyweb/dedistracter
