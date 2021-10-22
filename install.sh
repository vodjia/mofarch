#!/bin/zsh

# Pre-installation

echo "Preparing installation..."

## Verify the boot mode
echo "Verying the boot mode..."
if ! ls /sys/firmware/efi/efivars > /dev/null
then
    echo "System is not booted in UEFI mode, which is currently not supported." > /dev/stderr
    exit 1
fi
echo "The system is booted in UEFI mode."

source ./.installrc

if [ ! -z $KEYMAP ]
then
    if ! ls /usr/share/kbd/keymaps/**/$KEYMAP.map.gz
    then
	echo "Keyboard layout '$KEYMAP' not found." > /dev/stderr
	exit 1
    fi
else
    echo "Using default keymap: US..."
fi

echo "Verifying internet connection..."
if ! ping -c 8 archlinux.org > /dev/null
then
    echo "No internet connection." > /dev/stderr
    exit 1
fi
echo "Internet connection established."

if ! fdisk -l /dev/$EFI_SYSTEM_PARTITION
then
    echo "EFI system partition '$EFI_SYSTEM_PARTITION' not found." >> /dev/stderr
    exit 1
fi

if ! fdisk -l /dev/$SWAP_PARTITION
then
    echo "Swap partition '$SWAP_PARTITION' not found." >> /dev/stderr
    exit 1
fi

if ! fdisk -l /dev/$ROOT_PARTITION
then
    echo "Root partition '$ROOT_PARTITION' not found." >> /dev/stderr
    exit 1
fi

if [ ! -d /usr/share/zoneinfo/$REGION ]
then
    echo "Region '$REGION' not found." > /dev/stderr
    exit 1
fi

if [ ! -f /usr/share/zoneinfo/$REGION/$CITY ]
then
    echo "City '$CITY' not found." > /dev/stderr
    exit 1
fi

## Set the console keyboard layout
if [ ! -z $KEYMAP ]
then
    echo "Setting the console keyboard layout..."
    loadkeys $KEYMAP
fi

## Update the system clock
echo "Updating the system clock..."
timedatectl set-ntp true

## Format the partitions
echo "Formatting the partitions..."
mkfs.ext4 /dev/$ROOT_PARTITION
if [ ! -z $SWAP_PARTITION ]
then
    mkswap /dev/$SWAP_PARTITION
fi

## Mount the file systems
echo "Mounting the file systems..."
echo "Mounting the root volume to `/mnt`..."
mount /dev/$ROOT_PARTITION /mnt
echo "Creating remaining mount points..."
mount /dev/$EFI_SYSTEM_PARTITION /mnt/efi
if [ ! -z $SWAP_PARTITION ]
then
    echo "Enabling swap volume..."
    swapon /dev/$SWAP_PARTITION
fi
echo "genfstab will later detect mounted file systems and swap space"

# Installation
echo "Installing essential packages..."
pacstrap /mnt base linux linux-firmware

## Fstab
echo "Generating fstab file..."
genfstab -U /mnt >> /mnt/etc/fstab
echo "Check the resulting /mnt/etc/fstab file, and edit it in case of errors."

## Copying repository
echo "Copying repository to the new system..."
cp . /mnt/opt

## Chroot
echo "Changing root into the new system..."
arch-chroot /mnt
