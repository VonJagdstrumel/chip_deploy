#!/usr/bin/env bash

. "$(dirname "$BASH_SOURCE")/setup_vars.sh"

apt update && apt full-upgrade -y
apt install -y fakeroot kernel-package gcc-$BUILD_TGT_ARCH binutils-$BUILD_TGT_ARCH libncurses-dev ccache

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

cp /vagrant/config .config

make olddefconfig clean
make -j $BUILD_CPU_COUNT CC="ccache $BUILD_TGT_ARCH-gcc"
make -j $BUILD_CPU_COUNT zinstall modules_install
cd $BUILD_WORKSPACE

wget $BUILD_WXAN_URL
tar xf $BUILD_WXAN_ARCHIVE
cd $BUILD_WXAN_SRC

for i in debian/patches/0*; do
    patch -p 1 <$i
done

make clean
make -j $BUILD_CPU_COUNT -C $BUILD_WORKSPACE/$BUILD_KERN_SRC/ M=$PWD CC="ccache $BUILD_TGT_ARCH-gcc"
make -j $BUILD_CPU_COUNT -C $BUILD_WORKSPACE/$BUILD_KERN_SRC/ M=$PWD modules_install
cd $BUILD_WORKSPACE

cp $BUILD_KERN_SRC/arch/arm/boot/dts/sun5i-r8-chip.dtb usr/lib/linux-image-$BUILD_FULL_VERSION/sun5i-r8-chip.dtb
find lib/firmware -mindepth 1 -maxdepth 1 ! -name $BUILD_FULL_VERSION -exec mv {} lib/firmware/$BUILD_FULL_VERSION/. \;
rm lib/modules/$BUILD_FULL_VERSION/build lib/modules/$BUILD_FULL_VERSION/source

for i in boot lib usr; do
    tar caf /vagrant/out/${BUILD_FULL_VERSION}_$i.tgz $i
done
