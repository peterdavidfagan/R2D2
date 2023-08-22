import os
from cv2 import aruco

# Robot Params #
nuc_ip = "192.168.106.10"
robot_ip = "192.168.106.99"
laptop_ip = "192.168.106.20"
gateway_ip = "129.215.91.247" # only needed if connecting to internet via ethernet
sudo_password = "robot"
robot_type = "panda"  # 'panda' or 'fr3'
robot_serial_number = "295341-1325422"
# set libfranka version according to robot type
if robot_type=='panda':
    libfranka_version = "0.9.0"
else:
    libfranka_version = "0.10.0"

# Camera ID's #
hand_camera_id = "head"
varied_camera_1_id = "left"
varied_camera_2_id = "right"

# Charuco Board Params #
CHARUCOBOARD_ROWCOUNT = 9
CHARUCOBOARD_COLCOUNT = 14
CHARUCOBOARD_CHECKER_SIZE = 0.020
CHARUCOBOARD_MARKER_SIZE = 0.015
ARUCO_DICT = aruco.Dictionary_get(aruco.DICT_5X5_100)

# Ubuntu Pro Token (RT PATCH) #
ubuntu_pro_token = "C17CujhTteHnrdQW5wVEudVKA5cye"

# Code Version [DONT CHANGE] #
r2d2_version = "1.3"
