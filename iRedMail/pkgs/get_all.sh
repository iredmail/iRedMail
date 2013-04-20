#!/usr/bin/env bash

# Author:   Zhang Huangbin (zhb _at_ iredmail.org)
# Purpose:  Fetch all extra packages we need to build mail server.

#---------------------------------------------------------------------
# This file is part of iRedMail, which is an open source mail server
# solution for Red Hat(R) Enterprise Linux, CentOS, Debian and Ubuntu.
#
# iRedMail is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# iRedMail is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with iRedMail.  If not, see <http://www.gnu.org/licenses/>.
#---------------------------------------------------------------------

ROOTDIR="$(pwd)"
CONF_DIR="${ROOTDIR}/../conf"

. ${CONF_DIR}/global
. ${CONF_DIR}/core
. ${CONF_DIR}/iredadmin

# Re-define @STATUS_FILE, so that iRedMail.sh can read it.
export STATUS_FILE="${ROOTDIR}/../.status"

check_user root
check_hostname

# Where to fetch/store binary packages and source tarball.
export IREDMAIL_MIRROR="${IREDMAIL_MIRROR:=http://iredmail.org}"
export PKG_DIR="${ROOTDIR}/pkgs"
export MISC_DIR="${ROOTDIR}/misc"

if [ X"${DISTRO}" == X"RHEL" ]; then
    # Special package.
    # command: which.
    export BIN_WHICH='which'
    export PKG_WHICH="which${PKG_ARCH}"
    # command: wget.
    export BIN_WGET='wget'
    export PKG_WGET="wget${PKG_ARCH}"

elif [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ]; then
    if [ X"${ARCH}" == X"x86_64" ]; then
        export pkg_arch='amd64'
    else
        export pkg_arch="${ARCH}"
    fi

    # Special package.
    # command: which.
    export BIN_WHICH='which'
    export PKG_WHICH="debianutils"
    # command: wget.
    export BIN_WGET='wget'
    export PKG_WGET="wget"
    # command: dpkg-scanpackages.
    export BIN_CREATEREPO="dpkg-scanpackages"
    export PKG_CREATEREPO="dpkg-dev"
fi

# Binary packages.
export pkg_total=$(echo ${PKGLIST} | wc -w | awk '{print $1}')
export pkg_counter=1

# Misc file (source tarball) list.
if [ X"${DISTRO}" == X"FREEBSD" ]; then
    PKGMISC='SHASUM.freebsd.misc'
elif [ X"${DISTRO}" == X"DEBIAN" -a X"${DISTRO_CODENAME}" == X"squeeze" ]; then
    PKGMISC='MD5.debian.squeeze'
elif [ X"${DISTRO}" == X"SUSE" ]; then
    PKGMISC='MD5.misc MD5.opensuse'
elif [ X"${DISTRO}" == X'OPENBSD' ]; then
    PKGMISC='MD5.openbsd'
else
    PKGMISC='MD5.misc'
fi
MISCLIST="$(cat ${ROOTDIR}/${PKGMISC} | awk -F'misc/' '{print $2}')"

prepare_dirs()
{
    ECHO_DEBUG "Creating necessary directories ..."
    for i in ${PKG_DIR} ${MISC_DIR}
    do
        [ -d "${i}" ] || mkdir -p "${i}"
    done
}

fetch_misc()
{
    # Fetch all misc packages.
    cd ${MISC_DIR}

    misc_total=$(( $(echo ${MISCLIST} | wc -w | awk '{print $1}') ))
    misc_count=1

    ECHO_INFO "Fetching source tarballs ..."

    for i in ${MISCLIST}; do
        url="${IREDMAIL_MIRROR}/yum/misc/${i}"
        ECHO_INFO "+ ${misc_count} of ${misc_total}: ${url}"

        ${FETCH_CMD} "${url}"

        misc_count=$((misc_count + 1))
    done
}

check_md5()
{
    cd ${ROOTDIR}

    if [ X"${DISTRO}" != X"FREEBSD" ]; then
        ECHO_INFO -n "Validate packages ..."

        md5file="/tmp/check_md5_tmp.${RANDOM}$RANDOM}"
        echo -e "${MD5LIST}" > ${md5file}
        cat ${PKGMISC} >> ${md5file}
        if [ X"${DISTRO}" == X'OPENBSD' ]; then
            md5 -c ${md5file} |grep 'FAILED'
            RETVAL="$?"
        else
            md5sum -c ${md5file} |grep 'FAILED'
            RETVAL="$?"
        fi
        rm -f ${md5file} 2>/dev/null

        if [ X"${RETVAL}" == X"0" ]; then
            echo -e "\t[ FAILED ]"
            ECHO_ERROR "MD5 check failed. Script exit ...\n"
            exit 255
        else
            echo -e "\t[ OK ]"
            echo 'export status_fetch_misc="DONE"' >> ${STATUS_FILE}
            echo 'export status_check_md5="DONE"' >> ${STATUS_FILE}
        fi
    fi
}

create_repo_rhel()
{
    # createrepo
    ECHO_INFO "Generating yum repository ..."

    # Backup old repo file.
    backup_file ${LOCAL_REPO_FILE}

    # Generate new repo file.
    cat > ${LOCAL_REPO_FILE} <<EOF
[${LOCAL_REPO_NAME}]
name=${LOCAL_REPO_NAME}
baseurl=${IREDMAIL_MIRROR}/yum/rpms/${DISTRO_VERSION}/
enabled=1
gpgcheck=0
EOF

    # Dovecot-1.2 for RHEL 5.
    if [ X"${DISTRO_VERSION}" == X"5" ]; then
        cat >> ${LOCAL_REPO_FILE} <<EOF
[iRedMail-Dovecot-12]
name=iRedMail-Dovecot-12
baseurl=${IREDMAIL_MIRROR}/yum/rpms/dovecot/rhel${DISTRO_VERSION}/
enabled=1
gpgcheck=0
EOF
    fi

    echo 'export status_create_yum_repo="DONE"' >> ${STATUS_FILE}
}

create_repo_suse()
{
    ECHO_INFO "Create zypper repo file: ${ZYPPER_REPOS_DIR}/${PROG_NAME}.repo."
    cat > ${ZYPPER_REPOS_DIR}/${PROG_NAME}.repo <<EOF
# Repository for packages:
#   - apache-mod_auth_mysql, apache-mod_wsgi
#   - Altermime, awstats
# Reference: http://iredmail.org/yum/opensuse/${DISTRO_VERSION}/README

[iRedMail]
name=iRedMail
baseurl=${IREDMAIL_MIRROR}/yum/opensuse/${DISTRO_VERSION}/
enabled=1
autorefresh=1
path=/
type=rpm-md
keeppackages=1
gpgcheck=0
EOF

}

check_new_iredmail()
{
    # Check new version and track basic information,
    # Used to help iRedMail team understand which Linux/BSD distribution
    # we should take more care of.
    # iRedMail version number, OS distribution, release version, code name, backend.
    ECHO_INFO "Checking new version of iRedMail ..."
    ${FETCH_CMD} "${IREDMAIL_MIRROR}/version/check.py/iredmail_os?iredmail_version=${PROG_VERSION}&arch=${ARCH}&distro=${DISTRO}&distro_version=${DISTRO_VERSION}&distro_code_name=${DISTRO_CODENAME}" &>/dev/null

    UPDATE_AVAILABLE='NO'
    if ls iredmail_os* &>/dev/null; then
        info="$(cat iredmail_os*)"
        if [ X"${info}" == X'UPDATE_AVAILABLE' ]; then
            UPDATE_AVAILABLE='YES'
        fi
    fi

    rm -f iredmail_os* &>/dev/null

    if [ X"${UPDATE_AVAILABLE}" == X'YES' ]; then
        echo ''
        ECHO_ERROR "Your iRedMail version (${PROG_VERSION}) is out of date, please"
        ECHO_ERROR "download the latest version and try again:"
        ECHO_ERROR "http://www.iredmail.org/download.html"
        echo ''
        exit 255
    fi

    echo 'export status_check_new_iredmail="DONE"' >> ${STATUS_FILE}
}

echo_end_msg()
{
    cat <<EOF
********************************************************
* All tasks had been finished successfully. Next step:
*
*   # cd ..
*   # bash ${PROG_NAME}.sh
*
********************************************************

EOF
}

if [ -e ${STATUS_FILE} ]; then
    . ${STATUS_FILE}
else
    echo '' > ${STATUS_FILE}
fi

# Check latest version
check_status_before_run check_new_iredmail

prepare_dirs

if [ X"${DISTRO}" == X"RHEL" ]; then
    # Clean metadata
    ECHO_INFO "Clean metadata of yum repositories."
    yum clean metadata

    # Create yum repository.
    create_repo_rhel

    # Check required commands, install related package if command doesn't exist.
    check_pkg ${BIN_WHICH} ${PKG_WHICH}
    check_pkg ${BIN_WGET} ${PKG_WGET}

elif [ X"${DISTRO}" == X"SUSE" ]; then
    ECHO_INFO "Clean metadata of zypper repositories."
    zypper clean --metadata --raw-metadata

    create_repo_suse

    ECHO_INFO "Refresh zypper repositories."
    zypper refresh
elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
    # Force update.
    ECHO_INFO "Resynchronizing the package index files (apt-get update) ..."
    ${APTGET} update
elif [ X"${DISTRO}" == X'GENTOO' ]; then
    # qlist is used to list all installed portages (qlist --installed).
    check_pkg 'qlist' 'portage-utils'
    check_pkg 'equery' 'gentoolkit'
    check_pkg 'crontab' 'vixie-cron'
fi

check_status_before_run fetch_misc && \
check_status_before_run check_md5 && \
check_pkg ${BIN_DIALOG} ${PKG_DIALOG} && \
echo_end_msg && \
echo 'export status_get_all="DONE"' >> ${STATUS_FILE}
