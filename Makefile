topdir=$(shell pwd)
boostdir=${topdir}/boost_1_64_0
NDK=${topdir}/android-ndk-r17c
NDK_INSTALLDIR=${topdir}/toolchains/aarch-android-r17c
export PATH := ${NDK_INSTALLDIR}/bin:$(PATH)

# DEPS: git wget curl gcc g++ autoconf libtool cmake scons
#
#----- NDK --------

${NDK}/.done:
	wget https://dl.google.com/android/repository/android-ndk-r17c-linux-x86_64.zip
	unzip android-ndk-r17c-linux-x86_64.zip
	touch $@

${NDK_INSTALLDIR}/.done: ${NDK}/.done
	${NDK}/build/tools/make_standalone_toolchain.py \
	    --arch arm64 \
	    --api 26 \
	    --stl=libc++ \
	    --install-dir=${NDK_INSTALLDIR}
	touch $@

#---- BOOST -------

boost_1_64_0/.done:
	wget https://dl.bintray.com/boostorg/release/1.64.0/source/boost_1_64_0.tar.bz2	
	tar xvjf boost_1_64_0.tar.bz2
	touch $@

${boostdir}/install/.done: ${NDK_INSTALLDIR}/.done boost_1_64_0/.done
	echo ${PATH}
	echo "using gcc : arm : aarch64-linux-android-clang++ ;" > ${boostdir}/user-config.jam
	(cd ${boostdir} && \
	./bootstrap.sh --prefix=${boostdir}/install && \
	./b2 install --user-config=${boostdir}/user-config.jam \
	  toolset=gcc-arm link=static cxxflags=-fPIC --with-filesystem \
	  --with-test --with-log --with-program_options -j8)
	touch $@

#------ ACL -------

ComputeLibrary/.done: ${NDK_INSTALLDIR}/.done ${boostdir}/install/.done
	git clone https://github.com/ARM-software/ComputeLibrary.git
	touch $@

ComputeLibrary/build/.done: ComputeLibrary/.done
	(cd ComputeLibrary && \
	CXX=clang++ CC=clang scons Werror=1 -j8 debug=0 asserts=1 neon=1 opencl=0 embed_kernels=1 os=android arch=arm64-v8a)
	touch $@

#---- PROTOBUF -----

protobuf/.done:
	git clone https://github.com/google/protobuf.git
	cd protobuf && git checkout -b v3.5.2 v3.5.2 && ./autogen.sh
	touch $@

x86_pb_install/.done: protobuf/.done
	mkdir -p x86_pb_build
	cd x86_pb_build && ../protobuf/configure --prefix=${topdir}/x86_pb_install && make install -j8
	touch $@

arm64_pb_install/.done: ${NDK_INSTALLDIR}/.done x86_pb_install/.done arm64_pb_build/.done
	mkdir -p arm64_pb_build
	cd arm64_pb_build && CC=aarch64-linux-android-clang \
	   CXX=aarch64-linux-android-clang++ \
	   CFLAGS="-fPIE -fPIC" LDFLAGS="-pie -llog" \
	    ../protobuf/configure --host=aarch64-linux-android \
	    --prefix=${topdir}/arm64_pb_install \
	    --with-protoc=${topdir}/x86_pb_install/bin/protoc
	cd arm64_pb_build && make -j8 install
	touch $@

#------ TF PB ------

tensorflow/.done:
	git clone https://github.com/tensorflow/tensorflow.git
	touch $@

armnn/.done:
	git clone https://github.com/ARM-software/armnn.git
	cd armnn/third-party && git clone https://github.com/nothings/stb.git
	touch $@

tf_pb/.done: x86_pb_install/.done tensorflow/.done armnn/.done
	cd tensorflow && ../armnn/scripts/generate_tensorflow_protobuf.sh ../tf_pb ../x86_pb_install
	touch $@

#---- ARMNN --------

armnn_build/.done: ${NDK_INSTALLDIR}/.done ComputeLibrary/build/.done tf_pb/.done arm64_pb_install/.done armnn/.done
	mkdir -p armnn_build
	cd armnn_build && CXX=aarch64-linux-android-clang++ \
	 CC=aarch64-linux-android-clang \
	 CXX_FLAGS="-fPIE -fPIC" \
	 cmake ../armnn \
	  -DCMAKE_SYSTEM_NAME=Android \
	  -DCMAKE_ANDROID_ARCH_ABI=arm64-v8a \
	  -DCMAKE_ANDROID_STANDALONE_TOOLCHAIN=${NDK_INSTALLDIR}/ \
	  -DCMAKE_EXE_LINKER_FLAGS="-pie -llog" \
	  -DARMCOMPUTE_ROOT=${topdir}/ComputeLibrary/ \
	  -DARMCOMPUTE_BUILD_DIR=${topdir}/ComputeLibrary/build \
	  -DBOOST_ROOT=${topdir}/boost/install/ \
	  -DARMCOMPUTENEON=1 -DARMCOMPUTECL=0 \
	  -DTF_GENERATED_SOURCES=${topdir}/tf_pb/ -DBUILD_TF_PARSER=1 \
	  -DBUILD_TF_LITE_PARSER=0 \
	  -DPROTOBUF_ROOT=${topdir}/arm64_pb_install/ \
	  -DBUILD_TESTS=1
	cd armnn_build && make -j8
	touch $@

armnn: armnn_build/.done

#-------------------

unittest_push: armnn_build/.done
	adb shell 'mkdir -p /data/local/tmp/armnn/unittest'
	adb push armnn_build/libarmnnTfParser.so /data/local/tmp/armnn/unittest/
	adb push armnn_build/libarmnn.so /data/local/tmp/armnn/unittest/
	adb push armnn_build/UnitTests /data/local/tmp/armnn/unittest/
	adb push ${NDK}/sources/cxx-stl/llvm-libc++/libs/arm64-v8a/libc++_shared.so /data/local/tmp/armnn/unittest/
	adb push ${topdir}/arm64_pb_install/lib/libprotobuf.so /data/local/tmp/armnn/unittest/libprotobuf.so.15.0.1
	adb shell 'rm -f /data/local/tmp/armnn/unittest/libprotobuf.so.15 /data/local/tmp/armnn/unittest/libprotobuf.so'
	adb shell 'ln -s libprotobuf.so.15.0.1 /data/local/tmp/armnn/unittest/libprotobuf.so.15'
	adb shell 'ln -s libprotobuf.so.15.0.1 /data/local/tmp/armnn/unittest/libprotobuf.so'

unittest_run:
	adb shell 'LD_LIBRARY_PATH=/data/local/tmp/armnn/unitest /data/local/tmp/armnn/unittest/UnitTests'

test_push: armnn_build/.done
	adb shell 'mkdir -p /data/local/tmp/armnn/tests'
	adb push armnn_build/libarmnnTfParser.so /data/local/tmp/armnn/tests/
	adb push armnn_build/libarmnn.so /data/local/tmp/armnn/tests/
	adb push armnn_build/tests/* /data/local/tmp/armnn/tests/
	adb push ${NDK}/sources/cxx-stl/llvm-libc++/libs/arm64-v8a/libc++_shared.so /data/local/tmp/armnn/tests/
	adb push ${topdir}/arm64_pb_install/lib/libprotobuf.so /data/local/tmp/armnn/tests/libprotobuf.so.15.0.1
	adb shell 'rm -f /data/local/tmp/armnn/tests/libprotobuf.so.15 /data/local/tmp/armnn/tests/libprotobuf.so'
	adb shell 'ln -s libprotobuf.so.15.0.1 /data/local/tmp/armnn/tests/libprotobuf.so.15'
	adb shell 'ln -s libprotobuf.so.15.0.1 /data/local/tmp/armnn/tests/libprotobuf.so'
	adb push models/inputs/Dog_224x224.snpy /data/local/tmp/armnn/tests/ 
	adb push models/tflite/mobilenet_v1_0.25_224_quant.tflite /data/local/tmp/armnn/tests/ 
	adb push models/tf/mobilenet_v2_1.4_224_frozen.pb /data/local/tmp/armnn/tests/ 

test_run:
	adb shell 'LD_LIBRARY_PATH=/data/local/tmp/armnn/tests /data/local/tmp/armnn/tests/ExecuteNetwork --compute Hexagon --compute CpuAcc --model-format tensorflow-binary --model-path /data/local/tmp/armnn/tests/mobilenet_v2_1.4_224_frozen.pb --input-tensor-shape 1,224,224,3 --input-type float --input-name input --output-name MobilenetV2/Predictions/Reshape_1 --input-tensor-data /data/local/tmp/armnn/tests/Dog_224x224.snpy --event-based-profiling' > result

models/.done:
	mkdir -p models/tflite
	cd models/tflite && wget http://download.tensorflow.org/models/mobilenet_v1_2018_08_02/mobilenet_v1_0.25_224_quant.tgz && tar xf mobilenet_v1_0.25_224_quant.tgz
	mkdir -p models/tf
	cd models/tf && wget https://storage.googleapis.com/mobilenet_v2/checkpoints/mobilenet_v2_1.4_224.tgz && tar xf mobilenet_v2_1.4_224.tgz
	touch $@

	


