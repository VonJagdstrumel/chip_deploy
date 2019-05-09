#!/usr/bin/env bash

export LOCALVERSION=-chip

BUILD_KERN_VERSION=5.1
BUILD_FULL_VERSION=$BUILD_KERN_VERSION.0$LOCALVERSION
BUILD_TGT_ARCH=arm-linux-gnueabihf
BUILD_CPU_COUNT=$(nproc)
BUILD_WORKSPACE=$PWD

BUILD_KERN_REPO=linux
BUILD_KERN_BRANCH=$BUILD_KERN_VERSION
BUILD_KERN_SRC=$BUILD_KERN_REPO-$BUILD_KERN_BRANCH
BUILD_KERN_ARCHIVE=$BUILD_KERN_SRC.tar.xz
BUILD_KERN_URL=https://cdn.kernel.org/pub/linux/kernel/v5.x/$BUILD_KERN_ARCHIVE

BUILD_WXAN_REPO=RTL8723BS
BUILD_WXAN_BRANCH=debian
BUILD_WXAN_SRC=$BUILD_WXAN_REPO-$BUILD_WXAN_BRANCH
BUILD_WXAN_ARCHIVE=$BUILD_WXAN_BRANCH.tar.gz
BUILD_WXAN_URL=https://github.com/kaplan2539/rtl8723bs/archive/$BUILD_WXAN_BRANCH.tar.gz

export CCACHE_DIR="$HOME/.ccache"
export PATH="/usr/lib/ccache:$PATH"
export ARCH=arm
export CROSS_COMPILE=/usr/bin/$BUILD_TGT_ARCH-
export INSTALL_PATH=$BUILD_WORKSPACE/boot
export INSTALL_MOD_PATH=$BUILD_WORKSPACE

export CONFIG_PLATFORM_ARM_SUNxI=y
export CONFIG_RTL8723BS=m

SETUP_HOSTNAME=potato
SETUP_LOCALE=fr_FR
SETUP_APT_MIRROR=fr
SETUP_TIMEZONE=Europe/Paris
SETUP_WPA_PSK='YOUR_SUPER_SECRET'
SETUP_WPA_SSID='YOUR_NETWORK'

SETUP_PURGE_PACKAGES=(
    avahi-daemon
    avahi-autoipd
    network-manager
    ntp
)
SETUP_INST_PACKAGES=(
    anacron
    aptitude
    at
    automake
    bash-completion
    bluez-tools
    build-essential
    gdb
    git
    libtool
    libuv1-dev
    lsof
    mpg123
    musl-tools
    nginx-light
    obexftp
    oracle-java8-installer
    php7.3-bcmath
    php7.3-bz2
    php7.3-curl
    php7.3-fpm
    php7.3-gd
    php7.3-gmp
    php7.3-mbstring
    php7.3-readline
    php7.3-sqlite3
    php7.3-xsl
    php7.3-zip
    pulseaudio-module-bluetooth
    python3-pip
    python3-venv
    shorewall6
    unzip
    vim
    wpasupplicant
)

set -euxo pipefail
