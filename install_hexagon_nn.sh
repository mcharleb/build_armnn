#!/bin/bash

# Install Hexagon NN
# Assumes default install to ${HOME}/Qualcomm/Hexagon_SDK/3.4.3
# unzip qualcomm_hexagon_sdk_3_4_3_linux.zip
# sh qualcomm_hexagon_sdk_3_4_3_linux/qualcomm_hexagon_sdk_3_4_3_eval.bin
# sudo apt-get install lib32z1 lib32ncurses5

export HEXAGON_SDK_ROOT=${HOME}/Qualcomm/Hexagon_SDK/3.4.3
export ANDROID_ROOT_DIR=`pwd`/android-ndk-r17c
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$HEXAGON_SDK_ROOT/tools/libusb/
export HEXAGON_TOOLS_ROOT=${HEXAGON_SDK_ROOT}/tools/HEXAGON_Tools/8.3.02
export HEXAGON_NN=${HEXAGON_SDK_ROOT}/libs/hexagon_nn/2.6
if [ -f /lib32/ld-linux.so.* ];
then
   echo ""
else
   echo "32 bit compatibility libs are not installed.Please install them using \"sudo apt-get install lib32z1 lib32ncurses5\""
fi
export SDK_SETUP_ENV=Done

# Build Hexagon NN
cd ${HEXAGON_NN}

# For 845
make tree VERBOSE=1 V=hexagon_Release_dynamic_toolv82_v65 V65=1
