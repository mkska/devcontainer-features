#!/usr/bin/env bash

set -e

VERSION="${VERSION:-"latest"}"

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

# Figure out correct version of a three part version number is not passed
find_version_from_git_tags() {
    local variable_name=$1
    local requested_version=${!variable_name}
    if [ "${requested_version}" = "none" ]; then return; fi
    local repository=$2
    local prefix=${3:-"tags/v"}
    local separator=${4:-"."}
    local last_part_optional=${5:-"false"}
    if [ "$(echo "${requested_version}" | grep -o "." | wc -l)" != "2" ]; then
        local escaped_separator=${separator//./\\.}
        local last_part
        if [ "${last_part_optional}" = "true" ]; then
            last_part="(${escaped_separator}[0-9]+)?"
        else
            last_part="${escaped_separator}[0-9]+"
        fi
        local regex="${prefix}\\K[0-9]+${escaped_separator}[0-9]+${last_part}$"
        local version_list="$(git ls-remote --tags ${repository} | grep -oP "${regex}" | tr -d ' ' | tr "${separator}" "." | sort -rV)"
        if [ "${requested_version}" = "latest" ] || [ "${requested_version}" = "current" ] || [ "${requested_version}" = "lts" ]; then
            declare -g ${variable_name}="$(echo "${version_list}" | head -n 1)"
        else
            set +e
            declare -g ${variable_name}="$(echo "${version_list}" | grep -E -m 1 "^${requested_version//./\\.}([\\.\\s]|$)")"
            set -e
        fi
    fi
    if [ -z "${!variable_name}" ] || ! echo "${version_list}" | grep "^${!variable_name//./\\.}$" >/dev/null 2>&1; then
        echo -e "Invalid ${variable_name} value: ${requested_version}\nValid values:\n${version_list}" >&2
        exit 1
    fi
    echo "${variable_name}=${!variable_name}"
}

architecture="$(uname -m)"
case $architecture in
x86_64) architecture="amd64" ;;
aarch64 | armv8*) architecture="arm64" ;;
aarch32 | armv7* | armvhf*) architecture="arm" ;;
i?86) architecture="386" ;;
*)
    echo "(!) Architecture $architecture unsupported"
    exit 1
    ;;
esac

if [ "${VERSION}" != "none" ]; then
    if [ "${VERSION::1}" == 'v' ]; then
        VERSION="${VERSION:1}"
    fi
    binaryname="cloud-sql-proxy"
    url="https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v${VERSION}/${binaryname}.linux.${architecture}"

    find_version_from_git_tags VERSION https://github.com/GoogleCloudPlatform/cloud-sql-proxy

    if [ "${VERSION::1}" == '1' ]; then
        binaryname="cloud_sql_proxy"
        url="https://storage.googleapis.com/cloudsql-proxy/v${VERSION}/${binaryname}.linux.${architecture}"
    fi

    echo "Downloading ${binaryname}..."

    curl -sSL -o /usr/local/bin/cloud_sql_proxy $url
    chmod 0755 /usr/local/bin/cloud_sql_proxy
fi

echo "Done!"
