#!/bin/bash

SCRIPT_DIR=$(dirname $(realpath "${BASH_SOURCE}"))

# Define the device
STORAGE_PATH=${1:-/dev/mmcblk0}
ARTQUITECTURE=${2:-armhf}

clear
set -e

# Download OS
if [ ! -f $SCRIPT_DIR/2021-05-07-2-ClusterCTRL-$ARTQUITECTURE-lite-CBRIDGE.zip ]; then
    echo "Downloading image:"
    wget -P $SCRIPT_DIR/ -T 60 https://dist1.8086.net/clusterctrl/testing/2021-05-07-2-ClusterCTRL-$ARTQUITECTURE-lite-CBRIDGE.zip
fi

# Download USBBoot
if [ ! -f $SCRIPT_DIR/2021-05-07-2-ClusterCTRL-$ARTQUITECTURE-lite-usbboot.tar.xz ]; then
    echo "Downloading USBBoot:"
    wget -P $SCRIPT_DIR/ -T 60 https://dist1.8086.net/clusterctrl/testing/2021-05-07-2-ClusterCTRL-$ARTQUITECTURE-lite-usbboot.tar.xz
fi

echo "Preparing device $STORAGE_PATH"
echo -n "I need sudo "

# Request sudo access for root actions
sudo echo ok

# Remove the partitions
set +e
sudo umount -l $STORAGE_PATH?*
set -e

# Coloca la imagen en la SD
unzip -p $SCRIPT_DIR/2021-05-07-2-ClusterCTRL-$ARTQUITECTURE-lite-CBRIDGE.zip | sudo dd of=$STORAGE_PATH bs=4M conv=fsync status=progress

# Resize partitions
sudo parted "$STORAGE_PATH" resizepart 2 100%
sudo e2fsck -f "${STORAGE_PATH}p2"
sudo resize2fs "${STORAGE_PATH}p2"

# Synchronize the drivers
sudo sync

# Mount the partitions generated with the image
for i in $(lsblk -lfe7 -p -o NAME,LABEL | awk -v OFS='-' '{ print $1, $2}' | grep '/dev/mmcblk0p');
do
    MOUNT_LABEL=$(echo $i | sed -e 's/.*\-//' )
    MOUNT_SRC=$(echo $i | sed -e 's/\-.*//' )
    MOUNT_POINT=/media/$USER/$MOUNT_LABEL
    echo $MOUNT_SRC 'in' $MOUNT_POINT
    if [ ! -d $MOUNT_POINT ]; then
        sudo mkdir -p $MOUNT_POINT;
    fi
    sudo mount $MOUNT_SRC $MOUNT_POINT
    if [ "boot" = $MOUNT_LABEL ]; then
        echo "Activating ssh"
        sudo touch $MOUNT_POINT/ssh
        echo "Activanting fan"
        sudo sed "$ a\dtoverlay=gpio-fan,gpiopin=18,temp=60000\n" -i $MOUNT_POINT/config.txt
        sudo sed -i "s/#hdmi_safe=1/hdmi_safe=1\n#/" -i $MOUNT_POINT/config.txt
    fi
done

echo "ClusterCTRL OS in $MOUNT_POINT"

# Add start Respberry Pi Zero's
sudo sed -i "s+^exit 0+# Start pis\nsleep 5\n/sbin/clusterhat init\n/sbin/clusterhat on\n\nexit 0\n+" $MOUNT_POINT/etc/rc.local.bak
# Add reboot Respberry Pi
sudo sed -i "s+; /etc/rc.local++" $MOUNT_POINT/etc/rc.local
sudo sed -i "s+^exit 0+reboot\n\nexit 0+g" $MOUNT_POINT/etc/rc.local

# Configure the OS to use the USBBOOT
for i in {1..4}
    do
        # Clean directories
        set +e
        sudo rm -rf $MOUNT_POINT/var/lib/clusterctrl/nfs/p$i/{*,.*}
        set -e
        # Puts the USBBOOT.
        sudo tar -axf $SCRIPT_DIR/2021-05-07-2-ClusterCTRL-$ARTQUITECTURE-lite-usbboot.tar.xz -C $MOUNT_POINT/var/lib/clusterctrl/nfs/p$i/
        # Set the host name
        sudo sed -i "s#cbridge#p${i}#g" $MOUNT_POINT/var/lib/clusterctrl/nfs/p$i/etc/hostname
        # Set the host IP
        sudo sed -i "s#^127.0.1.1.*#127.0.1.1\tp${i}#g" $MOUNT_POINT/var/lib/clusterctrl/nfs/p$i/etc/hosts
        # Set the start configuration
        sudo sed -i "s#nfsroot=.*:static#nfsroot=172.19.180.254:/var/lib/clusterctrl/nfs/p${i} rw ip=172.19.180.${i}:172.19.180.254::255.255.255.0:p${i}:usb0.10:static#" $MOUNT_POINT/var/lib/clusterctrl/nfs/p$i/boot/cmdline.txt
        # Set the link with the controller
        sudo sed -i "s+static ip_address=172.19.181.253/24 #ClusterCTRL+static ip_address=172.19.181.${i}/24 #ClusterCTRL+" $MOUNT_POINT/var/lib/clusterctrl/nfs/p$i/etc/dhcpcd.conf
        # Activate SSH access
        sudo touch $MOUNT_POINT/var/lib/clusterctrl/nfs/p$i/boot/ssh
    done

# Unmount the partitions
for i in $(lsblk -lfe7 -p -o NAME,LABEL | awk -v OFS='-' '{ print $1, $2}' | grep '/dev/mmcblk0p');
do
    MOUNT_LABEL=$(echo $i | sed -e 's/.*\-//' )
    MOUNT_SRC=$(echo $i | sed -e 's/\-.*//' )
    MOUNT_POINT=/media/$USER/$MOUNT_LABEL
    echo 'Unnount ' $MOUNT_LABEL
    sudo umount $MOUNT_POINT
done
