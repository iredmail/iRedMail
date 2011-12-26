#!/usr/bin/env bash

# Author:   Zhang Huangbin (zhb(at)iredmail.org)
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
. ${CONF_DIR}/functions
. ${CONF_DIR}/core
. ${CONF_DIR}/iredadmin

# Re-define @STATUS_FILE, so that iRedMail.sh can read it.
export STATUS_FILE="${ROOTDIR}/../.${PROG_NAME}.installation.status"

check_user root
check_hostname

if [ X"${DISTRO}" == X"FREEBSD" ]; then
    # -i: Turns off interactive prompting during multiple file transfers.
    # -V: Disable verbose and progress
    FETCH_CMD='ftp -iV'
else
    # -c: Continue getting a partially-downloaded file.
    # -q: Turn off Wget's output.
    # --referer: Include 'Referer: url' header in HTTP request.
    FETCH_CMD="wget -cq --referer ${PROG_NAME}-${PROG_VERSION}-${DISTRO}-X${DISTRO_VERSION}-${ARCH}"
fi

#
# Mirror site.
# Site directory structure:
#
#   ${MIRROR}/
#           |- yum/         # for RHEL/CentOS
#               |- rpms/
#                   |- 5/
#                   |- 6/   # Not present yet.
#               |- misc/    # Source tarballs.
#               |- srpms/   # Source RPMs.
#           |- apt/             # for Debian/Ubuntu
#               |- debian/      # For Debian
#                   |- lenny/   # For Debian (Lenny)
#
# You can find nearest mirror in this page:
#   http://code.google.com/p/iredmail/wiki/Mirrors
#

# Where to store binary packages and source tarball.
PKG_DIR="${ROOTDIR}/pkgs"
MISC_DIR="${ROOTDIR}/misc"

if [ X"${DISTRO}" == X"RHEL" ]; then
    export MIRROR='http://iredmail.org/yum'

    # Special package.
    # command: which.
    export BIN_WHICH='which'
    export PKG_WHICH="which${PKG_ARCH}"
    # command: wget.
    export BIN_WGET='wget'
    export PKG_WGET="wget${PKG_ARCH}"

elif [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ]; then
    export MIRROR='http://iredmail.org/apt'

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
elif [ X"${DISTRO}" == X"FREEBSD" ]; then
    export MIRROR='http://iredmail.org/yum/freebsd'
else
    export MIRROR='http://iredmail.org/yum'
fi

# Binary packages.
export pkg_total=$(echo ${PKGLIST} | wc -w | awk '{print $1}')
export pkg_counter=1

# Misc file (source tarball) list.
if [ X"${DISTRO}" == X"FREEBSD" ]; then
    PKGMISC='SHASUM.freebsd.misc'
elif [ X"${DISTRO}" == X"DEBIAN" -a X"${DISTRO_CODENAME}" == X"squeeze" ]; then
    PKGMISC='MD5.ubuntu.lucid'
elif [ X"${DISTRO}" == X"UBUNTU" -a X"${DISTRO_CODENAME}" == X"lucid" ]; then
    PKGMISC='MD5.ubuntu.lucid'
elif [ X"${DISTRO}" == X"SUSE" ]; then
    PKGMISC='MD5.misc MD5.opensuse'
else
    PKGMISC='MD5.misc'
fi
MISCLIST="$(cat ${ROOTDIR}/${PKGMISC} | awk -F'misc/' '{print $2}')"


mirror_notify()
{
    cat <<EOF
*********************************************************************
**************************** Mirrors ********************************
*********************************************************************
* If you can't fetch packages, please try to use another mirror site
* listed in below url:
*
*   - http://code.google.com/p/iredmail/wiki/Mirrors
*
*********************************************************************
EOF

    echo 'export status_mirror_notify="DONE"' >> ${STATUS_FILE}
}

prepare_dirs()
{
    ECHO_DEBUG "Creating necessary directories ..."
    for i in ${PKG_DIR} ${MISC_DIR}
    do
        [ -d "${i}" ] || mkdir -p "${i}"
    done
}

fetch_pkgs_debian()
{
    cd ${PKG_DIR}

    if [ X"${PKGLIST}" != X"0" ]; then
        ECHO_INFO "Fetching Binary Packages ..."
        for i in ${PKGLIST}; do
            if [ X"${DISTRO}" == X"DEBIAN" ]; then
                url="${MIRROR}/debian/lenny/${i}"
            fi

            ECHO_INFO "+ ${pkg_counter} of ${pkg_total}: ${url}"
            ${FETCH_CMD} "${url}"

            pkg_counter=$((pkg_counter+1))
        done
    else
        :
    fi
}

fetch_misc()
{
    # Fetch all misc packages.
    cd ${MISC_DIR}

    # Help track basic information, used to help iRedMail team understand
    # which Linux/BSD distribution we should take more care of.
    # iRedMail version number, OS distribution, release version, code name.
    ${FETCH_CMD} "http://iredmail.org/version/check.py/iredmail_os?iredmail_version=${PROG_VERSION}&distro=${DISTRO}&distro_version=${DISTRO_VERSION}&distro_code_name=${DISTRO_CODENAME}" &>/dev/null

    misc_total=$(( $(echo ${MISCLIST} | wc -w | awk '{print $1}') ))
    misc_count=1

    ECHO_INFO "Fetching Source Tarballs ..."

    for i in ${MISCLIST}; do
        url="${MIRROR}/misc/${i}"
        ECHO_INFO "+ ${misc_count} of ${misc_total}: ${url}"

        ${FETCH_CMD} "${url}"

        misc_count=$((misc_count + 1))
    done
}

check_md5()
{
    cd ${ROOTDIR}

    if [ X"${DISTRO}" != X"FREEBSD" ]; then
        ECHO_INFO -n "Validate Packages ..."

        md5file="/tmp/check_md5_tmp.${RANDOM}$RANDOM}"
        echo -e "${MD5LIST}" > ${md5file}
        cat ${PKGMISC} >> ${md5file}
        md5sum -c ${md5file} |grep 'FAILED'
        RETVAL="$?"
        rm -f ${md5file} 2>/dev/null

        if [ X"${RETVAL}" == X"0" ]; then
            echo -e "\t[ FAILED ]"
            ECHO_ERROR "MD5 check failed. Check your rpm packages. Script exit ...\n"
            exit 255
        else
            echo -e "\t[ OK ]"
            echo 'export status_fetch_pkgs="DONE"' >> ${STATUS_FILE}
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
baseurl=http://iredmail.org/yum/rpms/${DISTRO_VERSION}/
enabled=1
gpgcheck=0
EOF

    # Dovecot-1.2 for RHEL 5.
    if [ X"${DISTRO_VERSION}" == X"5" ]; then
        cat >> ${LOCAL_REPO_FILE} <<EOF
[iRedMail-Dovecot-12]
name=iRedMail-Dovecot-12
baseurl=http://iredmail.org/yum/rpms/dovecot/rhel${DISTRO_VERSION}/
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
baseurl=http://iredmail.org/yum/opensuse/${DISTRO_VERSION}/
enabled=1
autorefresh=1
path=/
type=rpm-md
keeppackages=0
gpgcheck=0
EOF

}

create_repo_debian()
{
    # Use http://backports.debian.org/ on Debian 5.
    if [ X"${DISTRO}" == X"DEBIAN" -a X"${DISTRO_VERSION}" == X"5" ]; then
        grep 'Debian-Backports-iRedMail' /etc/apt/sources.list &>/dev/null
        if [ X"$?" != X"0" ]; then
            cat >> /etc/apt/sources.list <<EOF
# Debian-Volatile. Used for updating ClamAV.
deb http://volatile.debian.org/debian-volatile lenny/volatile main contrib non-free
# Debian-Backports-iRedMail
deb http://backports.debian.org/debian-backports lenny-backports main
EOF

            cat >> /etc/apt/preferences <<EOF

Package: *
Pin: release a=lenny-backports
Pin-Priority: 500
EOF

            # Force 'apt-get update' to enable backports repo.
            ECHO_INFO "Execute 'apt-get update'..."
            ${APTGET} update

            ${APTGET} install -y debian-archive-keyring
        fi
    fi
}

create_repo_ubuntu()
{
    if [ X"${DISTRO}" == X"UBUNTU" ]; then
        if [ X"${DISTRO_CODENAME}" == X"hardy" ]; then
            # Add ppa repo for Ubuntu 8.04.
            grep 'Ubuntu-Hardy-PPA-iRedMail' /etc/apt/sources.list &>/dev/null
            if [ X"$?" != X"0" ]; then
                # Add repo url.
                cat >> /etc/apt/sources.list <<EOF
# Ubuntu-Hardy-PPA-iRedMail
deb http://ppa.launchpad.net/iredmail/8.04/ubuntu hardy main
#deb-src http://ppa.launchpad.net/iredmail/8.04/ubuntu hardy main
EOF

                # Import GPG key.
                apt-key adv --recv-keys \
                    --keyserver keyserver.ubuntu.com \
                    0xd9226c1a29511386b3b9f8bc8dc2c190ddf700d3
            fi
        fi

        # Force update
        ECHO_INFO "Execute 'apt-get update'..."
        ${APTGET} update
    fi
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

prepare_dirs

# Create yum repository.
if [ X"${DISTRO}" == X"RHEL" ]; then
    check_pkg ${BIN_WHICH} ${PKG_WHICH} && \
    check_pkg ${BIN_WGET} ${PKG_WGET} && \
    create_repo_rhel
elif [ X"${DISTRO}" == X"SUSE" ]; then
    create_repo_suse

    ECHO_INFO "Clean and refresh metadata of zypper repositories."
    zypper clean --metadata --raw-metadata
    zypper refresh
elif [ X"${DISTRO}" == X"UBUNTU" ]; then
    create_repo_ubuntu
elif [ X"${DISTRO}" == X"DEBIAN" ]; then
    if [ X"${DISTRO_VERSION}" == X"5" ]; then
        create_repo_debian
    else
        # Force update.
        ECHO_INFO "Execute 'apt-get update'..."
        ${APTGET} update
    fi
fi

fetch_misc && \
check_md5 && \
check_pkg ${BIN_DIALOG} ${PKG_DIALOG} && \
echo_end_msg && \
echo 'export status_get_all="DONE"' >> ${STATUS_FILE}
