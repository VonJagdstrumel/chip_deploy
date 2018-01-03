#!/bin/bash

. setup_vars.sh

setupNetwork() {
    systemctl stop NetworkManager
    systemctl stop networking
    systemctl stop wpa_supplicant

    wpa_passphrase "$WPA_SSID" "$WPA_PSK" > /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
    chmod go-rwx /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
    ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf

    cat <<'EOF' > /etc/systemd/network/20-wired.network
[Match]
Name=usb0

[Network]
DHCP=yes
IPv6PrivacyExtensions=kernel
EOF
    cat <<'EOF' > /etc/systemd/network/25-wireless.network
[Match]
Name=wlan0

[Network]
DHCP=yes
IPv6PrivacyExtensions=kernel
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

    systemctl start systemd-networkd
    systemctl start systemd-resolved
    systemctl start wpa_supplicant@wlan0
    systemctl start systemd-timesyncd
}

setupKernel() {
    tar -xf boot.tgz
    cp -r boot/ /
    rm boot.tgz
    rm -r boot

    tar -xf lib.tgz
    cp -r lib/modules/$LINUX_VERSION /lib/modules
    mv lib/firmware /lib/firmware/$LINUX_VERSION
    rm lib.tgz
    rm -r lib

    update-initramfs -c -t -k "$LINUX_VERSION"
}

setupAptitude() {
    cat <<'EOF' >> /etc/apt/sources.list
deb http://ftp.us.debian.org/debian/ jessie-updates main contrib non-free
deb http://ppa.launchpad.net/webupd8team/java/ubuntu zesty main
EOF
    sed -ri "s/us(\.debian\.org)/$MIRROR\1/" /etc/apt/sources.list
    sed -ri '/chip/!s/jessie/buster/' /etc/apt/sources.list
    sed -ri '/(deb-src|backports)/s/^/#/' /etc/apt/sources.list

    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys EEA14886
    apt-mark hold flash-kernel

    apt-get update
    apt-get dist-upgrade -y
    apt-get install -y ${INST_PACKAGES[@]}
    apt-get remove --purge -y ${PURGE_PACKAGES[@]}
    apt-get autoremove --purge -y
    apt-get clean
}

setupSystem() {
    cat <<'EOF' > /etc/sysctl.d/90-$HOST_NAME.conf
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

    sed -ri "s/# ($LOCALE\.UTF-8 UTF-8)/\1/" /etc/locale.gen
    locale-gen
    update-locale LANG=$LOCALE.UTF-8

    echo $TIMEZONE > /etc/timezone
    echo TZ=$TIMEZONE >> /etc/environment

    sed -ri "s/(127\.0\.0\.1\t)chip/\1$HOST_NAME/" /etc/hosts
    hostname $HOST_NAME
    echo $HOST_NAME > /etc/hostname

    passwd -l root
}

setupFirewall() {
    tar -xf shorewall.tar
    cp -r etc/ /
    sed -ri 's/(startup)=0/\1=1/' /etc/default/shorewall*
    rm shorewall.tar
    rm -r etc

    systemctl enable shorewall
    systemctl enable shorewall6

    systemctl start shorewall
    systemctl start shorewall6
}

setupSsh() {
    rm /etc/ssh/ssh_host_*
    ssh-keygen -A

    sed -ri 's/(PermitRootLogin) yes/\1 no/' /etc/ssh/sshd_config
    sed -ri 's/#(PasswordAuthentication) yes/\1 no/' /etc/ssh/sshd_config
    sed -ri 's/(X11Forwarding) yes/\1 no/' /etc/ssh/sshd_config

    systemctl restart ssh

    mkdir -p /home/chip/.ssh
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
ExecStart=/bin/sh -c 'echo none > /sys/class/leds/chip\:white\:status/trigger'

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

setupBash() {
    sed -ri 's/#(shopt -s globstar)/\1/' /home/chip/.bashrc
    sed -ri 's/#(export GCC_COLORS=)/\1/' /home/chip/.bashrc
    sed -ri 's/#(alias)/\1/' /home/chip/.bashrc
    cat <<'EOF' >> /home/chip/.bashrc

[[ $- = *i* ]] && source /opt/liquidprompt/liquidprompt
EOF

    cat /home/chip/.bashrc > /root/.bashrc
}

setupNginx() {
    sed -ri 's/#(server_names_hash_bucket_size 64;)/\1/' /etc/nginx/nginx.conf
    cat << EOF > /etc/nginx/sites-available/$HOST_NAME
server {
    listen 80;
    listen [::]:80;

	root /var/www/html/$HOST_NAME;
    index index.html index.htm index.php;
    server_name $HOST_NAME;
    try_files \$uri \$uri/ =404;
    server_tokens off;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php7.1-fpm.sock;
    }
}
EOF

    mkdir /var/www/html/$HOST_NAME
    ln -s /etc/nginx/sites-available/$HOST_NAME /etc/nginx/sites-enabled/$HOST_NAME
    rm /etc/nginx/sites-enabled/default

    systemctl restart nginx
}

setupMariaDb() {
    cat <<'EOF' > /etc/mysql/conf.d/$HOST_NAME.cnf
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
    sed -ri 's/(display_errors =) Off/\1 stderr/' /etc/php/7.1/cli/php.ini
    sed -ri "s:;?(date\.timezone =):\1 $TIMEZONE:" /etc/php/7.1/cli/php.ini
    sed -ri 's/(mail\.add_x_header =) On/\1 Off/' /etc/php/7.1/cli/php.ini

    sed -ri 's/(display_errors =) Off/\1 On/' /etc/php/7.1/fpm/php.ini
    sed -ri 's/(upload_max_filesize =) 2M/\1 20M/' /etc/php/7.1/fpm/php.ini
    sed -ri "s:;?(date\.timezone =):\1 $TIMEZONE:" /etc/php/7.1/fpm/php.ini
    sed -ri 's/(mail\.add_x_header =) On/\1 Off/' /etc/php/7.1/fpm/php.ini
    sed -ri 's/(session\.use_strict_mode =) 0/\1 1/' /etc/php/7.1/fpm/php.ini

    sed -ri 's/(pm =) dynamic/\1 ondemand/' /etc/php/7.1/fpm/pool.d/www.conf
    sed -ri 's:;(chdir = /var/www):\1/html:' /etc/php/7.1/fpm/pool.d/www.conf

    systemctl restart php7.1-fpm

    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
}

if [ -z "$*" ]; then
    smul=$(tput smul)
    rmul=$(tput rmul)

    cat << EOF
${smul}Usage:${rmul} $(basename "$0") <step>

${smul}Available steps:${rmul}
network
kernel
aptitude
system
firewall
ssh
blink
liquidprompt
bash
nginx
php
EOF
else
    $(typeset -F | sed 's/^declare -f //' | grep -i "setup$1")
fi
