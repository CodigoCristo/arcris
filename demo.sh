
STORAGE_DEVICE="/dev/vda"

dd if=/dev/zero of="$STORAGE_DEVICE" bs=100M count=10 status=progress

printf "Clave de cifrado: "
read PASSPHRASE
echo "$PASSPHRASE"
sleep 5


parted "$STORAGE_DEVICE" --script mklabel gpt
parted "$STORAGE_DEVICE" --script mkpart ESP fat32 1MiB 200MiB
parted "$STORAGE_DEVICE" --script set 1 boot on
parted "$STORAGE_DEVICE" --script name 1 efi
parted "$STORAGE_DEVICE" --script mkpart primary 800MiB 100%
parted "$STORAGE_DEVICE" --script set 2 lvm on
parted "$STORAGE_DEVICE" --script name 2 lvm
parted "$STORAGE_DEVICE" --script print


modprobe dm-crypt
modprobe dm-mod



# shellcheck disable=SC2154
echo -n "$PASSPHRASE" | cryptsetup --verbose -c aes-xts-plain64 --pbkdf argon2id --type luks2 -y luksFormat "${STORAGE_DEVICE}${PARTITION_SUFFIX}2"
echo -n "$PASSPHRASE" | cryptsetup luksOpen "${STORAGE_DEVICE}${PARTITION_SUFFIX}2" lvm

pvcreate /dev/mapper/lvm
vgcreate vg /dev/mapper/lvm


lvcreate --size 4G vg --name swap
lvcreate --size 20G vg --name root
lvcreate -l +100%FREE vg --name home

#lvcreate -L 512M vg -n efi
#lvcreate -L 30G vg -n root
#lvcreate -l +100%FREE vg -n home



#mkfs.ext4 /dev/mapper/vg-efi

mkfs.ext4 /dev/mapper/vg-root
mkfs.ext4 /dev/mapper/vg-home
mkswap /dev/mapper/vg-swap
mkfs.fat -F32 "${STORAGE_DEVICE}${PARTITION_SUFFIX}1"



mount /dev/mapper/vg-root /mnt
mkdir /mnt/home
mount /dev/mapper/vg-home /mnt/home
swapon /dev/mapper/vg-swap
mkdir /mnt/efi
mount "${STORAGE_DEVICE}${PARTITION_SUFFIX}1" /mnt/efi

lsblk

echo "Presiona ENTER para continuar..."
sleep 5

pacman -Sy reflector python --noconfirm

reflector --verbose --latest 5 --protocol http --protocol https --sort rate --save /etc/pacman.d/mirrorlist

pacstrap /mnt base base-devel lvm2 linux wget efibootmgr grub nano reflector python neofetch networkmanager dhcpcd

genfstab -U /mnt > /mnt/etc/fstab


arch-chroot /mnt /bin/bash -c "pacman -S dhcpcd networkmanager iwd net-tools ifplugd --noconfirm"
#ACTIVAR SERVICIOS
arch-chroot /mnt /bin/bash -c "systemctl enable dhcpcd NetworkManager"

echo "noipv6rs" >> /mnt/etc/dhcpcd.conf
echo "noipv6" >> /mnt/etc/dhcpcd.conf


sed -i 's#^HOOKS=(\(.*\))#HOOKS=(\1 encrypt lvm2)#' /mnt/etc/mkinitcpio.conf
arch-chroot /mnt /bin/bash -c 'mkinitcpio -P'


sed -i "s#GRUB_CMDLINE_LINUX=\"\\(.*\\)\"#GRUB_CMDLINE_LINUX=\"cryptdevice=${STORAGE_DEVICE}${PARTITION_SUFFIX}2:lvm\"#" /mnt/etc/default/grub
echo "GRUB_ENABLE_CRYPTODISK=y" >> /mnt/etc/default/grub


echo '' 
echo 'Instalando EFI System >> bootx64.efi' 
arch-chroot /mnt /bin/bash -c 'grub-install --target=x86_64-efi --efi-directory=/efi --removable' 
echo '' 
echo 'Instalando UEFI System >> grubx64.efi' 
arch-chroot /mnt /bin/bash -c 'grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=Arch'

arch-chroot /mnt /bin/bash -c "grub-mkconfig -o /boot/grub/grub.cfg"


#CONFIGURANDO PACMAN
sed -i 's/#Color/Color/g' /mnt/etc/pacman.conf
sed -i 's/#TotalDownload/TotalDownload/g' /mnt/etc/pacman.conf
sed -i 's/#VerbosePkgLists/VerbosePkgLists/g' /mnt/etc/pacman.conf

sed -i "37i ILoveCandy" /mnt/etc/pacman.conf

sed -i '93d' /mnt/etc/pacman.conf
sed -i '94d' /mnt/etc/pacman.conf
sed -i "93i [multilib]" /mnt/etc/pacman.conf
sed -i "94i Include = /etc/pacman.d/mirrorlist" /mnt/etc/pacman.conf
clear

#hosts
clear
#NOmbre de computador
hostname=ArcriS
echo "$hostname" > /mnt/etc/hostname
echo "127.0.1.1 $hostname.localdomain $hostname" > /mnt/etc/hosts
clear
echo "Hostname: $(cat /mnt/etc/hostname)"
echo ""
echo "Hosts: $(cat /mnt/etc/hosts)"
echo ""
clear

arch-chroot /mnt /bin/bash -c "(echo 123 ; echo 123) | passwd root"



arch-chroot /mnt /bin/bash -c "mkinitcpio -p linux"

arch-chroot /mnt /bin/bash -c "git clone https://aur.archlinux.org/yay.git"
arch-chroot /mnt /bin/bash -c "cd yay"
arch-chroot /mnt /bin/bash -c "makepkg -sc --install --needed --noconfirm"
