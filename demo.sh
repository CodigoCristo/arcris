
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
    lvcreate -L 1G vg -C y -n swap
    lvcreate -L 512M vg -n boot
    lvcreate -L 40G vg -n root
    lvcreate -l +100%FREE vg -n home


    mkswap -L swap /dev/mapper/vg-swap
    mkfs.ext4 /dev/mapper/vg-boot
    mkfs.ext4 /dev/mapper/vg-root
    mkfs.ext4 /dev/mapper/vg-home
    mkfs.fat -F32 "${STORAGE_DEVICE}${PARTITION_SUFFIX}1"


  	swapon /dev/mapper/vg-swap
    mount /dev/mapper/vg-root /mnt
    mkdir /mnt/home
    mount /dev/mapper/vg-home /mnt/home
    mkdir /mnt/boot
    mount /dev/mapper/vg-boot /mnt/boot
    mkdir /mnt/boot/efi
    mount "${STORAGE_DEVICE}${PARTITION_SUFFIX}1" /mnt/boot/efi

    lsblk

echo "Presiona ENTER para continuar..."
read line