#!/bin/bash

# print out nice ascii art
ascii=$(cat ./intro.txt)
echo "$ascii"

# path variables
ROOT_DIR="$(git rev-parse --show-toplevel)"
DOCKER_COMPOSE_DIR="$ROOT_DIR/.docker/laptop"
DOCKER_COMPOSE_FILE="$DOCKER_COMPOSE_DIR/docker-compose-laptop.yaml"

# ensure local files are up to date and git lfs is configured
echo -e "0. Ensure all submodules are cloned and oculus_reader APK file pulled locally \n"

eval "$(ssh-agent -s)"
ssh-add /home/robot/.ssh/id_ed25519
curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash
apt update && apt install -y git-lfs
git lfs install # has to be run only once on a single user account
cd $ROOT_DIR && git submodule update --recursive --remote --init

# install APK on Oculus device
echo -e "1. Install APK on oculus device \n"

usermod -aG plugdev $LOGNAME
newgrp plugdev
apt install -y android-tools-adb android-sdk-platform-tools-common
adb start-server

read -p "Connect your Oculus Quest 2 via USB-C, and approve USB debugging within device. Confirm with y when complete? (y/n): " confirmation
    
if [ "$confirmation" != "y" ] && [ "$confirmation" != "Y" ]; then
	return 1
else
	return exit 1
fi

# Function to display devices and ask for confirmation
function confirm_devices {
    devices=$(adb devices)
    
    echo "List of devices:"
    echo "$devices"
    
    read -p "Is your oculus device connected? (y/n): " confirmation
    
    if [ "$confirmation" != "y" ] && [ "$confirmation" != "Y" ]; then
        return 1
    fi
}

# Retry loop
max_retries=3
retry_count=0

while ! confirm_devices; do
    ((retry_count++))
    if [ "$retry_count" -ge "$max_retries" ]; then
        echo "Max retry attempts reached. Aborting installation."
        exit 1
    fi
    echo "Retrying..."
done

pip3 install -e $ROOT_DIR/r2d2/oculus_reader
python3 $ROOT_DIR/r2d2/oculus_reader/oculus_reader/reader.py
echo cleaning up threads ...
sleep 5
adb kill-server

# install docker
echo -e "2. Install docker \n"

apt-get update
apt-get install ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# install and configure nvidia container toolkit
echo -e "3. Install Nvidia container toolkit \n"

distribution=$(. /etc/os-release;echo $ID$VERSION_ID) \
      && curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
      && curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
            sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
            sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
apt-get update
apt-get install -y nvidia-container-toolkit
nvidia-ctk runtime configure --runtime=docker
systemctl restart docker


# expose parameters as environment variables
echo -e "4. Set environment variables from parameters file \n"

PARAMETERS_FILE="$(git rev-parse --show-toplevel)/r2d2/misc/parameters.py"
awk -F'[[:space:]]*=[[:space:]]*' '/^[[:space:]]*([[:alnum:]_]+)[[:space:]]*=/ && $1 != "ARUCO_DICT" { gsub("\"", "", $2); print "export " $1 "=" $2 }' "$PARAMETERS_FILE" > temp_env_vars.sh
source temp_env_vars.sh
export NUC_IP=$nuc_ip
export LAPTOP_IP=$laptop_ip
export ROBOT_IP=$robot_ip
export GATEWAY_IP=$gateway_ip
export SUDO_PASSWORD=$sudo_password
export ROBOT_TYPE=$robot_type
export ROBOT_SERIAL_NUMBER=$robot_serial_number
export HAND_CAMERA_ID=$hand_camera_id
export VARIED_CAMERA_1_ID=$varied_camera_1_id
export VARIED_CAMERA_2_ID=$varied_camera_2_id
export LIBFRANKA_VERSION=$libfranka_version
rm temp_env_vars.sh

if [ "$ROBOT_TYPE" == "panda" ]; then
        export LIBFRANKA_VERSION=0.9.0
else
        export LIBFRANKA_VERSION=0.10.0
fi


# ensure GUI window is accessible from container
echo -e "5. set Docker Xauth for x11 forwarding \n"

export DOCKER_XAUTH=/tmp/.docker.xauth
touch $DOCKER_XAUTH
xauth nlist $DISPLAY | sed -e 's/^..../ffff/' | xauth -f $DOCKER_XAUTH nmerge -

# build client server container
echo -e "6. build control server container \n"

cd $DOCKER_COMPOSE_DIR && docker compose -f $DOCKER_COMPOSE_FILE build

# find ethernet interface on device
echo -e "7. set static ip \n"

interface_name=$(ip -o link show | grep -Eo '^[0-9]+: (en|eth|ens|eno|enp)[a-z0-9]*' | awk -F' ' '{print $2}')
if [ -z "$interface_name" ]; then
    echo "No Ethernet interface found."
    exit 1
fi

echo "Ethernet interface found: $interface_name"

nmcli connection delete "laptop_static"
nmcli connection add con-name "laptop_static" ifname "$interface_name" type ethernet
nmcli connection modify "laptop_static" ipv4.method manual ipv4.address $LAPTOP_IP/24 ipv4.gateway $GATEWAY_IP
nmcli connection up "laptop_static"

# run docker container
echo -e "8. run client application \n"
docker compose -f $DOCKER_COMPOSE_FILE up
