#!/bin/bash

# Single user creation script for iRedMail with MySQL password parameter
# Usage: /opt/iRedMail/tools/create_and_execute_mail_user_SQL_with_pass.sh <email> <password> <mysql_root_password>

if [ $# -ne 3 ]; then
    echo "Usage: $0 <email> <password> <mysql_root_password>"
    echo "Example: $0 test1@atosgenerators.com password123 mysql_root_pass"
    exit 1
fi

EMAIL="$1"
PASSWORD="$2"
MYSQL_ROOT_PASSWD="$3"

echo "Creating mailbox for: $EMAIL"
echo "=================================="

# Check if user already exists
USER_EXISTS=$(mysql -u root -p"$MYSQL_ROOT_PASSWD" -s -N -e "SELECT COUNT(*) FROM vmail.mailbox WHERE username='$EMAIL';" 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "✗ Failed to connect to database. Please check your MySQL credentials."
    exit 1
fi

if [ "$USER_EXISTS" -gt 0 ]; then
    echo "⚠ User $EMAIL already exists. Skipping creation."
    echo "✓ No action needed."
    exit 0
fi

# Generate SQL commands using the existing script
SQL_COMMANDS=$(/opt/iRedMail/tools/create_mail_user_SQL.sh "$EMAIL" "$PASSWORD")

# Modify the SQL to set unlimited quota (0 = unlimited) and add language field
SQL_COMMANDS=$(echo "$SQL_COMMANDS" | sed "s/'1024'/'0'/g")
SQL_COMMANDS=$(echo "$SQL_COMMANDS" | sed "s/created)/created, language)/g")
SQL_COMMANDS=$(echo "$SQL_COMMANDS" | sed "s/NOW())/NOW(), 'en_US')/g")

if [ $? -ne 0 ]; then
    echo "✗ Failed to generate SQL commands"
    exit 1
fi

# Execute the SQL commands with provided password
echo "$SQL_COMMANDS" | mysql -u root -p"$MYSQL_ROOT_PASSWD" vmail

if [ $? -eq 0 ]; then
    echo "✓ Successfully created mailbox: $EMAIL"
    
    # Extract domain and maildir path from SQL output
    DOMAIN=$(echo "$EMAIL" | cut -d'@' -f2)
    MAILDIR=$(echo "$SQL_COMMANDS" | grep -o "'$DOMAIN/[^']*" | tr -d "'" | head -1)
    
    # Create physical mail directory structure
    if [ -n "$MAILDIR" ]; then
        mkdir -p "/var/vmail/$MAILDIR"/{cur,new,tmp}
        chown -R vmail:vmail "/var/vmail/$DOMAIN/"
        chmod -R 0700 "/var/vmail/$DOMAIN/"
        echo "✓ Created mail directory: /var/vmail/$MAILDIR"
    fi
    
    echo "✓ Mailbox creation completed successfully!"
else
    echo "✗ Failed to create mailbox: $EMAIL"
    echo "Please check your database connection and credentials."
    exit 1
fi