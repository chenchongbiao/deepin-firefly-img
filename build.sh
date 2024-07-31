#!/bin/bash

set -e -u -x

sudo apt update

# 不进行交互安装
export DEBIAN_FRONTEND=noninteractive
ROOTFS=`mktemp -d`
DIST_VERSION="beige"
DIST_NAME="deepin"
SOURCES_FILE=config/apt/sources.list
PACKAGES_FILE=config/packages.list/packages.list
readarray -t REPOS < $SOURCES_FILE
PACKAGES=`cat $PACKAGES_FILE | grep -v "^-" | xargs | sed -e 's/ /,/g'`
IMG_NAME=$DIST_NAME-rootfs.img

sudo apt update -y && sudo apt install -y curl git mmdebstrap qemu-user-static usrmerge systemd-container usrmerge
# 开启异架构支持
sudo systemctl start systemd-binfmt

dd if=/dev/zero of=$IMG_NAME bs=1M count=2048
mkfs.ext4 -F -m 0 -L rootfs $IMG_NAME

sudo mount -o loop $IMG_NAME $ROOTFS

sudo mmdebstrap \
    --hook-dir=/usr/share/mmdebstrap/hooks/merged-usr \
    --include=$PACKAGES \
    --components="main,commercial,community" \
    --variant=minbase \
    --architectures=arm64 \
    --customize=./config/hooks.chroot/second-stage \
    $DIST_VERSION \
    $ROOTFS \
    "${REPOS[@]}"

sudo cp config/adb/adbd $ROOTFS/usr/local/bin/
sudo cp config/adb/adbd.service $ROOTFS/usr/lib/systemd/system/
sudo cp config/adb/adbd.service $ROOTFS/etc/systemd/system/multi-user.target.wants/
sudo ln -s $$ROOTFS/usr/lib/systemd/system/adbd.service $$ROOTFS/etc/systemd/system/multi-user.target.wants/adbd.service
sudo cp config/adb/adbd.sh $ROOTFS/etc/init.d/
sudo cp config/adb/.usb_config $ROOTFS/etc/init.d/

sudo umount $ROOTFS
sudo rmdir $ROOTFS
