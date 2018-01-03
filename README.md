# chip_install

Basic install script for [Next Thing Co. C.H.I.P.](https://getchip.com/pages/chip)

**Disclaimer:** This project is highly experimental and may completely mess up. The worst that can happen is you'll have to reflash your C.H.I.P.

> [Oh boy, look at this beauty!](https://i.imgur.com/FVxTQPg.jpg)

## Components

- Custom kernel build
    - [C.H.I.P.'s official repository](https://github.com/NextThingCo/CHIP-linux/tree/debian/4.4.13-ntc-mlc)
    - Custom configuration
        - NetFilter modules
        - TCP syncookies
- Use of systemd-networkd + systemd-resolved + wpa_supplicant instead of NetworkManager + avahi-daemon
- [APT repository for Oracle JDK](https://launchpad.net/~webupd8team/+archive/ubuntu/java)
- Sysctl security parameters
- Shorewall rulesets
- [Liquid Prompt](https://github.com/nojhan/liquidprompt)
- Nginx + PHP-FPM setup
- MariaDB

## Building kernel

Build the kernel in a Vagrant virtual machine as it's a pretty pretty resource intensive process.

```sh
vagrant up
vagrant ssh
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

`scp` your `build` folder to the chip.

```sh
wget https://github.com/VonJagdstrumel/chip_deploy/archive/master.tar.gz
tar xf master.tar.gz
cd chip_deploy-master
mv ../build/ .
```

Edit `setup_vars.sh` according to your needs.

```sh
sudo ./setup.sh
```

Follow the instructions.

## Todo

- Basic output to console
- Verbose output to logfiles
- Check if step has run once
