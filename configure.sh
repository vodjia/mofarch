#!/bin/sh

source .resource

# Configure the system

## Time zone
echo "Setting the time zone..."
ln -sf /usr/share/zoneinfo/$REGION/$CITY /etc/localtime
echo "Running hwclock to generate /etc/adjtime..."
hwclock --systohc
echo "This command assumes the hardware clock is set to UTC."

## Localization
cp ./etc/locale.gen /etc/locale.gen
echo "Generating the locales..."
locale-gen
echo "Setting the LANG variable..."
cp ./etc/locale.conf /etc/locale.conf

if [ ! -z $KEYMAP ]
then
    echo "Making the console keyboard layout persistent..."
    echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf
fi

## Network configuration
echo "Creating the hostname file..."
echo $HOSTNAME > /etc/hostname
echo "Matching entries to hosts..."
echo "127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.0.1\t$HOSTNAME" > /etc/hosts

## Initramfs
### Creating a new initramfs is usually not required, because mkinitcpio was run on installation of the kernel package with pacstrap.
### For LVM, system encryption or RAID, modify mkinitcpio.conf(5), uncomment the following command and recreate the initramfs image:
### mkinitcpio -P

## Root password
echo "Setting the root password..."
passwd

## Boot loader
echo "Installing GRUB..."
pacman -S grub efibootmgr
if [ ! -d /efi ]
then
    mkdir /efi
fi
grub-install --target=x86_64-efi --efi-directory=efi --bootloader-id=GRUB
echo "Generating `/boot/grub/grub.cfg`..."
grub-mkconfig -o /boot/grub/grub.cfg
echo "Enabling microcode updates (if you have an Intel or AMD CPU)..."
if [ $CPU_MANUFACTURER = "amd" ]
then
    pacman -S amd-ucode
fi
if [ $CPU_MANUFACTURER = "intel" ]
then
    pacman -S intel-ucode
fi

## Users and groups
echo "Creating user '$HOME_USERNAME'..."
useradd -m $HOME_USERNAME

# Switch user
echo "Switching to '$HOME_USERNAME'..."
su - $HOME_USERNAME
