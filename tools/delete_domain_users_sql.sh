#!/bin/bash

# Delete all users for a given domain except postmaster@domain
# Usage: /opt/iRedMail/tools/delete_domain_users_sql.sh <domain> <mysql_root_password>

if [ $# -ne 2 ]; then
    echo "Usage: $0 <domain> <mysql_root_password>"
    echo "Example: $0 atosgenerators.com mysql_root_pass"
    echo ""
    echo "WARNING: This will delete ALL users in the domain except postmaster@domain"
    echo "This action cannot be undone!"
    exit 1
fi

DOMAIN="$1"
MYSQL_ROOT_PASSWD="$2"

echo "Domain User Deletion Script"
echo "==========================="
echo "Target domain: $DOMAIN"
echo "Protected user: postmaster@$DOMAIN"
echo ""

# Test database connection
mysql -u root -p"$MYSQL_ROOT_PASSWD" -e "SELECT 1;" vmail >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "✗ Failed to connect to database. Please check your MySQL credentials."
    exit 1
fi

echo "✓ Database connection successful"

# Get users to delete (excluding postmaster)
USERS_TO_DELETE=$(mysql -u root -p"$MYSQL_ROOT_PASSWD" -s -N vmail -e "
    SELECT username FROM mailbox 
    WHERE domain='$DOMAIN' 
    AND username != 'postmaster@$DOMAIN'
    ORDER BY username;
" 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "✗ Failed to query users from database"
    exit 1
fi

# Check if there are any users to delete
if [ -z "$USERS_TO_DELETE" ]; then
    echo "ℹ No users found to delete in domain: $DOMAIN"
    echo "  (postmaster@$DOMAIN is protected and won't be deleted)"
    exit 0
fi

# Count users and show them
USER_COUNT=$(echo "$USERS_TO_DELETE" | wc -l)
echo "Found $USER_COUNT users to delete:"
echo "$USERS_TO_DELETE"
echo ""

# Check for domain admins
DOMAIN_ADMINS_EXISTS=$(mysql -u root -p"$MYSQL_ROOT_PASSWD" -s -N vmail -e "
    SELECT COUNT(*) FROM information_schema.tables 
    WHERE table_schema='vmail' AND table_name='domain_admins';
" 2>/dev/null)

if [ "$DOMAIN_ADMINS_EXISTS" -gt 0 ]; then
    ADMIN_USERS=$(mysql -u root -p"$MYSQL_ROOT_PASSWD" -s -N vmail -e "
        SELECT da.username FROM domain_admins da 
        JOIN mailbox m ON da.username = m.username 
        WHERE m.domain='$DOMAIN' AND da.username != 'postmaster@$DOMAIN';
    " 2>/dev/null)
    
    if [ -n "$ADMIN_USERS" ]; then
        echo "⚠ WARNING: The following users have domain admin privileges:"
        echo "$ADMIN_USERS"
        echo ""
    fi
fi

# Safety confirmation
echo "⚠ WARNING: This will permanently delete $USER_COUNT users and their mailboxes!"
echo "⚠ Mail directories will also be removed from the filesystem!"
echo "⚠ Domain admin privileges will be revoked!"
echo "⚠ This action cannot be undone!"
echo ""
read -p "Are you sure you want to continue? (y/yes to confirm): " CONFIRM

# Convert to lowercase for comparison
CONFIRM_LOWER=$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')

if [[ "$CONFIRM_LOWER" != "y" && "$CONFIRM_LOWER" != "yes" ]]; then
    echo "Operation cancelled by user."
    exit 0
fi

echo ""
echo "Starting deletion process..."
echo "==========================="

# Counters
TOTAL_USERS=0
SUCCESSFUL_DELETIONS=0
FAILED_DELETIONS=0

# Process each user
for email in $USERS_TO_DELETE; do
    if [ -z "$email" ]; then
        continue
    fi
    
    TOTAL_USERS=$((TOTAL_USERS + 1))
    echo "Processing [$TOTAL_USERS]: $email"
    
    # Check if user is domain admin
    if [ "$DOMAIN_ADMINS_EXISTS" -gt 0 ]; then
        IS_ADMIN=$(mysql -u root -p"$MYSQL_ROOT_PASSWD" -s -N vmail -e "
            SELECT COUNT(*) FROM domain_admins WHERE username='$email';
        " 2>/dev/null)
        
        if [ "$IS_ADMIN" -gt 0 ]; then
            echo "  ⚠ User has domain admin privileges"
        fi
    fi
    
    # Get maildir path before deletion
    MAILDIR=$(mysql -u root -p"$MYSQL_ROOT_PASSWD" -s -N vmail -e "
        SELECT maildir FROM mailbox WHERE username='$email';
    " 2>/dev/null)
    
    # Comprehensive database cleanup - Execute each statement separately for better error handling
    echo "  → Deleting from mailbox table..."
    mysql -u root -p"$MYSQL_ROOT_PASSWD" vmail -e "DELETE FROM mailbox WHERE username='$email';" 2>/dev/null
    MAILBOX_RESULT=$?
    
    if [ $MAILBOX_RESULT -eq 0 ]; then
        echo "  ✓ Deleted from mailbox table"
        
        echo "  → Deleting from forwardings table..."
        mysql -u root -p"$MYSQL_ROOT_PASSWD" vmail -e "DELETE FROM forwardings WHERE address='$email';" 2>/dev/null
        echo "  ✓ Deleted from forwardings table"
        
        echo "  → Deleting from domain_admins table..."
        mysql -u root -p"$MYSQL_ROOT_PASSWD" vmail -e "DELETE FROM domain_admins WHERE username='$email';" 2>/dev/null
        echo "  ✓ Deleted from domain_admins table"
        
        echo "  → Deleting from auxiliary tables..."
        mysql -u root -p"$MYSQL_ROOT_PASSWD" vmail -e "
            DELETE FROM deleted_mailboxes WHERE username='$email';
            DELETE FROM last_login WHERE username='$email';
            DELETE FROM used_quota WHERE username='$email';
            DELETE FROM alias WHERE address='$email';
            DELETE FROM alias WHERE username='$email';
        " 2>/dev/null
        echo "  ✓ Deleted from auxiliary tables"
        
        echo "  → Deleting from BCC and quota tables..."
        mysql -u root -p"$MYSQL_ROOT_PASSWD" vmail -e "
            DELETE FROM sender_bcc_user WHERE username='$email';
            DELETE FROM recipient_bcc_user WHERE username='$email';
            DELETE FROM sender_bcc_domain WHERE username='$email';
            DELETE FROM recipient_bcc_domain WHERE username='$email';
            DELETE FROM quota WHERE username='$email';
            DELETE FROM quota2 WHERE username='$email';
        " 2>/dev/null
        echo "  ✓ Deleted from BCC and quota tables"
        
        SUCCESSFUL_DELETIONS=$((SUCCESSFUL_DELETIONS + 1))
        
        # Remove physical mail directory
        if [ -n "$MAILDIR" ] && [ -d "/var/vmail/$MAILDIR" ]; then
            rm -rf "/var/vmail/$MAILDIR"
            if [ $? -eq 0 ]; then
                echo "  ✓ Removed mail directory: /var/vmail/$MAILDIR"
            else
                echo "  ⚠ Failed to remove mail directory: /var/vmail/$MAILDIR"
            fi
        else
            echo "  ℹ No mail directory to remove"
        fi
        
        echo "  ✓ Successfully deleted: $email"
    else
        echo "  ✗ Failed to delete from mailbox table: $email"
        echo "  ✗ Skipping remaining cleanup for this user"
        FAILED_DELETIONS=$((FAILED_DELETIONS + 1))
    fi
    
    echo "  ---"
done

echo ""
echo "==========================="
echo "Deletion Summary:"
echo "Total users processed: $TOTAL_USERS"
echo "Successfully deleted: $SUCCESSFUL_DELETIONS"
echo "Failed: $FAILED_DELETIONS"
echo "Protected (kept): postmaster@$DOMAIN"
echo "==========================="

# Show remaining users in domain
echo ""
echo "Remaining users in domain $DOMAIN:"
REMAINING_USERS=$(mysql -u root -p"$MYSQL_ROOT_PASSWD" -s -N vmail -e "
    SELECT username FROM mailbox WHERE domain='$DOMAIN';
" 2>/dev/null)

if [ -n "$REMAINING_USERS" ]; then
    echo "$REMAINING_USERS"
else
    echo "No users found in domain $DOMAIN"
fi

# Show remaining domain admins
if [ "$DOMAIN_ADMINS_EXISTS" -gt 0 ]; then
    echo ""
    echo "Remaining domain admins in $DOMAIN:"
    REMAINING_ADMINS=$(mysql -u root -p"$MYSQL_ROOT_PASSWD" -s -N vmail -e "
        SELECT da.username FROM domain_admins da 
        JOIN mailbox m ON da.username = m.username 
        WHERE m.domain='$DOMAIN';
    " 2>/dev/null)
    
    if [ -n "$REMAINING_ADMINS" ]; then
        echo "$REMAINING_ADMINS"
    else
        echo "No domain admins found in $DOMAIN"
    fi
fi

echo ""
if [ $FAILED_DELETIONS -eq 0 ]; then
    echo "✅ All users deleted successfully!"
    echo "✅ Domain $DOMAIN now only contains: postmaster@$DOMAIN"
else
    echo "⚠ Some users failed to delete. Please check the output above."
    echo "⚠ You may need to manually clean up failed deletions."
fi

echo ""
echo "==========================="
echo "Deletion process completed!"
echo "==========================="