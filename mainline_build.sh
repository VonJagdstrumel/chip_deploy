#!/usr/bin/env bash

. "$(dirname "$BASH_SOURCE")/setup_vars.sh"

apt update && apt full-upgrade -y
apt install -y fakeroot kernel-package gcc-$BUILD_TGT_ARCH binutils-$BUILD_TGT_ARCH libncurses-dev ccache bison flex libssl-dev

rm -rf \
    boot \
    lib \
    usr
mkdir -p \
    boot \
    lib/firmware/$BUILD_FULL_VERSION \
    usr/lib/linux-image-$BUILD_FULL_VERSION

wget $BUILD_KERN_URL
tar xf $BUILD_KERN_ARCHIVE
cd $BUILD_KERN_SRC

# Even with these patches, the mainline kernel can't boot as it doesn't read the NAND properly
for i in c123f63 3bdcf32 4c84048 c4093bb; do
    curl https://github.com/kaplan2539/ntc-linux/commit/$i.diff | patch -p1
done

# Custom yet untested lightweight kconfig
scripts/kconfig/merge_config.sh -m \
    /vagrant/config \
    /vagrant/in/01_multi_v7.config \
    /vagrant/in/02_sunxi.config \
    /vagrant/in/03_chip.config >/dev/null

make olddefconfig clean
make -j $BUILD_CPU_COUNT CC="ccache $BUILD_TGT_ARCH-gcc"
make -j $BUILD_CPU_COUNT zinstall modules_install
cd $BUILD_WORKSPACE

cp $BUILD_KERN_SRC/arch/arm/boot/dts/sun5i-r8-chip.dtb usr/lib/linux-image-$BUILD_FULL_VERSION/sun5i-r8-chip.dtb
find lib/firmware -mindepth 1 -maxdepth 1 ! -name $BUILD_FULL_VERSION -exec mv {} lib/firmware/$BUILD_FULL_VERSION/. \;
rm lib/modules/$BUILD_FULL_VERSION/build lib/modules/$BUILD_FULL_VERSION/source

for i in boot lib usr; do
    tar caf /vagrant/out/${BUILD_FULL_VERSION}_$i.tgz $i
done
