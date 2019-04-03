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
	  -DPROTOBUF_ROOT=${topdir}/arm64_pb_install/
	cd armnn_build && make -j8
	touch $@

armnn: armnn_build/.done
