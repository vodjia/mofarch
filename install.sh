#!/bin/sh

set_console_keyboard_layout()
{
    echo "Setting the console keyboard layout..."
    read -p "Press enter to view available layouts..."
    ls /usr/share/kbd/keymaps/**/*.map.gz | less
    echo "To modify the layout, choose a corresponding file name to loadkeys, omitting path and file extension."
    echo "For example, to set a German keyboard layout: `loadkeys de-latin1`"
    while :
    do
	echo "Enter console keyboard layout:"
	read CONSOLE_KEYBOARD_LAYOUT
	if ls /usr/share/kbd/keymaps/**/$CONSOLE_KEYBOARD_LAYOUT.map.gz
	then
	    loadkeys $CONSOLE_KEYBOARD_LAYOUT
	    break
	fi
    done
}

verify_boot_mode()
{
    echo "Verifying the boot mode"
    if ! ls /sys/firmware/efi/efivars > /dev/null
    then
	echo "System is not booted in UEFI mode, which is currently not supported." >&2
	exit 1
    fi
}

connect_to_internet()
{
    echo "Connecting to internet..."
    echo "Ensure your network interface is listed and enabled."
    read -p "Press enter to list network interfaces..."
    ip link | less
    while :
    do
	echo "Any interface to enable? [y/N]"
	read INPUT
	if [ $INPUT != "y" ]
	then
	    break
	fi
	echo "Enter interface name:"
	read NETWORK_INTERFACE
	ip link set $NETWORK_INTERFACE up
    done
    echo "Unblocking WLAN..."
    rfkill unblock wifi
    while :
    do
	read -p "Press enter to use `iwctl`..."
	iwctl
	echo "Ready to proceed? [y/N]"
	read INPUT
	if [ $INPUT = "y" ]
	then
	    break
	fi
    done
    if ! ping -c 8 archlinux.org > /dev/null
    then
	echo "Connecting to internet failed." >&2
	exit 1
    fi
}

partition_disks()
{
    echo "Partioning the disks..."
    read -p "Please enter to list devices..."
    echo "Results ending in rom, loop or airoot may be ignored."
    fdisk -l | less
    echo "The following partitions are required for a chosen device:"
    echo "* One partition for the root directory /."
    echo "* For booting in UEFI mode: an EFI system partition."
    echo "Note: So far, a swap partition is also required in this configuration."
    echo "Layout:"
    echo "|      Mount point      |         Partition         |    Partition type     |      Suggested size     |"
    echo "| /mnt/boot or /mnt/efi | /dev/efi_system_partition | EFI system partition  |     At least 260 MiB    |"
    echo "|        [SWAP]         |    /dev/swap_partition    |      Linux swap       |    More than 512 MiB    |"
    echo "|         /mnt          |    /dev/root_partition    | Linux x86-64 root (/) | Remainder of the device |"
    echo "Note: /mnt/efi should only be considered if the used boot loader is capable of loading the kernel and initramfs images from the root volume."
    while :
    do
	echo "Enter the disk to be partitioned (for example, `/dev/the_disk_to_be_partitioned`):"
	read DISK_TO_BE_PARTITONED
	fdisk $DISK_TO_BE_PARTITIONED
	echo "Ready to proceed? [y/N]"
	if [ $INPUT = "y" ]
	then
	    break
	fi
	echo "Enter EFI system partition:"
	read EFI_SYSTEM_PARTITION
	echo "Enter Linux swap partition:"
	read SWAP_PARTITION
	echo "Enter root partition:"
	read ROOT_PARTITION
    done
    while :
    do
	echo "Note: Omit `/dev/` when entering."
	echo "Enter EFI system partition:"
	read EFI_SYSTEM_PARTITION
	echo "Enter Linux swap partition:"
	read SWAP_PARTITION
	echo "Enter root partition:"
	read ROOT_PARTITION
	echo "Ready to proceed? [y/N]"
	if [ $INPUT = "y" ]
	then
	    break
	fi
    done
}

# Pre-installation
echo "The default console keymap is US."
echo "Do you want to change the console keyboard layout? [y/N]"
read INPUT
if [ $INPUT = "y" ]
then
    set_console_keyboard_layout
fi
### "Console fonts are located in /usr/share/kbd/consolefonts/ and can likewise be set with setfont.
verify_boot_mode
connect_to_internet
echo "Updating the system clock..."
timedatectl set-ntp true
partition_disks
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
pacstrap /mnt base linux linux-firmware emacs networkmanager man-db man-pages texinfo
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
echo "Enter your region:"
read REGION
while [ ! -d /usr/share/zoneinfo/$REGION ]
do
    echo "/usr/share/zoneinfo/$REGION does not exist"
    echo "Enter your region again:"
    read REGION
done
echo "Enter your city:"
read CITY
while [ ! -f /usr/share/zoneinfo/$REGION/$CITY ]
do
    echo "/usr/share/zoneinfo/$REGION/$CITY does not exist"
    echo "Enter your city again:"
    read CITY
done
ln -sf /usr/share/zoneinfo/$REGION/$CITY /etc/localtime
echo "Running hwclock to generate /etc/adjtime..."
hwclock --systohc
echo "This command assumes the hardware clock is set to UTC."
## Localization
echo "Edit /etc/locale.gen and uncomment en_US.UTF-8 UTF-8 and other needed locales."
read -p "Please enter to continue.."
emacs /etc/locale.gen
echo "Continue to generate the locales? [y/N]"
read INPUT
while [ $INPUT != "y" ]
do
    emacs /etc/locale.gen
    echo "Continue to generate the locales? [y/N]"
    read INPUT
done
echo "Generating the locales..."
locale-gen
echo "Create the locale.conf file, and set the LANG variable accordingly."
echo "For example, `LANG=en_US.UTF-` if you choose en_US.UTF-8 in the previous step."
read -p "Please enter to continue.."
INPUT=""
while [ $INPUT != "y" ]
do
    emacs /etc/locale.conf
    echo "Ready to continue? [y/N]"
    read INPUT
done
echo "If you set the console keyboard layout, make the changes persistent in vconsole.conf."
echo "For example, `KEYMAP=de-latin1`."
echo "Do you want to make the changes? [y/N]"
read INPUT
if [ $INPUT = "y" ]
then
    read -p "Please enter to continue.."
    INPUT=""
    while [ $INPUT != "y" ]
    do
	emacs /etc/vconsole.conf
	echo "Ready to continue? [y/N]"
	read INPUT
    done
fi
## Network configuration
INPUT=""
while [ $INPUT != "y" ]
do
    echo "Enter your hostname:"
    read HOSTNAME
    echo "Is $HOSTNAME your hostname? [y/N]"
    read INPUT
done
echo "Creating the hostname file..."
touch /etc/hostname
echo $HOSTNAME > /etc/hostname
echo "Matching entries to hosts..."
echo "127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.0.1\t$HOSTNAME" > /etc/hosts
echo "Setting the root password..."
passwd
INPUT=""
while [ INPUT != "y" ]
do
    echo "Enter your CPU manufacturer (amd/intel):"
    read CPU_MANUFACTURER
    echo "Is $CPU_MANUFACTURER your CPU manufacturer? (y/N)"
    read INPUT
done
if [ $CPU_MANUFACTURER = "amd" ]
then
    pacman -S amd-ucode
fi
if [ $CPU_MANUFACTURER = "intel" ]
then
    pacman -S intel-ucode
fi
echo "Installing GRUB..."
pacman -S grub efibootmgr
if [ ! -d /efi ]
then
    mkdir /efi
fi
grub-install --target=x86_64-efi --efi-directory=efi --bootloader-id=GRUB
echo "Generating `/boot/grub/grub.cfg`..."
grub-mkconfig -o /boot/grub/grub.cfg
echo "Exiting the chroot environment..."
exit
echo "Rebooting..."
reboot
