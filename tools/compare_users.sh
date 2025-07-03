#!/bin/bash

# Script to compare database entries between GUI-created and script-created users
# Usage: ./compare_users.sh <mysql_root_password>

if [ $# -ne 1 ]; then
    echo "Usage: $0 <mysql_root_password>"
    exit 1
fi

MYSQL_ROOT_PASSWD="$1"
OUTPUT_FILE="user_comparison_$(date +%Y%m%d_%H%M%S).txt"

echo "Comparing database entries for alex@atosgenerators.com vs test@atosgenerators.com"
echo "Output will be saved to: $OUTPUT_FILE"
echo "========================================================================"

# Redirect all output to both console and file
exec > >(tee "$OUTPUT_FILE")

echo "Database Comparison Report - $(date)"
echo "Comparing alex@atosgenerators.com (script-created) vs test@atosgenerators.com (GUI-created)"
echo "========================================================================"

# Check mailbox table
echo "=== MAILBOX TABLE ==="
mysql -u root -p"$MYSQL_ROOT_PASSWD" -e "
SELECT username, name, quota, bytes, messages, active, local_part, domain, created, modified, expired, accesspolicy 
FROM vmail.mailbox 
WHERE username IN ('alex@atosgenerators.com', 'test@atosgenerators.com');" 2>/dev/null

# Check alias table
echo -e "\n=== ALIAS TABLE ==="
mysql -u root -p"$MYSQL_ROOT_PASSWD" -e "
SELECT address, goto, name, active, created, modified, expired 
FROM vmail.alias 
WHERE address IN ('alex@atosgenerators.com', 'test@atosgenerators.com');" 2>/dev/null

# Check forwardings table
echo -e "\n=== FORWARDINGS TABLE ==="
mysql -u root -p"$MYSQL_ROOT_PASSWD" -e "
SELECT address, forwarding, domain, dest_domain, active, created, modified 
FROM vmail.forwardings 
WHERE address IN ('alex@atosgenerators.com', 'test@atosgenerators.com');" 2>/dev/null

# Check domain_admins table
echo -e "\n=== DOMAIN_ADMINS TABLE ==="
mysql -u root -p"$MYSQL_ROOT_PASSWD" -e "
SELECT username, domain, created, active 
FROM vmail.domain_admins 
WHERE username IN ('alex@atosgenerators.com', 'test@atosgenerators.com');" 2>/dev/null

# Check user_settings table if it exists
echo -e "\n=== USER_SETTINGS TABLE ==="
mysql -u root -p"$MYSQL_ROOT_PASSWD" -e "
SELECT user, pref, value 
FROM vmail.user_settings 
WHERE user IN ('alex@atosgenerators.com', 'test@atosgenerators.com');" 2>/dev/null

# Check mailbox table structure to see all columns
echo -e "\n=== MAILBOX TABLE STRUCTURE ==="
mysql -u root -p"$MYSQL_ROOT_PASSWD" -e "DESCRIBE vmail.mailbox;" 2>/dev/null

# Check what tables exist in vmail database
echo -e "\n=== ALL TABLES IN VMAIL DATABASE ==="
mysql -u root -p"$MYSQL_ROOT_PASSWD" -e "SHOW TABLES;" vmail 2>/dev/null

echo -e "\n========================================================================"
echo "Comparison completed! Output saved to: $OUTPUT_FILE"
echo "You can now share this file for analysis."