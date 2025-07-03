#!/bin/bash

# Bulk mailbox creation script for iRedMail with MySQL password parameter
# Usage: /opt/iRedMail/tools/bulk_create_mailboxes_sql_with_pass.sh <file_path> <mysql_root_password>

if [ $# -ne 2 ]; then
    echo "Usage: $0 <file_path> <mysql_root_password>"
    echo "Example: $0 /opt/mail_list.txt mysql_root_pass"
    echo ""
    echo "File format (CSV): email,password"
    echo "Example file content:"
    echo "r.mansour@atosgenerators.com,ATOSGen2026!!"
    echo "user2@atosgenerators.com,password456"
    exit 1
fi

FILE_PATH="$1"
MYSQL_ROOT_PASSWD="$2"

if [ ! -f "$FILE_PATH" ]; then
    echo "Error: File $FILE_PATH not found!"
    exit 1
fi

echo "Starting bulk mailbox creation from: $FILE_PATH"
echo "=================================================="

# Test database connection first
DB_TEST=$(mysql -u root -p"$MYSQL_ROOT_PASSWD" -s -N -e "SELECT 1;" 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "✗ Failed to connect to database. Please check your MySQL credentials."
    exit 1
fi

echo "✓ Database connection successful"

# Counters
TOTAL_USERS=0
SUCCESSFUL_USERS=0
FAILED_USERS=0
SKIPPED_USERS=0

# Read file and create users
while IFS=',' read -r email password || [ -n "$email" ]; do
    # Skip empty lines
    if [[ -z "$email" ]]; then
        continue
    fi
    
    # Clean up any whitespace and carriage returns
    email=$(echo "$email" | tr -d ' \r\n')
    password=$(echo "$password" | tr -d ' \r\n')
    
    # Skip if email is empty after cleanup
    if [[ -z "$email" ]]; then
        continue
    fi
    
    TOTAL_USERS=$((TOTAL_USERS + 1))
    
    echo "Processing [$TOTAL_USERS]: $email"
    
    # Check if user already exists
    USER_EXISTS=$(mysql -u root -p"$MYSQL_ROOT_PASSWD" -s -N -e "SELECT COUNT(*) FROM vmail.mailbox WHERE username='$email';" 2>/dev/null)
    
    if [ "$USER_EXISTS" -gt 0 ]; then
        echo "⚠ User $email already exists. Skipping."
        SKIPPED_USERS=$((SKIPPED_USERS + 1))
        echo "---"
        continue
    fi
    
    # Generate SQL commands using the existing script
    SQL_COMMANDS=$(/opt/iRedMail/tools/create_mail_user_SQL.sh "$email" "$password" 2>/dev/null)
    
    # Modify the SQL to set unlimited quota (0 = unlimited) and add language field
    SQL_COMMANDS=$(echo "$SQL_COMMANDS" | sed "s/'1024'/'0'/g")
    SQL_COMMANDS=$(echo "$SQL_COMMANDS" | sed "s/created)/created, language)/g")
    SQL_COMMANDS=$(echo "$SQL_COMMANDS" | sed "s/NOW())/NOW(), 'en_US')/g")
    
    if [ $? -ne 0 ]; then
        echo "✗ Failed to generate SQL for: $email"
        FAILED_USERS=$((FAILED_USERS + 1))
        echo "---"
        continue
    fi
    
    # Execute SQL commands with provided password
    echo "$SQL_COMMANDS" | mysql -u root -p"$MYSQL_ROOT_PASSWD" vmail 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "✓ Created mailbox: $email"
        SUCCESSFUL_USERS=$((SUCCESSFUL_USERS + 1))
        
        # Extract domain and maildir
        DOMAIN=$(echo "$email" | cut -d'@' -f2)
        MAILDIR=$(echo "$SQL_COMMANDS" | grep -o "'$DOMAIN/[^']*" | tr -d "'" | head -1)
        
        # Create physical mail directory
        if [ -n "$MAILDIR" ]; then
            mkdir -p "/var/vmail/$MAILDIR"/{cur,new,tmp}
            chown -R vmail:vmail "/var/vmail/$DOMAIN/"
            chmod -R 0700 "/var/vmail/$DOMAIN/"
            echo "✓ Created directory: /var/vmail/$MAILDIR"
        fi
    else
        echo "✗ Failed to create: $email"
        FAILED_USERS=$((FAILED_USERS + 1))
    fi
    
    echo "---"
    sleep 1
    
done < "$FILE_PATH"

echo "=================================================="
echo "Bulk creation summary:"
echo "Total users processed: $TOTAL_USERS"
echo "Successfully created: $SUCCESSFUL_USERS"
echo "Already existed (skipped): $SKIPPED_USERS"
echo "Failed: $FAILED_USERS"
echo "=================================================="

if [ $FAILED_USERS -gt 0 ]; then
    echo "Some users failed to create. Please check the output above."
    exit 1
else
    echo "All users processed successfully!"
fi