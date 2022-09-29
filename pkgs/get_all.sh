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

export PKG_DIR="${_ROOTDIR}/pkgs"
export PKG_MISC_DIR="${_ROOTDIR}/misc"

# Verify downloaded source tarballs
export SHASUM_CHECK_FILE='pkgs.sha256'
# Linux/FreeBSD use 'shasum -c'
export CMD_SHASUM_CHECK='sha256sum -c'

# Special package.
# command: which.
export BIN_WHICH='which'
export PKG_WHICH='which'
# command: wget.
export BIN_WGET='wget'
export PKG_WGET='wget'
# command: perl
export BIN_PERL='perl'
export PKG_PERL='perl'

if [ X"${DISTRO}" == X"DEBIAN" -o X"${DISTRO}" == X"UBUNTU" ]; then
    export PKG_WHICH="debianutils"

    export PKG_APT_TRANSPORT_HTTPS="apt-transport-https"
elif [ X"${DISTRO}" == X'FREEBSD' ]; then
    export SHASUM_CHECK_FILE='pkgs.freebsd.sha256'
    export CMD_SHASUM_CHECK='shasum -c'
    export CMD_SHASUM='sha256'
elif [ X"${DISTRO}" == X'OPENBSD' ]; then
    export SHASUM_CHECK_FILE='pkgs.openbsd.sha256'
    export CMD_SHASUM_CHECK='cksum -c'
fi

if [ X"${DISTRO}" == X'FREEBSD' -o X"${DISTRO}" == X'OPENBSD' ]; then
    MISCLIST="$(cat ${_ROOTDIR}/${SHASUM_CHECK_FILE} | awk -F'[(/)]' '{print $3}')"
else
    MISCLIST="$(cat ${_ROOTDIR}/${SHASUM_CHECK_FILE} | awk -F'misc/' '{print $2}')"
fi

prepare_dirs()
{
    ECHO_DEBUG "Creating necessary directories ..."
    for i in ${PKG_DIR} ${PKG_MISC_DIR}; do
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

verify_downloaded_packages()
{
    ECHO_INFO "Validate downloaded source tarballs ..."

    cd ${_ROOTDIR}
    if [ X"${DISTRO}" == X"FREEBSD" ]; then
        # Get package names.
        pkg_names="$(cat ${SHASUM_CHECK_FILE} | awk -F'(' '{print $2}' | awk -F')' '{print $1}')"

        # Create a temp file to store shasum
        ${CMD_SHASUM} ${pkg_names} > _tmp_pkg_names
        #cat _tmp_pkg_names

        # Compare the shasum
        diff _tmp_pkg_names ${SHASUM_CHECK_FILE}
        RETVAL="$?"
        rm -f _tmp_pkg_names &>/dev/null
    else
        ${CMD_SHASUM_CHECK} ${SHASUM_CHECK_FILE}
        RETVAL="$?"
    fi

    if [ X"${RETVAL}" == X"0" ]; then
        echo -e "\t[ OK ]"
        echo 'export status_fetch_misc="DONE"' >> ${STATUS_FILE}
        echo 'export status_verify_downloaded_packages="DONE"' >> ${STATUS_FILE}
    else
        echo -e "\t[ FAILED ]"
        ECHO_ERROR "Package verification failed. Script exit ...\n"
        exit 255
    fi
}

create_repo_rhel()
{
    ECHO_INFO "Preparing yum repositories ..."

    # Red Hat Enterprise Linux 8.
    if [ X"${DISTRO}" == X"RHEL" -a X"${DISTRO_VERSION}" == X'8' -a X"${DISTRO_CODENAME}" == X'rhel' ]; then
        # Enable repo (same as AppStream + PowerTools on CentOS).
        # Require registration of Red Hat subscription.
        ECHO_INFO "RHEL: Enable repo: codeready-builder-for-rhel-8-x86_64-rpms"
        subscription-manager repos --enable codeready-builder-for-rhel-8-x86_64-rpms
        if [[ X"$?" != X'0' ]]; then
            echo 'Failed to enable yum repository `codeready-builder-for-rhel-8-x86_64-rpms`. Please'
            echo -e 'try to enable it manually with command below:\n'
            echo 'subscription-manager repos --enable codeready-builder-for-rhel-8-x86_64-rpms'
        fi

        # Install epel-release.
        ECHO_INFO "RHEL: Install package epel-release."
        dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
    else
        yum -y install epel-release
    fi

    # epel-next-release is avaiable in epel repo, so `epel` must be enabled first.
    _required_pkgs="epel-next-release"

    # required by command `yum config-manager --enable <repo>`.
    _required_pkgs="${_required_pkgs} dnf-plugins-core"

    eval ${install_pkg} ${_required_pkgs}

    # Backup old repo file.
    backup_file ${LOCAL_REPO_FILE}

    # Generate iRedMail repo file.
    if [[ X"${DISTRO_VERSION}}" == X"8" ]]; then
        cat > ${LOCAL_REPO_FILE} <<EOF
[${LOCAL_REPO_NAME}]
name=${LOCAL_REPO_NAME}
baseurl=${IREDMAIL_MIRROR}/yum/rpms/\$releasever/
enabled=1
gpgcheck=0
#exclude=postfix*
priority=99
module_hotfixes=1
EOF
    fi

    # RHEL/CentOS 8.
    # appstream and powertools are required on CentOS Linux and CentOS Stream.
    if [ X"${DISTRO_CODENAME}" == X'centos' ]; then
        # Remove repo files with old/deprecated names.
        rm -f ${YUM_REPOS_DIR}/CentOS-AppStream.repo &>/dev/null
        rm -f ${YUM_REPOS_DIR}/CentOS-PowerTools.repo &>/dev/null

        # Create if not present.
        for repo in Linux-AppStream Linux-PowerTools; do
            if [ ! -f "${YUM_REPOS_DIR}/CentOS-${repo}.repo" ]; then
                cp -f "${SAMPLE_DIR}/yum/CentOS-${repo}.repo" ${YUM_REPOS_DIR}/CentOS-${repo}.repo
            fi
        done
    elif [ X"${DISTRO_CODENAME}" == X'stream' ]; then
        if [[ X"${DISTRO_VERSION}" == X'8' ]]; then
            for repo in Stream-AppStream Stream-PowerTools; do
                if [ ! -f "${YUM_REPOS_DIR}/CentOS-${repo}.repo" ]; then
                    cp -f "${SAMPLE_DIR}/yum/CentOS-${repo}.repo" ${YUM_REPOS_DIR}/CentOS-${repo}.repo
                fi
            done
        fi
    fi

    if [ X"${DISTRO_CODENAME}" == X'centos' \
        -o X"${DISTRO_CODENAME}" == X'stream' \
        -o X"${DISTRO_CODENAME}" == X'rocky' \
        -o X"${DISTRO_CODENAME}" == X'alma' \
        ]; then
        # Make sure required repos are enabled.
        if [ X"${DISTRO_VERSION}" == X'8' ]; then
            ECHO_INFO "Enable yum repos: appstream, powertools."
            yum config-manager --enable appstream powertools
        elif [ X"${DISTRO_VERSION}" == X'9' ]; then
            ECHO_INFO "Enable required yum repos."
            dnf config-manager --enable baseos appstream crb

            if [ X"${DISTRO_CODENAME}" == X'stream' ]; then
                dnf config-manager --enable extras-common
            elif [ X"${DISTRO_CODENAME}" == X'rocky' -o X"${DISTRO_CODENAME}" == X'alma' ]; then
                dnf config-manager --enable extras
            fi
        fi
    fi

    echo 'export status_create_repo_rhel="DONE"' >> ${STATUS_FILE}
}

check_new_iredmail()
{
    # Check new version.
    ECHO_INFO "Checking new version of iRedMail ..."
    ${FETCH_CMD} "https://l.iredmail.org/iredmail/new_version?iredmail_version=${PROG_VERSION}" &>/dev/null

    UPDATE_AVAILABLE='NO'
    if ls new_version* &>/dev/null; then
        info="$(cat new_version*)"
        if [ X"${info}" == X'UPDATE_AVAILABLE' ]; then
            UPDATE_AVAILABLE='YES'
        fi

        rm -f new_version* &>/dev/null
    fi

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

# Check required commands, and install packages which offer the commands.
if [ X"${DISTRO}" == X"RHEL" ]; then
    check_pkg ${BIN_WHICH} ${PKG_WHICH}
    check_pkg ${BIN_WGET} ${PKG_WGET}
    check_pkg ${BIN_PERL} ${PKG_PERL}
elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
    [[ -e /usr/sbin/update-ca-certificates ]] || export MISSING_PKGS="${MISSING_PKGS} ca-certificates"
    [[ -e /usr/lib/apt/methods/https ]] || export MISSING_PKGS="${MISSING_PKGS} ${PKG_APT_TRANSPORT_HTTPS}"
    [[ -e /usr/bin/gpg2 ]] || export MISSING_PKGS="${MISSING_PKGS} gnupg2"
    # dirmngr is required by apt-key
    [ -e /usr/bin/dirmngr ] || export MISSING_PKGS="${MISSING_PKGS} dirmngr"

    if [ X"${DISTRO}" == X'UBUNTU' ]; then
        # Some required packages are in `universe` and `multiverse` apt repos.
        [ -x /usr/bin/apt-add-repository ] || export MISSING_PKGS="${MISSING_PKGS} software-properties-common"
    fi

    check_pkg ${BIN_PERL} ${PKG_PERL}
    check_pkg ${BIN_WGET} ${PKG_WGET}
fi

check_pkg ${BIN_DIALOG} ${PKG_DIALOG}
install_missing_pkg

if [ X"${DISTRO}" == X"RHEL" ]; then
    # Create yum repository.
    check_status_before_run create_repo_rhel
elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
    if [ X"${DISTRO}" == X'UBUNTU' ]; then
        for repo in multiverse universe; do
            if [ X"${UBUNTU_MIRROR_SITE}" != X'' ]; then
                apt-add-repository -n "deb ${UBUNTU_MIRROR_SITE} ${DISTRO_CODENAME} $repo"
                apt-add-repository -n "deb ${UBUNTU_MIRROR_SITE} ${DISTRO_CODENAME}-security $repo"
                apt-add-repository -n "deb ${UBUNTU_MIRROR_SITE} ${DISTRO_CODENAME}-updates $repo"
            else
                apt-add-repository -n $repo
            fi
        done
    fi

    # Force update.
    ECHO_INFO "apt update ..."
    ${APTGET} update
fi

check_status_before_run fetch_misc && \
check_status_before_run verify_downloaded_packages && \
echo_end_msg && \
echo 'export status_get_all="DONE"' >> ${STATUS_FILE}
