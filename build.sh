#!/bin/bash

set -euxo pipefail
. build_vars.sh

cpuCount=`nproc`
workspace=$PWD
kernRepo=ntc-linux
kernBranch=ntc-stable-mlc-$KERNEL_VERSION
buildPath=$kernRepo-$kernBranch
archBuild=arm-linux-gnueabihf

apt-get update
apt-get install -y fakeroot kernel-package gcc-$archBuild binutils-$archBuild

export ARCH=arm
export CROSS_COMPILE=/usr/bin/$archBuild-
export INSTALL_MOD_PATH=$workspace

wget https://github.com/kaplan2539/$kernRepo/archive/$kernBranch.tar.gz
tar xf $kernBranch.tar.gz
cd $buildPath

cp /vagrant/config .config

make olddefconfig
make -j $cpuCount
make -j $cpuCount modules_install
cd $workspace

wget https://github.com/kaplan2539/rtl8723bs/archive/debian.tar.gz
tar xf debian.tar.gz
cd RTL8723BS-debian

for i in debian/patches/0*; do
    patch -p 1 <$i
done

make -j $cpuCount CONFIG_PLATFORM_ARM_SUNxI=y -C $workspace/$buildPath/ M=$PWD CONFIG_RTL8723BS=m
make -j $cpuCount CONFIG_PLATFORM_ARM_SUNxI=y -C $workspace/$buildPath/ M=$PWD CONFIG_RTL8723BS=m modules_install
cd $workspace

mkdir -p boot
mkdir -p lib/firmware/$LINUX_VERSION
mkdir -p usr/lib/linux-image-$LINUX_VERSION

cp $buildPath/arch/arm/boot/zImage boot/vmlinuz-$LINUX_VERSION
cp $buildPath/.config boot/config-$LINUX_VERSION
cp $buildPath/System.map boot/System.map-$LINUX_VERSION
cp $buildPath/arch/arm/boot/dts/sun5i-r8-chip.dtb usr/lib/linux-image-$LINUX_VERSION/sun5i-r8-chip.dtb

find lib/firmware -mindepth 1 -maxdepth 1 ! -name 4.4.139-chip -exec mv {} lib/firmware/4.4.139-chip/. \;
rm lib/modules/$LINUX_VERSION/build lib/modules/$LINUX_VERSION/source

tar caf /vagrant/build/boot.tgz boot
tar caf /vagrant/build/lib.tgz lib
tar caf /vagrant/build/usr.tgz usr
