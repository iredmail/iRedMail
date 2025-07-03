#!/bin/bash

# Check if a user is completely deleted from all tables
# Usage: /opt/iRedMail/tools/check_user_deletion.sh <email> <mysql_root_password>

if [ $# -ne 2 ]; then
    echo "Usage: $0 <email> <mysql_root_password>"
    echo "Example: $0 alex@atosgenerators.com mysql_root_pass"
    exit 1
fi

EMAIL="$1"
MYSQL_ROOT_PASSWD="$2"

echo "Checking deletion status for: $EMAIL"
echo "===================================="

# Test database connection
mysql -u root -p"$MYSQL_ROOT_PASSWD" -e "SELECT 1;" vmail >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "✗ Failed to connect to database"
    exit 1
fi

echo "✓ Database connection successful"
echo ""

# Get all tables in vmail database
TABLES=$(mysql -u root -p"$MYSQL_ROOT_PASSWD" -s -N vmail -e "SHOW TABLES;" 2>/dev/null)

echo "Checking all tables for user: $EMAIL"
echo "------------------------------------"

FOUND_IN_TABLES=""
TOTAL_REFERENCES=0

# Check each table for the user
for table in $TABLES; do
    echo -n "Checking table '$table'... "
    
    # Get all columns for this table
    COLUMNS=$(mysql -u root -p"$MYSQL_ROOT_PASSWD" -s -N vmail -e "
        SELECT COLUMN_NAME FROM information_schema.COLUMNS 
        WHERE TABLE_SCHEMA='vmail' AND TABLE_NAME='$table';
    " 2>/dev/null)
    
    FOUND_IN_TABLE=false
    
    # Check common column names that might contain the email
    for column in $COLUMNS; do
        if [[ "$column" == "username" || "$column" == "address" || "$column" == "email" || "$column" == "user" ]]; then
            COUNT=$(mysql -u root -p"$MYSQL_ROOT_PASSWD" -s -N vmail -e "
                SELECT COUNT(*) FROM $table WHERE $column='$EMAIL';
            " 2>/dev/null)
            
            if [ "$COUNT" -gt 0 ]; then
                echo "FOUND ($COUNT records in column '$column')"
                FOUND_IN_TABLES="$FOUND_IN_TABLES $table"
                TOTAL_REFERENCES=$((TOTAL_REFERENCES + COUNT))
                FOUND_IN_TABLE=true
                break
            fi
        fi
    done
    
    if [ "$FOUND_IN_TABLE" = false ]; then
        echo "✓ Clean"
    fi
done

echo ""
echo "===================================="
echo "Deletion Check Summary"
echo "===================================="

if [ $TOTAL_REFERENCES -eq 0 ]; then
    echo "✅ SUCCESS: User $EMAIL is completely deleted!"
    echo "✅ No references found in any table"
else
    echo "❌ INCOMPLETE: User $EMAIL still exists in $TOTAL_REFERENCES location(s)"
    echo "❌ Found in tables:$FOUND_IN_TABLES"
    echo ""
    echo "Detailed breakdown:"
    echo "-------------------"
    
    # Show details for each table where user was found
    for table in $FOUND_IN_TABLES; do
        echo "Table: $table"
        mysql -u root -p"$MYSQL_ROOT_PASSWD" -s -N vmail -e "
            SELECT COLUMN_NAME FROM information_schema.COLUMNS 
            WHERE TABLE_SCHEMA='vmail' AND TABLE_NAME='$table';
        " 2>/dev/null | while read column; do
            if [[ "$column" == "username" || "$column" == "address" || "$column" == "email" || "$column" == "user" ]]; then
                COUNT=$(mysql -u root -p"$MYSQL_ROOT_PASSWD" -s -N vmail -e "
                    SELECT COUNT(*) FROM $table WHERE $column='$EMAIL';
                " 2>/dev/null)
                
                if [ "$COUNT" -gt 0 ]; then
                    echo "  - Column '$column': $COUNT records"
                fi
            fi
        done
        echo ""
    done
fi

echo ""
echo "Physical Directory Check:"
echo "------------------------"
DOMAIN=$(echo "$EMAIL" | cut -d'@' -f2)
if [ -d "/var/vmail/$DOMAIN" ]; then
    MAIL_DIRS=$(find "/var/vmail/$DOMAIN" -name "*$(echo "$EMAIL" | cut -d'@' -f1)*" -type d 2>/dev/null)
    if [ -n "$MAIL_DIRS" ]; then
        echo "❌ Mail directories still exist:"
        echo "$MAIL_DIRS"
    else
        echo "✅ No mail directories found"
    fi
else
    echo "✅ Domain directory doesn't exist or is empty"
fi
