# chip_install

Basic install script for [Next Thing Co. C.H.I.P.](https://getchip.com/pages/chip)

## Components

- Custom kernel build
    - [C.H.I.P.'s official repository](https://github.com/NextThingCo/CHIP-linux/tree/debian/4.4.13-ntc-mlc)
    - Custom configuration
        - NetFilter modules
        - TCP syncookies
- Use of systemd-networkd + systemd-resolved + wpa_supplicant instead of NetworkManager
- [APT repository for Oracle JDK](https://launchpad.net/~webupd8team/+archive/ubuntu/java)
- Sysctl security parameters
- Shorewall rulesets
- [Graceful shutdown through configurable trigger + LED control](https://github.com/fordsfords/blink)
- [Liquid Prompt](https://github.com/nojhan/liquidprompt)
- Custom PHP static build
- Nginx + PHP-FPM setup
- MariaDB

## Building kernel

Building the kernel is pretty resource intensive. We'll build it in a Vagrant virtual machine.

```sh
vagrant up
vagrant ssh
/vagrant/build.sh
```

In the build folder, we'll have:

- `boot.tgz`
    - `vmlinuz`
    - `System.map`
    - `config`
    - `dtbs`
- `lib.tgz`
    - `modules`
    - `firmware`

## Setup C.H.I.P.

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
./setup.sh
```
