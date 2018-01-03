#!/bin/bash

. build_kernel.vars

apt-get update
apt-get install -y git build-essential fakeroot kernel-package zlib1g-dev libncurses5-dev lzop gcc-arm-linux-gnueabihf binutils-arm-linux-gnueabihf

workspace=$PWD
buildPath=CHIP-linux-debian-$LINUX_VERSION
export ARCH=arm
export CROSS_COMPILE=/usr/bin/arm-linux-gnueabihf-
export INSTALL_MOD_PATH=$workspace

wget https://github.com/NextThingCo/CHIP-linux/archive/debian/$LINUX_VERSION.tar.gz
tar -xf $LINUX_VERSION.tar.gz
rm $LINUX_VERSION.tar.gz
cd $buildPath

cp /vagrant/config .config
make olddefconfig
make
make modules_install
cd $workspace

wget https://github.com/NextThingCo/RTL8723BS/archive/debian.tar.gz
tar -xf debian.tar.gz
rm debian.tar.gz
cd RTL8723BS-debian

for i in debian/patches/0*
do
    patch -p 1 <$i
done
make CONFIG_PLATFORM_ARM_SUNxI=y -C $workspace/$buildPath/ M=$PWD CONFIG_RTL8723BS=m
make CONFIG_PLATFORM_ARM_SUNxI=y -C $workspace/$buildPath/ M=$PWD CONFIG_RTL8723BS=m modules_install
cd $workspace

mv $buildPath/arch/arm/boot/zImage boot/vmlinuz-$LINUX_VERSION
mv $buildPath/.config boot/config-$LINUX_VERSION
mv $buildPath/System.map boot/System.map-$LINUX_VERSION
rm lib/modules/$LINUX_VERSION/build lib/modules/$LINUX_VERSION/source
tar -czf /vagrant/build/boot.tgz boot
tar -czf /vagrant/build/lib.tgz lib
