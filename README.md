# chip_install

Basic install script for [Next Thing Co. C.H.I.P.](https://web.archive.org/web/20180626203032/https://getchip.com/pages/chip)

**Disclaimer:** This project is highly experimental and may completely mess up. The worst that can happen is you'll have to reflash your C.H.I.P.

> [Oh boy, look at this beauty!](https://i.imgur.com/FVxTQPg.jpg)

## Components

- Custom kernel build
    - [Patched Linux 4.4.139](https://github.com/kaplan2539/ntc-linux/tree/ntc-stable-mlc-4.4.139)
    - [Patched RTL8723BS driver](https://github.com/kaplan2539/rtl8723bs/tree/debian)
    - Custom configuration
        - NetFilter modules
        - TCP syncookies
- systemd-networkd + systemd-resolved + wpa_supplicant instead of NetworkManager + avahi-daemon
- [C.H.I.P. APT repository](http://chip.jfpossibilities.com/chip/debian/)
- [Oracle JDK APT repository](https://launchpad.net/~webupd8team/+archive/ubuntu/java)
- Sysctl security parameters
- Shorewall rulesets
- [Liquid Prompt](https://github.com/nojhan/liquidprompt)
- Nginx + PHP-FPM setup
- MariaDB

## Building kernel

Build the kernel in a Vagrant virtual machine as it's a pretty resource intensive process.

```sh
vagrant up
vagrant ssh
mkdir -p ~/chip_workdir && cd $_
sudo /vagrant/build.sh
```

In the `build` folder, there are:

- `boot.tgz`
    - `vmlinuz`
    - `System.map`
    - `config`
- `lib.tgz`
    - `modules`
    - `firmware`

## Setup

Flash the C.H.I.P. with the latest headless Debian image from Next Thing Co. C.H.I.P.

Login through a serial terminal to the C.H.I.P.

```sh
sudo nmcli device wifi connect '(your wifi network name/SSID)' password '(your wifi password)' ifname wlan0
```

`scp` your `out` folder to the chip.

```sh
mkdir -p ~/chip_workdir && cd $_
wget https://github.com/VonJagdstrumel/chip_deploy/archive/master.tar.gz
tar xf master.tar.gz
cd chip_install-master
```

Edit `setup_vars.sh` according to your needs.

```sh
sudo ./setup.sh aptitude
sudo ./setup.sh kernel
sudo ./setup.sh system
sudo ./setup.sh network
sudo ./setup.sh ssh
sudo ./setup.sh firewall
sudo ./setup.sh blink
sudo ./setup.sh liquidprompt
sudo ./setup.sh nginx
sudo ./setup.sh php
```

Follow the instructions.

## Todo

- Basic output to console
- Verbose output to logfiles
- Check if step has run once
