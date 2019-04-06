#!/bin/bash

cd tf
if [ ! -f mobilenet_v2_1.4_224.tgz ]; then
  wget https://storage.googleapis.com/mobilenet_v2/checkpoints/mobilenet_v2_1.4_224.tgz
  tar xf mobilenet_v2_1.4_224.tgz
fi

if [ ! -f mobilenet_v1_1.0_224_quant.tgz ]; then
  wget http://download.tensorflow.org/models/mobilenet_v1_2018_08_02/mobilenet_v1_1.0_224_quant.tgz
  tar xf mobilenet_v1_1.0_224_quant.tgz
fi
