export REPO_NAME="mofarch"

# The default console keymap is US. Available layouts can be listed with:
# `ls /usr/share/kbd/keymaps/**/*.map.gz`
# Leave KEYMAP empty if you are using US keyboard layout.
export KEYMAP=

# The following partitions are required for a chosen device:
# * One partition for the root directory /.
# * For booting in UEFI mode: an EFI system partition.
# Layout:
# |      Mount point      |         Partition         |    Partition type     |      Suggested size     |
# | /mnt/boot or /mnt/efi | /dev/efi_system_partition | EFI system partition  |     At least 260 MiB    |
# |        [SWAP]         |    /dev/swap_partition    |      Linux swap       |    More than 512 MiB    |
# |         /mnt          |    /dev/root_partition    | Linux x86-64 root (/) | Remainder of the device |
# Note: /mnt/efi should only be considered if the used boot loader is capable of loading the kernel and initramfs images from the root volume.
export EFI_SYSTEM_PARTITION=
export SWAP_PARTITION=
export ROOT_PARTITION=

export REGION=
export CITY=

export HOSTNAME=

# Use lower cases. For example, "amd", "intel", and "nvidia".
export CPU_MANUFACTURER=
export GPU_MANUFACTURER=

export HOME_USERNAME=

export NETWORK_MANAGER="networkmanager"
export NETWORK_MANAGER_SERVICE=${NETWORK_MANAGER}.service
export TEXT_EDITOR="emacs"
export DOCUMENTATION_TOOLS="man-db man-pages texinfo"
export EXTRA_FONTS="wqy-microhei wqy-microhei-lite wqy-bitmapfont wqy-zenhei ttf-arphic-ukai ttf-arphic-uming adobe-source-han-sans-cn-fonts adobe-source-han-serif-cn-fonts noto-fonts-cjk"
export BROWSER="firefox"
export EMAIL_CLIENT="thunderbird"
