#!/bin/sh

source ./.resource

# Post-installation

## Network manager
echo "Installing network manager '$NETWORK_MANAGER'..."
sudo pacman -S $NETWORK_MANAGER
echo "Enabling '$NETWORK_MANAGER'..."
systemctl enable $NETWORK_MANAGER_SERVICE

## Text editor
echo "Installing text editor '$TEXT_EDITOR'..."
sudo pacman -S $TEXT_EDITOR

## Documentation tools
echo "Installing packages for accessing documentation in `man` and `info` pages: `$DOCUMENTATION_TOOLS`..."
sudo pacman -S $DOCUMENTATION_TOOLS

## Git
echo "Installing Git..."
sudo pacman -S git

## Paru
echo "Installing Paru..."
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si

## Zsh
echo "Installing Zsh..."
sudo pacman -S zsh zsh-completions
echo "Changing default shell to zsh..."
chsh -s /usr/bin/zsh
echo "Installing Oh My Zsh..."
paru -S oh-my-zsh-git

## Reflector
echo "Installing Reflector..."
sudo pacman -S reflector
echo "Enabling Reflector..."
systemctl enable reflector.service

## Xorg
echo "Installing Xorg..."
sudo pacman -S xorg

## Drivers
echo "Installing Drivers..."
if [ $GPU_MANUFACTURER = "amd" ]
then
    sudo pacman -S xf86-video-amdgpu
fi
if [ $GPU_MANUFACTURER = "intel" ]
then
    sudo pacman -S xf86-video-intel
fi
if [ $GPU_MANUFACTURER = "nvidia" ]
then
    sudo pacman -S nvidia
fi

## KDE
echo "Installing Plasma and KDE applications..."
sudo pacman -S plasma-meta kde-applications-meta

## SDDM
echo "Enabling SDDM..."
systemctl enable sddm.service

## Fonts
echo "Installing Microsoft fonts..."
sudo pacman -S ttf-ms-fonts

## Browser
echo "Installing '$BROWSER'..."
sudo pacman -S $BROWSER

## Email client
echo "Installing '$EMAIL_CLIENT'..."
sudo pacman -S $EMAIL_CLIENT

## Fcitx5
echo "Installing Fcitx5..."
sudo pacman -S fcitx5
echo "GTK_IM_MODULE=fcitx" >> /etc/environment
echo "QT_IM_MODULE=fcitx" >> /etc/environment
echo "XMODIFIERS=@im=fcitx" >> /etc/environment
echo "SDL_IM_MODULE=fcitx" >> /etc/environment

## Extra packages
echo "Installing extra packages..."
sudo pacman -S $EXTRA_PACKAGES

# Reboot
## Optionally manually unmount all the partitions with umount -R /mnt: this allows noticing any "busy" partitions, and finding the cause with fuser.
echo "Installation is complete."
echo "Please remove the installation media and reboot."
