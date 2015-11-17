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

_ROOTDIR="$(pwd)"
CONF_DIR="${_ROOTDIR}/../conf"

. ${CONF_DIR}/global
. ${CONF_DIR}/core
. ${CONF_DIR}/iredadmin

# Re-define @STATUS_FILE, so that iRedMail.sh can read it.
#export STATUS_FILE="${_ROOTDIR}/../.status"

check_user root
check_hostname
check_runtime_dir

# Where to fetch/store binary packages and source tarball.
export IREDMAIL_MIRROR="${IREDMAIL_MIRROR:=http://iredmail.org}"
export PKG_DIR="${_ROOTDIR}/pkgs"
export PKG_MISC_DIR="${_ROOTDIR}/misc"

if [ X"${DISTRO}" == X"RHEL" ]; then
    # Special package.
    # command: which.
    export BIN_WHICH='which'
    export PKG_WHICH='which'
    # command: wget.
    export BIN_WGET='wget'
    export PKG_WGET='wget'

elif [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ]; then
    if [ X"${OS_ARCH}" == X"x86_64" ]; then
        export pkg_arch='amd64'
    else
        export pkg_arch="${OS_ARCH}"
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
    MD5_FILE='SHASUM.freebsd.misc'
    SHASUM_CMD='shasum'
elif [ X"${DISTRO}" == X'OPENBSD' ]; then
    MD5_FILE='MD5.openbsd'
    MD5_CMD='md5'
else
    MD5_FILE='MD5.misc'
    MD5_CMD='md5sum'
fi

MISCLIST="$(cat ${_ROOTDIR}/${MD5_FILE} | awk -F'misc/' '{print $2}')"

prepare_dirs()
{
    ECHO_DEBUG "Creating necessary directories ..."
    for i in ${PKG_DIR} ${PKG_MISC_DIR}
    do
        [ -d "${i}" ] || mkdir -p "${i}"
    done
}

fetch_misc()
{
    # Fetch all misc packages.
    cd ${PKG_MISC_DIR}

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
    cd ${_ROOTDIR}

    ECHO_INFO -n "Validate packages ..."

    if [ X"${DISTRO}" == X"FREEBSD" ]; then
        shasum -c ${MD5_FILE} | grep 'FAILED' &>/dev/null
        RETVAL="$?"
    else
        md5sum -c ${MD5_FILE} | grep 'FAILED' &>/dev/null
        RETVAL="$?"
    fi

    if [ X"${RETVAL}" == X"0" ]; then
        echo -e "\t[ FAILED ]"
        ECHO_ERROR "MD5 check failed. Script exit ...\n"
        exit 255
    else
        echo -e "\t[ OK ]"
        echo 'export status_fetch_misc="DONE"' >> ${STATUS_FILE}
        echo 'export status_check_md5="DONE"' >> ${STATUS_FILE}
    fi
}

create_repo_rhel()
{
    ECHO_INFO "Preparing yum repositories ..."

    # Backup old repo file.
    backup_file ${LOCAL_REPO_FILE}

    # Generate new repo file.
    cat > ${LOCAL_REPO_FILE} <<EOF
[${LOCAL_REPO_NAME}]
name=${LOCAL_REPO_NAME}
baseurl=${IREDMAIL_MIRROR}/yum/rpms/${DISTRO_VERSION}/
enabled=1
gpgcheck=0
#exclude=postfix*
EOF

    # For Red Hat Enterprise Linux
    if [ X"${DISTRO_CODENAME}" == X'rhel' ]; then
        # repo to install epel-release without GPG check.
        cat > ${YUM_REPOS_DIR}/tmp_epel.repo <<EOF
[tmp_epel]
name=Extra Packages for Enterprise Linux ${DISTRO_VERSION} - \$basearch
#baseurl=http://download.fedoraproject.org/pub/epel/${DISTRO_VERSION}/\$basearch
mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=epel-${DISTRO_VERSION}&arch=\$basearch
failovermethod=priority
enabled=1
gpgcheck=0
EOF
    fi

    eval ${install_pkg} epel-release

    if [ X"${DISTRO_CODENAME}" == X'rhel' ]; then
        rm -f ${YUM_REPOS_DIR}/tmp_epel.repo
    fi

    # Use specified EPEL local mirror site (url doesn't end with slash)
    epel_repo="${YUM_REPOS_DIR}/epel.repo"
    if [ -n "${IREDMAIL_EPEL_MIRROR}" -a -f ${epel_repo} ]; then
        # comment out all 'mirrorlist=' and 'baseurl='
        perl -pi -e 's/^(mirrorlist=.*)/#${1}/g' ${epel_repo}
        perl -pi -e 's/^(baseurl=.*)/#${1}/g' ${epel_repo}
        # Add a new 'baseurl='
        export IREDMAIL_EPEL_MIRROR
        perl -pi -e 's/^(\[epel\])$/${1}\nbaseurl=$ENV{IREDMAIL_EPEL_MIRROR}\/$ENV{DISTRO_VERSION}\/\$basearch/g' ${epel_repo}
    fi

    echo 'export status_create_repo_rhel="DONE"' >> ${STATUS_FILE}
}

check_new_iredmail()
{
    # Check new version and track basic information,
    # Used to help iRedMail team understand which Linux/BSD distribution
    # we should take more care of.
    #
    #   - PROG_VERSION: iRedMail version number
    #   - OS_ARCH: arch (i386, x86_64)
    #   - DISTRO: OS distribution
    #   - DISTRO_VERSION: distribution release number
    #   - DISTRO_CODENAME: code name
    ECHO_INFO "Checking new version of iRedMail ..."
    ${FETCH_CMD} "${IREDMAIL_MIRROR}/version/check.py/iredmail_os?iredmail_version=${PROG_VERSION}&arch=${OS_ARCH}&distro=${DISTRO}&distro_version=${DISTRO_VERSION}&distro_code_name=${DISTRO_CODENAME}" &>/dev/null

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
    if [ X"$(basename $0)" != X'get_all.sh' ]; then
        cat <<EOF
********************************************************
* All tasks had been finished successfully. Next step:
*
*   # cd ..
*   # bash ${PROG_NAME}.sh
*
********************************************************

EOF
    fi
}

if [ -e ${STATUS_FILE} ]; then
    . ${STATUS_FILE}
else
    echo '' > ${STATUS_FILE}
fi

# Check latest version
[ X"${CHECK_NEW_IREDMAIL}" != X'NO' ] && \
    check_status_before_run check_new_iredmail

prepare_dirs

if [ X"${DISTRO}" == X"RHEL" ]; then
    # Create yum repository.
    check_status_before_run create_repo_rhel

    # Check required commands, install related package if command doesn't exist.
    check_pkg ${BIN_WHICH} ${PKG_WHICH}
    check_pkg ${BIN_WGET} ${PKG_WGET}

elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
    # Force update.
    ECHO_INFO "Resynchronizing the package index files (apt-get update) ..."
    ${APTGET} update
fi

check_status_before_run fetch_misc && \
check_status_before_run check_md5 && \
check_pkg ${BIN_DIALOG} ${PKG_DIALOG} && \
echo_end_msg && \
echo 'export status_get_all="DONE"' >> ${STATUS_FILE}
