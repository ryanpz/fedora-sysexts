#!/bin/bash

# Re-generate the GitHub workflows based on templates. We do not use a matrix
# build strategy in GitHub worflows to reduce overall build time and avoid
# pulling the same base container image multiple time, once for each individual
# job.

set -euo pipefail
# set -x

main() {
    if [[ ! -d .github ]] || [[ ! -d .git ]]; then
        echo "This script must be run at the root of the repo"
        exit 1
    fi

    # Remove all existing worflows
    rm -f "./.github/workflows/containers"*".yml"
    rm "./.github/workflows/sysexts"*".yml"

    generate \
        'quay.io/fedora-ostree-desktops/sway-atomic' \
        '42' \
        'x86_64' \
        'Fedora Sway Atomic'

    generate \
        'quay.io/fedora-ostree-desktops/kinoite' \
        '42' \
        'x86_64' \
        'Fedora Kinoite'
}

ignored_sysexts() {
    declare -a ignored=(
        ".github"
        ".workflow-templates"
        "1password-cli"
        "1password-gui"
        "bitwarden"
        "chromium"
        "cockpit"
        "compsize"
        "cri-o-1.29"
        "cri-o-1.30"
        "cri-o-1.31"
        "cri-o-1.32"
        "emacs"
        "firefox"
        "fuse2"
        "gdb"
        "google-chrome"
        "incus"
        "iwd"
        "keepassxc"
        "krb5-workstation"
        "kubernetes-1.29"
        "kubernetes-1.30"
        "kubernetes-1.31"
        "kubernetes-1.32"
        "kubernetes-cri-o-1.29"
        "kubernetes-cri-o-1.30"
        "kubernetes-cri-o-1.31"
        "kubernetes-cri-o-1.32"
        "lact-libadwaita"
        "lact"
        "libvirtd"
        "mesa-git"
        "microsoft-edge"
        "monitoring"
        "mpd"
        "mullvad-vpn"
        "openh264"
        "openssl"
        "python"
        "semanage"
        "steam"
        "strace"
        "tree"
        "vscode"
        "vscodium"
        "wasmtime"
        "wireguard-tools"
        "wireshark"
        "zoxide"
    )

    pat=$(printf "|^%s$" "${ignored[@]}")
    pat="${pat:1}" # remove leading separator
    echo "$pat"
}

generate() {
    local -r image="${1}"
    local -r release="${2}"
    local -r arch="${3}"
    local -r name="${4}"
    local -r shortname="$(echo "${name}" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g')"

    # For containers only
    local -r registry="quay.io/travier"
    local -r destination_suffix="-sysexts"

    # Get the list of sysexts for a given target
    sysexts=()
    for s in $(git ls-tree -d --name-only HEAD | grep -Ev "$(ignored_sysexts)"); do
        pushd "${s}" > /dev/null
        # Only require the architecture to be explicitly listed for non x86_64 for now
        if [[ "${arch}" == "x86_64" ]]; then
            if [[ $(just targets | grep -c "${image}:${release}") == "1" ]]; then
                sysexts+=("${s}")
            fi
        else
            if [[ $(just targets | grep -cE "${image}:${release} .*${arch}.*") == "1" ]]; then
                sysexts+=("${s}")
            fi
        fi
        popd > /dev/null
    done

    local -r tmpl=".workflow-templates/"
    if [[ ! -d "${tmpl}" ]]; then
        echo "Could not find the templates. Is this script run from the root of the repo?"
        exit 1
    fi

    # Generate EROFS sysexts workflows
    {
    sed \
        -e "s|%%IMAGE%%|${image}:${release}|g" \
        -e "s|%%RELEASE%%|${release}|g" \
        -e "s|%%NAME%%|${name}|g" \
        -e "s|%%SHORTNAME%%|${shortname}|g" \
        -e "s|%%ARCH%%|${arch}|g" \
        "${tmpl}/sysexts_header"
    echo ""
    for s in "${sysexts[@]}"; do
        sed "s|%%SYSEXT%%|${s}|g" "${tmpl}/sysexts_body"
        echo ""
    done
    cat "${tmpl}/sysexts_footer"
    } > ".github/workflows/sysexts-${shortname}-${release}-${arch}.yml"

    # Fix GitHub runner for aarch64
    if [[ "${arch}" == "aarch64" ]]; then
        sed -i "s/ubuntu-24.04/ubuntu-24.04-arm/" ".github/workflows/sysexts-${shortname}-${release}-${arch}.yml"
    fi

    # Skip container builds for now as we are not using them yet.
    return 0

    # Generate container sysexts workflows
    # Skip non x86-64 builds for now
    if [[ "${arch}" != "x86_64" ]]; then
        return 0
    fi
    {
    sed \
        -e "s|%%IMAGE%%|${image}|g" \
        -e "s|%%RELEASE%%|${release}|g" \
        -e "s|%%NAME%%|${name}|g" \
        -e "s|%%REGISTRY%%|${registry}|g" \
        -e "s|%%DESTINATION%%|${shortname}${destination_suffix}|g" \
        -e "s|%%ARCH%%|${arch}|g" \
        "${tmpl}/containers_header"
    echo ""
    for s in "${sysexts[@]}"; do
        if [[ -f "${s}/Containerfile" ]]; then
            sed \
                -e "s|%%SYSEXT%%|${s}|g" \
                -e "s|%%SYSEXT_NODOT%%|${s//\./_}|g" \
                "${tmpl}/containers_build"
            echo ""
        fi
    done
    # Skip pushing containers for now
    # cat "${tmpl}/containers_logincosign"
    # echo ""
    # for s in "${sysexts[@]}"; do
    #     if [[ -f "${s}/Containerfile" ]]; then
    #         sed \
    #             -e "s|%%SYSEXT%%|${s}|g" \
    #             -e "s|%%SYSEXT_NODOT%%|${s//\./_}|g" \
    #             "${tmpl}/containers_pushsign"
    #         echo ""
    #     fi
    # done
    } > ".github/workflows/containers-${shortname}-${release}.yml"
}

main "${@}"
