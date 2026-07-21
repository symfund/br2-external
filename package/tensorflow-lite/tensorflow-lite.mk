################################################################################
#
# tensorflow-lite
#
################################################################################

TENSORFLOW_LITE_VERSION = 2.21.0
TENSORFLOW_LITE_SITE = $(call github,tensorflow,tensorflow,v$(TENSORFLOW_LITE_VERSION))
TENSORFLOW_LITE_LICENSE = Apache-2.0
TENSORFLOW_LITE_LICENSE_FILES = LICENSE
TENSORFLOW_LITE_INSTALL_STAGING = YES

# Point CMake directly to the Lite subdirectory inside the main repository
TENSORFLOW_LITE_SUBDIR = tensorflow/lite

# Force the execution environment to look at the host bin folder layout first
# This ensures any relative call to 'protoc' uses the compiled host tools automatically.
TENSORFLOW_LITE_CONF_ENV = PATH="$(HOST_DIR)/bin:$(BR2_PATH)"

TENSORFLOW_LITE_DEPENDENCIES = host-flatbuffers flatbuffers eigen libabseil-cpp farmhash \
	host-protobuf protobuf fxdiv

# Configuration flags for TFLite compilation
# NOTE: We keep TENSORFLOW_SOURCE_DIR=$(@D) so CMake uses your extracted source 
# archive and doesn't re-download the entire 1GB+ main Git repository history.
TENSORFLOW_LITE_CONF_OPTS = \
	-DTENSORFLOW_SOURCE_DIR=$(@D) \
	-DTFLITE_ENABLE_XNNPACK=ON \
	-DTFLITE_ENABLE_RUY=ON \
	-DTFLITE_ENABLE_MMAP=ON \
	-DTFLITE_ENABLE_GPU=OFF \
	-DBUILD_SHARED_LIBS=ON \
	-DFETCHCONTENT_QUIET=OFF \
	-DCMAKE_FIND_PACKAGE_PREFER_CONFIG=ON \
	-Dabsl_DIR=$(STAGING_DIR)/usr/lib/cmake/absl \
	-Dflatbuffers_DIR=$(STAGING_DIR)/usr/lib/cmake/flatbuffers \
	-DSYSTEM_FARMHASH=ON \
	-DFARMHASH_ROOT_DIR=$(STAGING_DIR)/usr \
	-DSYSTEM_PROTOBUF=ON \
	-DTFLITE_HOST_TOOLS_DIR=$(HOST_DIR)/bin \
	-DFETCHCONTENT_SOURCE_DIR_PROTOBUF=$(BR2_EXTERNAL_EXTPACK_PATH)/src/protobuf \
	-DFETCHCONTENT_SOURCE_DIR_FFT2D=$(BR2_EXTERNAL_EXTPACK_PATH)/src/OouraFFT \
	-DFETCHCONTENT_SOURCE_DIR_GEMMLOWP=$(BR2_EXTERNAL_EXTPACK_PATH)/src/gemmlowp \
	-DFETCHCONTENT_SOURCE_DIR_CPUINFO=$(BR2_EXTERNAL_EXTPACK_PATH)/src/cpuinfo \
	-DFETCHCONTENT_SOURCE_DIR_ML_DTYPES=$(BR2_EXTERNAL_EXTPACK_PATH)/src/ml_dtypes \
	-DFETCHCONTENT_SOURCE_DIR_RUY=$(BR2_EXTERNAL_EXTPACK_PATH)/src/ruy \
	-DPTHREADPOOL_SOURCE_DIR=$(BR2_EXTERNAL_EXTPACK_PATH)/src/pthreadpool \
	-DFXDIV_SOURCE_DIR=$(FXDIV_DIR) \
	-DFP16_SOURCE_DIR=$(BR2_EXTERNAL_EXTPACK_PATH)/src/FP16 \
	-DXNNPACK_SOURCE_DIR=$(BR2_EXTERNAL_EXTPACK_PATH)/src/XNNPACK \
	-DFETCHCONTENT_SOURCE_DIR_XNNPACK=$(BR2_EXTERNAL_EXTPACK_PATH)/src/XNNPACK \
	-DKLEIDIAI_SOURCE_DIR=$(BR2_EXTERNAL_EXTPACK_PATH)/src/kleidiai \
	-DFETCHCONTENT_SOURCE_DIR_KLEIDIAI=$(BR2_EXTERNAL_EXTPACK_PATH)/src/kleidiai \
	-Dprotobuf_BUILD_TESTS=OFF \
	-Dprotobuf_BUILD_EXAMPLES=OFF \
	-Dprotobuf_BUILD_PROTOC_BINARIES=OFF \
	-DProtobuf_PROTOC_EXECUTABLE=$(HOST_DIR)/bin/protoc \
	-D_protobuf_PROTOC_EXECUTABLE_EXECUTABLE_PATH=$(HOST_DIR)/bin/protoc \
	-DProtobuf_INCLUDE_DIR=$(STAGING_DIR)/usr/include \
	-DProtobuf_LIBRARY=$(STAGING_DIR)/usr/lib/libprotobuf.so \
	-DProtobuf_LIBRARIES=$(STAGING_DIR)/usr/lib/libprotobuf.so

# Phase 1: Pre-Configure Hooks (Inject custom system library definitions)
# Bypass internal protobuf compilation subdirectory mapping.
define TENSORFLOW_LITE_FIX_DEPENDENCIES
	sed -i '1i add_library(protobuf::libprotobuf UNKNOWN IMPORTED GLOBAL)\nset_target_properties(protobuf::libprotobuf PROPERTIES IMPORTED_LOCATION "$(STAGING_DIR)/usr/lib/libprotobuf.so" INTERFACE_INCLUDE_DIRECTORIES "$(STAGING_DIR)/usr/include")\nset(protobuf_POPULATED TRUE)' $(@D)/tensorflow/lite/CMakeLists.txt
endef
TENSORFLOW_LITE_PRE_CONFIGURE_HOOKS += TENSORFLOW_LITE_FIX_DEPENDENCIES

# Phase 2: Pre-Build Hooks (Executes AFTER Makefile generation is completed)
# This substitutes any text string matching "[something]/protoc" with the true host protoc location.
# It satisfies Makefile file targets while keeping the compiler instruction line completely valid.
define TENSORFLOW_LITE_PATCH_PROTO_RULES
	find $(@D)/tensorflow/lite/ \( -name "build.make" -o -name "Makefile" \) -type f -exec sed -i -E 's|[^[:space:]]*/protoc|$(HOST_DIR)/bin/protoc|g' {} \;
endef
TENSORFLOW_LITE_PRE_BUILD_HOOKS += TENSORFLOW_LITE_PATCH_PROTO_RULES

define TENSORFLOW_LITE_INSTALL_STAGING_CMDS
	$(INSTALL) -D -m 0755 $(@D)/tensorflow/lite/libtensorflow-lite.so $(STAGING_DIR)/usr/lib/libtensorflow-lite.so
	mkdir -p $(STAGING_DIR)/usr/include/tensorflow/lite
	cp -r $(@D)/tensorflow/lite/*.h $(STAGING_DIR)/usr/include/tensorflow/lite/
endef

define TENSORFLOW_LITE_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/tensorflow/lite/libtensorflow-lite.so $(TARGET_DIR)/usr/lib/libtensorflow-lite.so
endef

define TENSORFLOW_LITE_POST_INSTALL_TARGET_RM_FILES
	rm -rf $(TARGET_DIR)/usr/include
endef

TENSORFLOW_LITE_POST_INSTALL_TARGET_HOOKS += TENSORFLOW_LITE_POST_INSTALL_TARGET_RM_FILES

$(eval $(cmake-package))
