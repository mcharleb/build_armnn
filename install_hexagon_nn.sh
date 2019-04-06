#!/bin/bash

# Install Hexagon NN
# Assumes default install to ${HOME}/Qualcomm/Hexagon_SDK/3.4.3
# sudo apt-get install lib32z1 lib32ncurses5

if [ ! ~/Qualcomm/Hexagon_SDK/3.4.3 ]; then

  if [ ! -f qualcomm_hexagon_sdk_3_4_3_linux.zip ]; then
    echo "You must download qualcomm_hexagon_sdk_3_4_3_linux.zip from Qualcomm Developer Network"
    exit 1
  fi

  if [ !  qualcomm_hexagon_sdk_3_4_3_linux/qualcomm_hexagon_sdk_3_4_3_eval.bin ]; then
    unzip qualcomm_hexagon_sdk_3_4_3_linux.zip
    chmod +x qualcomm_hexagon_sdk_3_4_3_linux/qualcomm_hexagon_sdk_3_4_3_eval.bin
  fi

  qualcomm_hexagon_sdk_3_4_3_linux/qualcomm_hexagon_sdk_3_4_3_eval.bin -i silent
fi

cd ~/Qualcomm/Hexagon_SDK/3.4.3
source setup_sdk_env.source
cd examples/hexagon_nn/
source setup_hexagon_nn.source
cd tutorials/

# For 8150
#make tree VERBOSE=1 V=hexagon_Release_dynamic_toolv83_v66 V66=1

# For 845
make tree VERBOSE=1 V=hexagon_Release_dynamic_toolv83_v65 V65=1
