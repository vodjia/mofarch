# Pre-installation

echo "Preparing installation..."

if [ ! ls /sys/firmware/efi/efivars > /dev/null ]
then
    echo "System is not booted in UEFI mode, which is currently not supported." > /dev/stderr
    exit 1
fi

source ./default.sh

if [ ! ls /usr/share/kbd/keymaps/**/$KEYMAP.map.gz > /dev/null ]
then
    echo "Keyboard layout '$KEYMAP' not found." > /dev/stderr
    exit 1
fi

if [ ! ping -c 8 archlinux.org > /dev/null ]
then
    echo "No internet connection." > /dev/stderr
    exit 1
fi

if [ ! fdisk -l /dev/$EFI_SYSTEM_PARTITION ]
then
    exit 1
fi

if [ ! fdisk -l /dev/$SWAP_PARTITION ]
then
    exit 1
fi

if [ ! fdisk -l /dev/$ROOT_PARTITION ]
then
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

echo "Setting the console keyboard layout..."
loadkeys $KEYMAP
echo "Updating the system clock..."
timedatectl set-ntp true
echo "Formatting the partitions..."
mkfs.ext4 /dev/$ROOT_PARTITION
mkswap /dev/$SWAP_PARTITION
echo "Mounting the file systems..."
echo "Mounting the root volume to `/mnt`..."
mount /dev/$ROOT_PARTITION /mnt
echo "Creating remaining mount points..."
mount /dev/$EFI_SYSTEM_PARTITION /mnt/efi
echo "Enabling swap volume..."
swapon /dev/$SWAP_PARTITION
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
echo "Making the console keyboard layout persistent..."
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

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

# Reboot
echo "Exiting the chroot environment..."
exit
## Optionally manually unmount all the partitions with umount -R /mnt: this allows noticing any "busy" partitions, and finding the cause with fuser.
echo "Rebooting..."
reboot
