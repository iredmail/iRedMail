# Additional Management Tools

This directory contains additional management scripts for iRedMail server administration.

## Prerequisites

- iRedMail server installed and running
- MySQL/MariaDB root password
- Scripts must be executable: `chmod +x *.sh`

## Tools Overview

### 1. Single User Creation
**Script:** `create_and_execute_mail_user_SQL.sh`  
**Purpose:** Create a single mailbox with unlimited quota

```bash
./create_and_execute_mail_user_SQL.sh user@example.com password123 mysql_root_password
```

### 2. Bulk User Creation
**Script:** `bulk_create_mailboxes_sql.sh`  
**Purpose:** Create multiple users from CSV file

```bash
# Create CSV file with format: email,password
# Example: users.csv
# user1@example.com,password123
# user2@example.com,password456

./bulk_create_mailboxes_sql.sh /path/to/users.csv mysql_root_password
```

### 3. Domain User Deletion
**Script:** `delete_domain_users_sql.sh`  
**Purpose:** Delete all users in a domain except postmaster

```bash
./delete_domain_users_sql.sh example.com mysql_root_password
```

**⚠️ WARNING:** This permanently deletes users and their mail data!

### 4. User Deletion Verification
**Script:** `check_user_deletion.sh`  
**Purpose:** Verify if a user is completely removed from all database tables

```bash
./check_user_deletion.sh user@example.com mysql_root_password
```

### 5. User Comparison
**Script:** `compare_users.sh`  
**Purpose:** Compare database entries between users for troubleshooting

```bash
./compare_users.sh mysql_root_password
```

Saves comparison results to a timestamped file.
