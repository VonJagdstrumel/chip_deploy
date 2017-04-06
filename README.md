# chip_deploy

Basic deploy scripts for [Next Thing Co. C.H.I.P.](https://getchip.com/pages/chip)

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
