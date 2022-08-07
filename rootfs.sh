rm -rf ramdisk
mkdir -p ramdisk
pushd ramdisk >/dev/null

cp -r ../busybox*/_install/* .
ln -s bin/busybox init
mkdir -pv {bin,sbin,etc,proc,sys,usr/{bin,sbin},dev}

cat <<EOF > etc/inittab
::sysinit:/etc/init.d/rcS   
::askfirst:-/bin/sh    
::restart:/sbin/init
::ctrlaltdel:/sbin/reboot
::shutdown:/bin/umount -a -r
::shutdown:/sbin/swapoff -a
EOF

chmod +x etc/inittab

mkdir etc/init.d

cat <<EOF > etc/init.d/rcS
#!/bin/sh

mount proc
mount -o remount,rw /
mount -a    
clear                               
echo "My Tiny Linux Start :D ......"
EOF

chmod +x etc/init.d/rcS

cat <<EOF > etc/fstab
proc            /proc        proc    defaults          0       0

sysfs           /sys         sysfs   defaults          0       0

devtmpfs        /dev         devtmpfs  defaults          0       0
EOF

find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../initramfs.img
