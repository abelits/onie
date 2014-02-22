#!/bin/sh -e

# This script formats the hard drive and installs ONIE on it.
# It is intended to be used from PXE or other boot environment
# that does not depend on the target drive for booting.

# Default ONIE block device

install_device_platform()
{
    # The problem we are trying to solve is:
    #
    #    How to determine the block device upon which to install ONIE?
    #
    # The question is complicated when multiple block devices are
    # present, i.e. perhaps the system has two hard drives installed
    # or maybe a USB memory stick is currently installed.  For example
    # the mSATA device usually shows up as /dev/sda under Linux, but
    # maybe with a USB drive connected the internal disk now shows as
    # /dev/sdb.
    #
    # The approach here is to look for the first drive that
    # is connected to AHCI SATA controller.

    for d in /sys/block/sd* ; do
        fname=`ls "$d/device/../../scsi_host/host"*"/proc_name"` \
            2>/dev/null || true
        if [ -e "$fname" ] ; then
            if grep -i "ahci" "$fname" > /dev/null ; then
                device="/dev/$(basename $d)"
                echo $device
                return 0
            fi
        fi
    done
    echo "WARNING: Unable to find internal ONIE install device"
    echo "WARNING: expecting a hard drive connected to AHCI controller"
    return 1
}

# Installer

dstdrive=`install_device_platform`

[ -b "${dstdrive}" ] || exit 1

# Unmount everything

while [ -d /boot ]
  do
    onie-mount-parts -u
    [ -d /boot ] && sleep 2
  done

# Create new partition table with only one partition.

parted -s -a optimal "${dstdrive}" mklabel msdos
parted -s -a optimal "${dstdrive}" mkpart primary ext2 1MiB 129MiB

sync


# Wait until changed partition table is accepted.

until blockdev --rereadpt "${dstdrive}"
  do sleep 1
done

# Create boot filesystem, use "BOOT" as the label.

mkfs.ext2 -L BOOT "${dstdrive}"1

# Mount it.

until [ -d /boot ]
  do
    onie-mount-parts
    [ -d /boot ] || sleep 2
  done

# Copy ONIE installation.

cp /self-installer/onie.initrd /self-installer/onie.vmlinuz /boot/

# Configure and install GRUB

cp -r /usr/lib/grub/i386-pc /boot/grub

onie-boot-init -f
onie-boot-update

# Mount the boot filesystem again

until [ -d /boot ]
  do
    onie-mount-parts
    [ -d /boot ] || sleep 2
  done

grub-install "${dstdrive}"

# Unmount everything

while [ -d /boot ]
  do
    onie-mount-parts -u
    [ -d /boot ] && sleep 2
  done

# Sync

sync

# ONIE is now installed on otherwise empty hard drive.
