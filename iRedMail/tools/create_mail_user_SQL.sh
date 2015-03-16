#!/usr/bin/env bash

# Author:   Zhang Huangbin (zhb _at_ iredmail.org)
# Purpose:  Import users to MySQL database from plain text file.
# Project:  iRedMail (http://www.iredmail.org/)

# -------------------------------------------------------------------
# Usage:
#   * Edit these variables:
#       STORAGE_BASE_DIRECTORY
#       DEFAULT_PASSWD='888888'
#       USE_DEFAULT_PASSWD='NO'
#       DEFAULT_QUOTA='100'   # 100 -> 100M
#
#   * Run this script to generate SQL files used to import to MySQL
#     database later.
#
#       # bash create_mail_user_MySQL.sh domain.ltd user [user1 user2 user3 ...]
#
#     It will generate file 'output.sql' in current directory, open
#     it and confirm all records are correct.
#
#   * Import output.sql into MySQL database.
#
#       # mysql -uroot -p
#       mysql> USE vmail;
#       mysql> SOURCE /path/to/output.sql;
#
#   That's all.
# -------------------------------------------------------------------

# ChangeLog:
#   - 2009.05.07 Add hashed maildir style support.
#   - Improve file detect.
#   - Drop output message of 'which dos2unix'.

# --------- CHANGE THESE VALUES ----------
# Storage base directory used to store users' mail.
STORAGE_BASE_DIRECTORY="/var/vmail/vmail1"

# Password setting.
# Note: password will be crypted in MD5.
DEFAULT_PASSWD='88888888'
USE_DEFAULT_PASSWD='NO'     # If set to 'NO', password is the same as username.

# Default mail quota.
DEFAULT_QUOTA='100'   # 100 -> 100M

# -------------- You may not need to change variables below -------------------
# Mailbox format: mbox, Maildir.
MAILBOX_FORMAT='Maildir'

# ---- Maildir settings ----
# Maildir style: hashed, normal.
# Hashed maildir style, so that there won't be many large directories
# in your mail storage file system. Better performance in large scale
# deployment.
# Format: e.g. username@domain.td
#   hashed  -> domain.ltd/u/us/use/username/
#   normal  -> domain.ltd/username/
# Default hash level is 3.
MAILDIR_STYLE='hashed'      # hashed, normal.

# Time stamp, will be appended in maildir.
DATE="$(date +%Y.%m.%d.%H.%M.%S)"

STORAGE_BASE="$(dirname ${STORAGE_BASE_DIRECTORY})"
STORAGE_NODE="$(basename ${STORAGE_BASE_DIRECTORY})"

# Path to SQL template file.
SQL="output.sql"
echo '' > ${SQL}

# Cyrpt the password.
if [ X"${USE_DEFAULT_PASSWD}" == X"YES" ]; then
    export CRYPT_PASSWD="$(openssl passwd -1 ${DEFAULT_PASSWD})"
else
    :
fi

generate_sql()
{
    # Get domain name.
    DOMAIN="$1"
    shift 1

    for i in $@; do
        username="$i"
        mail="${username}@${DOMAIN}"

        if [ X"${USE_DEFAULT_PASSWD}" != X"YES" ]; then
            export CRYPT_PASSWD="$(openssl passwd -1 ${username})"
        else
            :
        fi

        # Different maildir style: hashed, normal.
        if [ X"${MAILDIR_STYLE}" == X"hashed" ]; then
            length="$(echo ${username} | wc -L)"
            str1="$(echo ${username} | cut -c1)"
            str2="$(echo ${username} | cut -c2)"
            str3="$(echo ${username} | cut -c3)"

            if [ X"${length}" == X"1" ]; then
                str2="${str1}"
                str3="${str1}"
            elif [ X"${length}" == X"2" ]; then
                str3="${str2}"
            else
                :
            fi

            # Use mbox, will be changed later.
            maildir="${DOMAIN}/${str1}/${str2}/${str3}/${username}-${DATE}"
        else
            # Use mbox, will be changed later.
            maildir="${DOMAIN}/${username}-${DATE}"
        fi

        # Different maildir format: maildir, mbox.
        if [ X"${MAILBOX_FORMAT}" == X"Maildir" ]; then
            # Append slash to make it 'maildir' format.
            maildir="${maildir}/"
        else
            # It's already mbox format.
            :
        fi

        cat >> ${SQL} <<EOF
INSERT INTO mailbox (username, password, name, storagebasedirectory,storagenode, maildir, quota, domain, active, local_part, created)
    VALUES ('${mail}', '${CRYPT_PASSWD}', '${username}', '${STORAGE_BASE}','${STORAGE_NODE}', '${maildir}', '${DEFAULT_QUOTA}', '${DOMAIN}', '1','${username}', NOW());
INSERT INTO alias (address, goto, domain, created, active) VALUES ('${mail}', '${mail}','${DOMAIN}', NOW(), 1);
EOF
    done
}

if [ $# -lt 2 ]; then
    echo "Usage: $0 domain_name username [user2 user3 user4 ...]"
else
    # Generate SQL template.
    generate_sql $@ && \
    cat <<EOF

SQL template file was generated successfully, Please import it
*MANUALLY* after verify the records:

    - ${SQL}

Steps to import these users looks like below:

    # mysql -uroot -p
    mysql> USE vmail;
    mysql> SOURCE ${SQL};

Or, PostgreSQL:

    # su - postgres
    $ psql -d vmail
    sql> \i ${SQL};

EOF
fi
