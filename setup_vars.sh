#!/bin/bash

. build_vars.sh

HOST_NAME=potato
LOCALE=fr_FR
MIRROR=fr
TIMEZONE=Europe/Paris
WPA_PSK='YOUR_SUPER_SECRET'
WPA_SSID='YOUR_NETWORK'

PURGE_PACKAGES=(
    avahi-daemon
    avahi-autoipd
    network-manager
    ntp
)
INST_PACKAGES=(
    anacron
    aptitude
    at
    bash-completion
    build-essential
    git
    nginx-light
    oracle-java8-installer
    php7.1-bcmath
    php7.1-bz2
    php7.1-curl
    php7.1-fpm
    php7.1-gd
    php7.1-gmp
    php7.1-mbstring
    php7.1-mcrypt
    php7.1-readline
    php7.1-sqlite3
    php7.1-xsl
    php7.1-zip
    python
    python-pip
    python3
    python3-pip
    shorewall6
    unzip
    wpasupplicant
)
