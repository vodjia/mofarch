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
pacstrap /mnt $ESSENTIAL_PACKAGES

# Configure the system

## Fstab
echo "Generating fstab file..."
genfstab -U /mnt >> /mnt/etc/fstab
echo "Check the resulting /mnt/etc/fstab file, and edit it in case of errors."

## Chroot
echo "Changing root into the new system..."
arch-chroot /mnt

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
echo "Enabling NetworkManager..."
systemctl enable NetworkManager.service

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

# Post-installation

## Paru
echo "Installing paru..."
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si

## Zsh
echo "Installing zsh..."
pacman -S zsh zsh-completions
echo "Changing default shell to zsh..."
chsh -s /usr/bin/zsh
echo "Installing Oh My Zsh..."
paru -S oh-my-zsh-git

## Users and groups
echo "Creating user '$USERNAME'..."
useradd -m $USERNAME -s /usr/bin/zsh

## Reflector
echo "Installing Reflector..."
pacman -S reflector
echo "Enabling Reflector..."
systemctl enable reflector.service

## Xorg
echo "Installing Xorg..."
pacman -S xorg

## Drivers
echo "Installing Drivers..."
if [ $GPU_MANUFACTURER = "amd" ]
then
    pacman -S xf86-video-amdgpu
fi
if [ $GPU_MANUFACTURER = "intel" ]
then
    pacman -S xf86-video-intel
fi
if [ $GPU_MANUFACTURER = "nvidia" ]
then
    pacman -S nvidia
fi

## KDE
echo "Installing Plasma and KDE applications..."
pacman -S plasma-meta kde-applications-meta

## SDDM
echo "Enabling SDDM..."
systemctl enable sddm.service

## Fonts
echo "Installing Chinese fonts..."
pacman -S wqy-microhei wqy-microhei-lite wqy-bitmapfont wqy-zenhei ttf-arphic-ukai ttf-arphic-uming adobe-source-han-sans-cn-fonts adobe-source-han-serif-cn-fonts noto-fonts-cjk
echo "Installing Microsoft fonts..."
pacman -S ttf-ms-fonts

## Browser
echo "Installing $BROWSER..."
pacman -S $BROWSER

## Email client
echo "Installing $EMAIL_CLIENT..."
pacman -S $EMAIL_CLIENT

# Reboot
echo "Exiting the chroot environment..."
exit
## Optionally manually unmount all the partitions with umount -R /mnt: this allows noticing any "busy" partitions, and finding the cause with fuser.
echo "Rebooting..."
reboot
