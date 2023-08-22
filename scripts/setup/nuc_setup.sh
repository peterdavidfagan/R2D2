#!/bin/bash

# install docker
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
systemctl enable docker

# Read the parameter values from the Python script using awk and convert to env variables
PARAMETERS_FILE="$(git rev-parse --show-toplevel)/r2d2/misc/parameters.py"
awk -F'[[:space:]]*=[[:space:]]*' '/^[[:space:]]*([[:alnum:]_]+)[[:space:]]*=/ && $1 != "ARUCO_DICT" { gsub("\"", "", $2); print "export " $1 "=" $2 }' "$PARAMETERS_FILE" > temp_env_vars.sh
source temp_env_vars.sh
export NUC_IP=$nuc_ip
export ROBOT_IP=$robot_ip
export LAPTOP_IP=$laptop_ip
export GATEWAY_IP=$gateway_ip
export SUDO_PASSWORD=$sudo_password
export ROBOT_TYPE=$robot_type
export ROBOT_SERIAL_NUMBER=$robot_serial_number
export LIBFRANKA_VERSION=$libfranka_version
export HAND_CAMERA_ID=$hand_camera_id
export VARIED_CAMERA_1_ID=$varied_camera_1_id
export VARIED_CAMERA_2_ID=$varied_camera_2_id
export UBUNTU_PRO_TOKEN=$ubuntu_pro_token
rm temp_env_vars.sh

# build control server container
ROOT_DIR="$(git rev-parse --show-toplevel)"
DOCKER_COMPOSE_DIR="$ROOT_DIR/.docker/nuc"
DOCKER_COMPOSE_FILE="$DOCKER_COMPOSE_DIR/docker-compose-nuc.yaml"
cd $DOCKER_COMPOSE_DIR && docker-compose -f $DOCKER_COMPOSE_FILE build

# perform rt-patch
apt update && apt install ubuntu-advantage-tools
pro attach $UBUNTU_PRO_TOKEN
pro enable realtime-kernel

# cpu frequency scaling
apt install cpufrequtils -y
systemctl disable ondemand
systemctl enable cpufrequtils
sh -c 'echo "GOVERNOR=performance" > /etc/default/cpufrequtils'
systemctl daemon-reload && sudo systemctl restart cpufrequtils

# find ethernet interface on device
interface_name=$(ip -o link show | grep -Eo '^[0-9]+: (en|eth|ens|eno|enp)[a-z0-9]*' | awk -F' ' '{print $2}')

# Check if an interface name was found
if [ -z "$interface_name" ]; then
    echo "No Ethernet interface found."
    exit 1
fi

echo "Ethernet interface found: $interface_name"

# set and activate static ip address
nmcli connection add con-name "nuc_static" ifname "$interface_name" type ethernet
nmcli connection modify "nuc_static" ipv4.method manual ipv4.address $NUC_IP/24 ipv4.gateway $GATEWAY_IP
nmcli connection up "nuc_static"

# start control server service and ensure runs on restart
DOCKER_COMPOSE_FILE="$(git rev-parse --show-toplevel)/.docker/nuc/docker-compose-nuc.yaml"
docker compose -f $DOCKER_COMPOSE_FILE up -d

# Display a message and wait for user confirmation
echo "Docker container started with restart always policy. Press Enter to reboot your machine..."
read _

reboot
