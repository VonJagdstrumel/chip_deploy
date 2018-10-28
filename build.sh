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

mkdir boot
cp $buildPath/arch/arm/boot/zImage boot/vmlinuz-$LINUX_VERSION
cp $buildPath/.config boot/config-$LINUX_VERSION
cp $buildPath/System.map boot/System.map-$LINUX_VERSION
rm lib/modules/$LINUX_VERSION/build lib/modules/$LINUX_VERSION/source
tar czf /vagrant/build/boot.tgz boot
tar czf /vagrant/build/lib.tgz lib
