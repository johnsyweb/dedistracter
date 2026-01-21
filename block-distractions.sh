#!/bin/bash
#
# block-distractions.sh
#
# This script enables all distraction domains that have been marked for scheduling.
# It queries the Pi Hole gravity database and updates the status of domains
# that are tagged with the 'scheduling' comment.
#
# Usage: ./block-distractions.sh
#
# Environment Variables:
#   PIHOLE_DB_PATH - Path to gravity.db (default: /etc/pihole/gravity.db)
#

set -e

# Configuration
PIHOLE_DB_PATH="${PIHOLE_DB_PATH:-/etc/pihole/gravity.db}"

echo 'Blocking distractions...'

# Ensure required commands are available
export PATH="$PATH:/usr/sbin:/usr/local/bin/"

# Check if database exists
if [[ ! -f "$PIHOLE_DB_PATH" ]]; then
    echo "Error: Pi Hole database not found at $PIHOLE_DB_PATH" >&2
    exit 1
fi

# In Pi Hole v6+, update the domainlist to enable domains with 'scheduling' comment
# The enabled column: 1 = enabled (block), 0 = disabled (don't block)
sqlite3 "$PIHOLE_DB_PATH" "UPDATE domainlist SET enabled = 1 WHERE comment = 'scheduling';"

# Force Pi Hole to reload the gravity database
if command -v pihole &> /dev/null; then
    pihole reloaddns
else
    # If pihole command not available, restart FTL directly
    sudo systemctl restart pihole-FTL 2>/dev/null || true
fi

echo 'Distractions are now blocked.'
