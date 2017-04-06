#!/bin/bash

. setup_vars.sh

setupNetwork() {
    systemctl stop networking
    systemctl stop wpa_supplicant
    systemctl disable networking
    systemctl disable wpa_supplicant

    wpa_passphrase "$WPA_SSID" "$WPA_PSK" > /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
    chmod go-rwx /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
    rm /etc/resolv.conf
    ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf

    cat <<'EOF' > /etc/systemd/network/20-wired.network
[Match]
Name=usb0

[Network]
DHCP=yes
EOF
    cat <<'EOF' > /etc/systemd/network/25-wireless.network
[Match]
Name=wlan0

[Network]
DHCP=yes
EOF
    cat <<'EOF' > /etc/systemd/system/wpa_supplicant@.service
[Unit]
Description=WPA supplicant daemon (interface-specific version)
Requires=sys-subsystem-net-devices-%i.device
After=sys-subsystem-net-devices-%i.device
Before=network.target
Wants=network.target

# NetworkManager users will probably want the dbus version instead.

[Service]
Type=simple
ExecStart=/sbin/wpa_supplicant -c/etc/wpa_supplicant/wpa_supplicant-%I.conf -i%I

[Install]
Alias=multi-user.target.wants/wpa_supplicant@%i.service
EOF

    sed -ri "s/#(NTP)=/\1=0.debian.pool.ntp.org 1.debian.pool.ntp.org 2.debian.pool.ntp.org 3.debian.pool.ntp.org/" /etc/systemd/timesyncd.conf
    sed -ri "s/#(LLMNR)=.*/\1=yes/" /etc/systemd/resolved.conf
    #echo DNSStubListener=no >> /etc/systemd/resolved.conf

    systemctl enable systemd-networkd
    systemctl enable systemd-resolved
    systemctl enable wpa_supplicant@wlan0
    systemctl start systemd-resolved
    systemctl start wpa_supplicant@wlan0
    systemctl start systemd-timesyncd
}

setupKernel() {
    tar -xf boot.tgz
    mv boot/* /boot
    ln -sf /boot/vmlinuz-$LINUX_VERSION /boot/zImage
    ln -sf /boot/dtbs/$LINUX_VERSION/sun5i-r8-chip.dtb /boot/sun5i-r8-chip.dtb
    rm boot.tgz
    rm -rf boot

    tar -xf lib.tgz
    cp -r lib/modules/$LINUX_VERSION /lib/modules
    mv lib/firmware /lib/firmware/$LINUX_VERSION
    rm lib.tgz
    rm -rf lib

    mkinitramfs -o initrd.img-$LINUX_VERSION $LINUX_VERSION
    mv initrd.img-$LINUX_VERSION /boot
}

setupAptitude() {
    sed -ri "s/us(\.debian\.org)/$MIRROR\1/" /etc/apt/sources.list
    cat <<'EOF' >> /etc/apt/sources.list
deb http://ppa.launchpad.net/webupd8team/java/ubuntu xenial main
EOF
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys EEA14886
    apt-get update
    apt-get dist-upgrade -y
    apt-get install -y ${INST_PACKAGES[@]}
    apt-get install -y -t jessie-backports ${INST_PACKAGES_BPO[@]}
}

setupSystem() {
    cat <<'EOF' > /etc/sysctl.d/90-$HOST_NAME.conf
kernel.core_uses_pid=1
kernel.sysrq=0
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.all.bootp_relay=0
net.ipv4.conf.all.forwarding=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.wlan0.accept_source_route=0
net.ipv4.conf.wlan0.log_martians=1
net.ipv4.conf.wlan0.rp_filter=1
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.icmp_ignore_bogus_error_responses=1
net.ipv4.ip_forward=0
net.ipv4.ip_local_port_range=24576 65534
net.ipv4.tcp_abort_on_overflow=1
net.ipv4.tcp_dsack=1
net.ipv4.tcp_fack=1
net.ipv4.tcp_fin_timeout=30
net.ipv4.tcp_keepalive_time=1800
net.ipv4.tcp_max_syn_backlog=4096
net.ipv4.tcp_retries1=3
net.ipv4.tcp_sack=1
net.ipv4.tcp_syn_retries=3
net.ipv4.tcp_synack_retries=2
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_timestamps=0
net.ipv4.tcp_tw_recycle=0
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_window_scaling=1
net.ipv6.conf.all.accept_ra_defrtr=0
net.ipv6.conf.all.accept_ra_pinfo=0
net.ipv6.conf.all.accept_ra_rtr_pref=0
net.ipv6.conf.all.accept_source_route=0
net.ipv6.conf.all.autoconf=0
net.ipv6.conf.all.dad_transmits=0
net.ipv6.conf.all.router_solicitations=0
EOF
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
    mv etc/ /
    sed -ri 's/(startup)=0/\1=1/' /etc/default/shorewall*
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
    wget -O /usr/local/bin/blink.sh http://fordsfords.github.io/blink/blink.sh
    chmod +x /usr/local/bin/blink.sh
    wget -O /etc/systemd/system/blink.service http://fordsfords.github.io/blink/blink.service
    wget -O /usr/local/etc/blink.cfg http://fordsfords.github.io/blink/blink.cfg
    sed -ri 's/(BLINK_STATUS=1)/#\1/' /usr/local/etc/blink.cfg
    systemctl enable blink
    systemctl start blink

    cat <<'EOF' > /etc/systemd/system/blink-disable.service
[Unit]
Description=blink-disable
After=blink.service

[Service]
Type=simple
ExecStart=/bin/sh -c 'echo none > /sys/class/leds/chip\:white\:status/trigger'

[Install]
WantedBy=blink.service
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
    cat /home/chip/.bashrc > /root/.bashrc
    sed -ri 's/#(shopt -s globstar)/\1/' /root/.bashrc
    sed -ri 's/#(export GCC_COLORS=)/\1/' /root/.bashrc
    sed -ri 's/#(alias)/\1/' /root/.bashrc
    cat <<'EOF' >> /root/.bashrc

[[ $- = *i* ]] && source /opt/liquidprompt/liquidprompt
EOF
    cat /root/.bashrc > /home/chip/.bashrc
}

setupNginx() {
    sed -ri 's/#(server_names_hash_bucket_size 64;)/\1/' /etc/nginx/nginx.conf
    cat << EOF > /etc/nginx/sites-available/$HOST_NAME
server {
	listen 80;
	listen [::]:80;

	root /var/www/html;
	index index.html index.htm index.php;
	server_name $HOST_NAME;
	try_files \$uri \$uri/ =404;
	server_tokens off;
	gzip_comp_level 6;
	gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

	location ~ \.php$ {
		include snippets/fastcgi-php.conf;
		fastcgi_pass unix:/var/run/php-fpm.sock;
	}
}
EOF
    ln -s /etc/nginx/sites-available/$HOST_NAME /etc/nginx/sites-enabled/$HOST_NAME
    rm /etc/nginx/sites-enabled/default
    rm /var/www/html/index.nginx-debian.html
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

character-set-server = utf8
collation-server = utf8_unicode_ci
init-connect='SET NAMES utf8'
EOF
    systemctl restart mysql
}

setupPhp() {
    apt-get install -y -t jessie-backports ${PHP_PACKAGES[@]}
    ln -s /usr/include/arm-linux-gnueabihf/gmp.h /usr/include/gmp.h

    for i in {1..3}
    do
       wget http://$MIRROR$i.php.net/distributions/$PHP_NAME.tar.gz && break
    done
    tar -xf $PHP_NAME.tar.gz
    rm $PHP_NAME.tar.gz
    cd $PHP_NAME

    ./configure ${PHP_CONFIGURE[@]}
    make
    make install

    mv php.ini-production /usr/local/lib/php.ini
    sed -ri 's/(short_open_tag =) Off/\1 On/' /usr/local/lib/php.ini
    sed -ri 's/(expose_php =) On/\1 Off/' /usr/local/lib/php.ini
    sed -ri 's/(display_errors =) Off/\1 On/' /usr/local/lib/php.ini
    sed -ri 's/(upload_max_filesize =) 2M/\1 8M/' /usr/local/lib/php.ini
    sed -ri "s/;?(date\.timezone =)/\1 $TIMEZONE/" /usr/local/lib/php.ini
    sed -ri 's/(mail\.add_x_header =) On/\1 Off/' /usr/local/lib/php.ini
    sed -ri 's/(session\.use_strict_mode =) 0/\1 1/' /usr/local/lib/php.ini
    line=$(($(sed -n '/extension=/{=}' /usr/local/lib/php.ini | tail -n 1)+1))
    sed -i $line'izend_extension=opcache.so' /usr/local/lib/php.ini

    mv /usr/local/etc/php-fpm.conf.default /usr/local/etc/php-fpm.conf
    sed -ri 's:(include=)NONE/(etc/php-fpm\.d/\*\.conf):\1\2:' /usr/local/etc/php-fpm.conf

    mv /usr/local/etc/php-fpm.d/www.conf.default /usr/local/etc/php-fpm.d/www.conf
    sed -ri 's/;(listen.(user|group) =) (nobody|www-data)/\1 www-data/' /usr/local/etc/php-fpm.d/www.conf
    sed -ri 's/;(listen.mode) = 0660)/\1/' /usr/local/etc/php-fpm.d/www.conf
    sed -ri 's:(listen =) 127\.0\.0\.1\:9000:\1 /var/run/php-fpm.sock:' /usr/local/etc/php-fpm.d/www.conf
    sed -ri 's/(pm =) dynamic/\1 static/' /usr/local/etc/php-fpm.d/www.conf
    sed -ri 's/(pm.max_children =) 5/\1 1/' /usr/local/etc/php-fpm.d/www.conf
    sed -ri 's:;(chdir = /var/www):\1/html:' /usr/local/etc/php-fpm.d/www.conf

    wget http://packages.dotdeb.org/pool/all/p/php7.0/php7.0-fpm_7.0.14-1~dotdeb+8.1_i386.deb
    ar vx php7.0-fpm_7.0.14-1~dotdeb+8.1_i386.deb
    tar -xf data.tar.xz
    mv lib/systemd/system/php7.0-fpm.service /lib/systemd/system/php-fpm.service
    sed -ri 's/(php)(7\.0)?(-fpm)(7\.0)?/\1\3/' /lib/systemd/system/php-fpm.service
    sed -ri 's:(/usr)(/sbin/):\1/local\2:' /lib/systemd/system/php-fpm.service
    sed -ri 's:/(etc/)php/7\.0/fpm/(php-fpm\.conf):/usr/local/\1\2:' /lib/systemd/system/php-fpm.service
    systemctl enable php-fpm
    systemctl start php-fpm

    cd ..
    rm -r $PHP_NAME

    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

    rm /usr/include/gmp.h
    apt-get remove --purge -y ${PHP_PACKAGES[@]}
    apt-get autoremove --purge -y
}

[ "$0" != "$BASH_SOURCE" ] && return

apt-get remove --purge -y ${PURGE_PACKAGES[@]}
apt-get autoremove --purge -y
setupNetwork
setupKernel
setupAptitude
setupSystem
setupFirewall
setupSsh
setupBlink
setupLiquidPrompt
setupBash
setupNginx
setupMariaDb
setupPhp
