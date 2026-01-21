#!/bin/bash
#
# test-dedistracter.sh
#
# Test the efficacy of the block/unblock scripts using dig
# This script queries domains marked with 'scheduling' comment
# and shows whether they're blocked or unblocked
#
# Usage:
#   sudo ./test-dedistracter.sh [OPTIONS]
#
# Environment Variables:
#   PIHOLE_DNS_IP  - Pi Hole DNS IP address (default: 127.0.0.1)
#   PIHOLE_DB_PATH - Path to gravity.db (default: /etc/pihole/gravity.db)
#

# Configuration
PIHOLE_DNS_IP="${PIHOLE_DNS_IP:-127.0.0.1}"
PIHOLE_DB_PATH="${PIHOLE_DB_PATH:-/etc/pihole/gravity.db}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

show_help() {
    cat << 'EOF'
Usage: sudo ./test-dedistracter.sh [OPTIONS]

Test the efficacy of block/unblock scripts using dig queries.

OPTIONS:
  --help              Show this help message
  --dns IP            Pi Hole DNS IP address (default: 127.0.0.1)
  --db PATH           Path to gravity.db (default: /etc/pihole/gravity.db)
  --block             Test blocking (run block script and test)
  --unblock           Test unblocking (run unblock script and test)
  --full              Full test (block, test, unblock, test)
  --domain DOMAIN     Test specific domain

EXAMPLES:
  sudo ./test-dedistracter.sh --full
  sudo ./test-dedistracter.sh --block
  sudo ./test-dedistracter.sh --dns 192.168.1.100 --full
  sudo ./test-dedistracter.sh --domain youtube.com --full

EOF
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root (use sudo)${NC}" >&2
   exit 1
fi

# Check if dig is installed
if ! command -v dig &> /dev/null; then
    echo -e "${RED}Error: 'dig' not found. Install it with: sudo apt-get install dnsutils${NC}" >&2
    exit 1
fi

# Check if database exists
if [[ ! -f "$PIHOLE_DB_PATH" ]]; then
    echo -e "${RED}Error: Pi Hole database not found at $PIHOLE_DB_PATH${NC}" >&2
    exit 1
fi

# Get domains from database
get_scheduled_domains() {
    sqlite3 "$PIHOLE_DB_PATH" "SELECT DISTINCT domain FROM domainlist WHERE comment = 'scheduling' AND domain NOT LIKE '%|%' LIMIT 5;" 2>/dev/null || echo ""
}

# Flush DNS cache
flush_dns_cache() {
    # Flush Pi Hole DNS cache
    if command -v pihole &> /dev/null; then
        pihole reloaddns &> /dev/null || true
    fi
    # Also try flushing systemd DNS cache if available
    sudo systemctl restart systemd-resolved &> /dev/null || true
    # Add a small delay to ensure cache is flushed
    sleep 1
}

# Test DNS resolution
test_domain() {
    local domain=$1
    local expected_status=$2  # "blocked" or "unblocked"
    
    # Query the domain through Pi Hole
    local result=$(dig +short @"$PIHOLE_DNS_IP" "$domain" A 2>/dev/null || echo "")
    
    if [[ -z "$result" ]]; then
        # No result = blocked
        if [[ "$expected_status" == "blocked" ]]; then
            echo -e "${GREEN}✓ BLOCKED${NC}: $domain (no response)"
            return 0
        else
            echo -e "${RED}✗ FAILED${NC}: $domain (should be unblocked but got no response)"
            return 1
        fi
    else
        # Got a result = either unblocked or Pi Hole's response IP
        if echo "$result" | grep -q "^0\.0\.0\.0$\|^127\.0\.0\.1$"; then
            # Pi Hole's null response = blocked
            if [[ "$expected_status" == "blocked" ]]; then
                echo -e "${GREEN}✓ BLOCKED${NC}: $domain (response: $result)"
                return 0
            else
                echo -e "${RED}✗ FAILED${NC}: $domain (should be unblocked but got Pi Hole response: $result)"
                return 1
            fi
        else
            # Real IP = unblocked
            if [[ "$expected_status" == "unblocked" ]]; then
                echo -e "${GREEN}✓ UNBLOCKED${NC}: $domain (resolved to: $result)"
                return 0
            else
                echo -e "${RED}✗ FAILED${NC}: $domain (should be blocked but resolved to: $result)"
                return 1
            fi
        fi
    fi
}

# Parse arguments
TEST_MODE=""
SPECIFIC_DOMAIN=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_help
            exit 0
            ;;
        --dns)
            PIHOLE_DNS_IP="$2"
            shift 2
            ;;
        --db)
            PIHOLE_DB_PATH="$2"
            shift 2
            ;;
        --block)
            TEST_MODE="block"
            shift
            ;;
        --unblock)
            TEST_MODE="unblock"
            shift
            ;;
        --full)
            TEST_MODE="full"
            shift
            ;;
        --domain)
            SPECIFIC_DOMAIN="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Get domains to test
if [[ -n "$SPECIFIC_DOMAIN" ]]; then
    DOMAINS="$SPECIFIC_DOMAIN"
else
    DOMAINS=$(get_scheduled_domains)
fi

if [[ -z "$DOMAINS" ]]; then
    echo -e "${YELLOW}Warning: No domains with 'scheduling' comment found in database${NC}"
    echo "Add some domains to test with the comment 'scheduling'"
    exit 1
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Dedistracter DNS Efficacy Test${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Testing against: $PIHOLE_DNS_IP"
echo "Database: $PIHOLE_DB_PATH"
echo ""

# Initialize counters
passed=0
failed=0

case $TEST_MODE in
    block)
        echo -e "${BLUE}Running block script...${NC}"
        /opt/dedistracter/block-distractions.sh
        echo -e "${BLUE}Flushing DNS cache...${NC}"
        flush_dns_cache
        sleep 2
        echo ""
        echo -e "${BLUE}Testing blocked domains:${NC}"
        while IFS= read -r domain; do
            if test_domain "$domain" "blocked"; then
                ((passed++))
            else
                ((failed++))
            fi
        done <<< "$DOMAINS"
        ;;
    unblock)
        echo -e "${BLUE}Running unblock script...${NC}"
        /opt/dedistracter/unblock-distractions.sh
        echo -e "${BLUE}Flushing DNS cache...${NC}"
        flush_dns_cache
        sleep 2
        echo ""
        echo -e "${BLUE}Testing unblocked domains:${NC}"
        while IFS= read -r domain; do
            if test_domain "$domain" "unblocked"; then
                ((passed++))
            else
                ((failed++))
            fi
        done <<< "$DOMAINS"
        ;;
    full)
        # Block test
        echo -e "${BLUE}Step 1: Running block script...${NC}"
        /opt/dedistracter/block-distractions.sh
        echo -e "${BLUE}Flushing DNS cache...${NC}"
        flush_dns_cache
        sleep 2
        echo ""
        echo -e "${BLUE}Testing blocked domains:${NC}"
        while IFS= read -r domain; do
            if test_domain "$domain" "blocked"; then
                ((passed++))
            else
                ((failed++))
            fi
        done <<< "$DOMAINS"
        
        echo ""
        echo -e "${BLUE}Step 2: Running unblock script...${NC}"
        /opt/dedistracter/unblock-distractions.sh
        echo -e "${BLUE}Flushing DNS cache...${NC}"
        flush_dns_cache
        sleep 2
        echo ""
        echo -e "${BLUE}Testing unblocked domains:${NC}"
        while IFS= read -r domain; do
            if test_domain "$domain" "unblocked"; then
                ((passed++))
            else
                ((failed++))
            fi
        done <<< "$DOMAINS"
        ;;
    *)
        # No test mode specified, just show current status
        echo -e "${BLUE}Current domain status (from database):${NC}"
        echo ""
        while IFS= read -r domain; do
            enabled=$(sqlite3 "$PIHOLE_DB_PATH" "SELECT enabled FROM domainlist WHERE domain = '$domain' AND comment = 'scheduling' LIMIT 1;")
            if [[ "$enabled" == "1" ]]; then
                status="BLOCKED"
            else
                status="UNBLOCKED"
            fi
            echo -e "  $domain: $status"
        done <<< "$DOMAINS"
        exit 0
        ;;
esac

# Print summary
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Passed:  ${GREEN}$passed${NC}"
echo -e "Failed:  ${RED}$failed${NC}"
echo ""

if [[ $failed -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
