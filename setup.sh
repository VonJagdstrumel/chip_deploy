#!/usr/bin/env bash

if [[ $# = 0 ]]; then
    smul=$(tput smul)
    rmul=$(tput rmul)

    cat << EOF
${smul}Usage:${rmul} $(basename "$BASH_SOURCE") <step>

${smul}Available steps:${rmul}
network
kernel
aptitude
system
firewall
ssh
blink
liquidprompt
nginx
php
EOF

    exit 1
fi

. "$(dirname "$BASH_SOURCE")/setup_vars.sh"

setupNetwork() {
    systemctl stop networking
    systemctl stop wpa_supplicant

    wpa_passphrase "$SETUP_WPA_SSID" "$SETUP_WPA_PSK" > /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
    chmod go-rwx /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
    rm /etc/resolv.conf
    ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf

    cat <<'EOF' > /etc/systemd/network/20-wired.network
[Match]
Name=usb0

[Network]
DHCP=yes
IPv6PrivacyExtensions=yes

[Link]
RequiredForOnline=no
EOF
    cat <<'EOF' > /etc/systemd/network/25-wireless.network
[Match]
Name=wlan0

[Network]
DHCP=yes
IPv6PrivacyExtensions=yes
EOF
    cat <<'EOF' > /etc/systemd/network/30-bluetooth.network
[Match]
Name=bnep0

[Network]
DHCP=yes
IPv6PrivacyExtensions=yes
EOF
    cat <<'EOF' > /etc/systemd/network/35-ap.network
[Match]
Name=wlan1

[Network]
DHCPServer=yes
Address=192.168.10.1/24
IPForward=ipv4

[DHCPServer]
DNS=8.8.8.8
EOF

    cat <<EOF > /etc/wpa_supplicant/wpa_supplicant-wlan1.conf
network={
    frequency=2412
    group=CCMP
    key_mgmt=WPA-PSK
    mode=2
    pairwise=CCMP
    proto=RSN
    psk="1812 Overture"
    ssid="${SETUP_HOSTNAME^}"
}
EOF

    cat <<'EOF' > /etc/systemd/system/wpa_supplicant@.service
[Unit]
Description=WPA supplicant daemon (interface-specific version)
Requires=sys-subsystem-net-devices-%i.device
After=sys-subsystem-net-devices-%i.device
Before=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=/sbin/wpa_supplicant -c/etc/wpa_supplicant/wpa_supplicant-%I.conf -i%I

[Install]
Alias=multi-user.target.wants/wpa_supplicant@%i.service
EOF

    sed -ri 's/#(NTP)=/\1=0.debian.pool.ntp.org 1.debian.pool.ntp.org 2.debian.pool.ntp.org 3.debian.pool.ntp.org/' /etc/systemd/timesyncd.conf
    sed -ri 's/#(LLMNR=yes)/\1/' /etc/systemd/resolved.conf
    sed -ri 's/#(DNSStubListener)=udp/\1=no/' /etc/systemd/resolved.conf

    systemctl enable systemd-networkd
    systemctl enable systemd-resolved
    systemctl enable wpa_supplicant@wlan0
    systemctl enable wpa_supplicant@wlan1

    systemctl start systemd-networkd
    systemctl start systemd-resolved
    systemctl start wpa_supplicant@wlan0
    systemctl start wpa_supplicant@wlan1
    systemctl start systemd-timesyncd
}

setupKernel() {
    tar xf boot.tgz -C /
    tar xf lib.tgz -C /
    tar xf usr.tgz -C /

    #ln -s linux-image-4.4.13-ntc-mlc /usr/lib/linux-image-4.4.139-chip

    rm boot.tgz
    rm lib.tgz
    rm usr.tgz

    update-initramfs -c -t -k $BUILD_FULL_VERSION
}

setupAptitude() {
    cat <<'EOF' >> /etc/apt/sources.list
deb http://ftp.us.debian.org/debian/ jessie-updates main contrib non-free
deb http://ppa.launchpad.net/webupd8team/java/ubuntu cosmic main
EOF
    sed -ri "s/us(\.debian\.org)/$SETUP_APT_MIRROR\1/" /etc/apt/sources.list
    sed -ri '/chip/!s/jessie/buster/' /etc/apt/sources.list
    sed -ri '/(deb-src|backports)/s/^/#/' /etc/apt/sources.list
    sed -ri 's/opensource.nextthing.co/chip.jfpossibilities.com/' /etc/apt/sources.list

    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys EEA14886
    apt-mark hold flash-kernel

    apt update
    apt full-upgrade -y
    apt install -y ${INST_PACKAGES[@]}
    apt purge -y ${PURGE_PACKAGES[@]}
    apt-get autoremove --purge -y
    apt-get clean
}

setupSystem() {
    cat <<'EOF' > /etc/sysctl.d/90-$SETUP_HOSTNAME.conf
fs.file-max=100000
kernel.core_uses_pid=1
kernel.sysrq=0
net.core.somaxconn=4096
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.tcp_abort_on_overflow=1
net.ipv4.tcp_fin_timeout=30
net.ipv4.tcp_keepalive_time=1800
net.ipv4.tcp_max_syn_backlog=4096
net.ipv4.tcp_max_tw_buckets=1440000
net.ipv4.tcp_rfc1337=1
net.ipv4.tcp_syn_retries=3
net.ipv4.tcp_synack_retries=2
net.ipv4.tcp_timestamps=0
net.ipv4.tcp_tw_reuse=1
net.ipv6.conf.all.accept_ra_defrtr=0
net.ipv6.conf.all.accept_ra_pinfo=0
net.ipv6.conf.all.accept_ra_rtr_pref=0
net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.all.autoconf=0
net.ipv6.conf.all.dad_transmits=0
net.ipv6.conf.all.router_solicitations=0
EOF
    sysctl -p
    sysctl -w net.ipv4.route.flush=1
    sysctl -w net.ipv6.route.flush=1

    sed -ri 's:(ExecStart=/usr/sbin/ubihealthd .*):\1 -v3:' /etc/systemd/system/ubihealthd.service
    systemctl restart ubihealthd

    sed -ri "s/# ($SETUP_LOCALE\.UTF-8 UTF-8)/\1/" /etc/locale.gen
    locale-gen
    update-locale LANG=$SETUP_LOCALE.UTF-8

    echo $SETUP_TIMEZONE > /etc/timezone
    echo TZ=$SETUP_TIMEZONE >> /etc/environment

    sed -ri "s/(127\.0\.0\.1\t)chip/\1$SETUP_HOSTNAME/" /etc/hosts
    hostname $SETUP_HOSTNAME
    echo $SETUP_HOSTNAME > /etc/hostname

    passwd -l root
    echo 'Defaults env_keep += "HOME"' > /etc/sudoers.d/10_keep_home
}

setupFirewall() {
    tar xf shorewall.tar
    cp -r etc/ /
    sed -ri 's/(startup)=0/\1=1/' /etc/default/shorewall*

    rm shorewall.tar
    rm -r etc

    systemctl enable shorewall
    systemctl enable shorewall6

    #systemctl start shorewall
    #systemctl start shorewall6
}

setupSsh() {
    rm /etc/ssh/ssh_host_*
    ssh-keygen -A

    mv /etc/rc.local.orig /etc/rc.local

    sed -ri 's/(PermitRootLogin) yes/\1 no/' /etc/ssh/sshd_config
    sed -ri 's/#(PasswordAuthentication) yes/\1 no/' /etc/ssh/sshd_config
    sed -ri 's/(X11Forwarding) yes/\1 no/' /etc/ssh/sshd_config

    systemctl restart ssh

    mkdir /home/chip/.ssh
    cat <<'EOF' > /home/chip/.ssh/authorized_keys
YOUR_SSH_KEY
EOF
    chown -R chip:chip /home/chip/.ssh
}

setupBlink() {
    cat <<'EOF' > /etc/systemd/system/blink-disable.service
[Unit]
Description=blink-disable
After=default.target

[Service]
Type=simple
ExecStart=/bin/sh -c 'echo none > /sys/class/leds/chip:white:status/trigger'

[Install]
WantedBy=default.target
EOF

    systemctl enable blink-disable
    systemctl start blink-disable
}

setupLiquidPrompt() {
    cd /opt
    git clone https://github.com/nojhan/liquidprompt.git
    rm -r liquidprompt/.git
}

setupNginx() {
    sed -ri 's/#(server_names_hash_bucket_size 64;)/\1/' /etc/nginx/nginx.conf
    cat << EOF > /etc/nginx/sites-available/$SETUP_HOSTNAME
server {
    listen 80;
    listen [::]:80;

	root /var/www/html/$SETUP_HOSTNAME;
    index index.html index.htm index.php;
    server_name $SETUP_HOSTNAME;
    try_files \$uri \$uri/ =404;
    server_tokens off;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php7.3-fpm.sock;
    }
}
EOF

    mkdir /var/www/html/$SETUP_HOSTNAME
    ln -s /etc/nginx/sites-available/$SETUP_HOSTNAME /etc/nginx/sites-enabled/$SETUP_HOSTNAME
    rm /etc/nginx/sites-enabled/default

    systemctl restart nginx
}

setupMariaDb() {
    cat <<'EOF' > /etc/mysql/conf.d/$SETUP_HOSTNAME.cnf
[mysqld]
skip-archive
skip-blackhole
skip-federated

innodb_additional_mem_pool_size = 2M
innodb_buffer_pool_size = 16M
innodb_log_file_size = 5M
max_allowed_packet = 1M
myisam_sort_buffer_size = 8M
net_buffer_length = 8K
sort_buffer_size = 512K
table_open_cache = 64
EOF

    systemctl restart mysql
}

setupPhp() {
    sed -ri 's/(display_errors =) Off/\1 stderr/' /etc/php/7.3/cli/php.ini
    sed -ri "s:;(date\.timezone =):\1 $SETUP_TIMEZONE:" /etc/php/7.3/cli/php.ini

    sed -ri 's/(display_errors =) Off/\1 On/' /etc/php/7.3/fpm/php.ini
    sed -ri 's/(upload_max_filesize =) 2M/\1 20M/' /etc/php/7.3/fpm/php.ini
    sed -ri "s:;(date\.timezone =):\1 $SETUP_TIMEZONE:" /etc/php/7.3/fpm/php.ini
    sed -ri 's/(session\.use_strict_mode =) 0/\1 1/' /etc/php/7.3/fpm/php.ini

    sed -ri 's/(pm =) dynamic/\1 ondemand/' /etc/php/7.3/fpm/pool.d/www.conf
    sed -ri 's:;(chdir = /var/www):\1/html:' /etc/php/7.3/fpm/pool.d/www.conf

    systemctl restart php7.3-fpm

    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
}

$(typeset -F | sed 's/^declare -f //' | grep -i setup$1)
