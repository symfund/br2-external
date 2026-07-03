################################################################################
# PROTOBUF
################################################################################
ifeq ($(BR2_PACKAGE_PROTOBUF),y)
PROTOBUF_OVERRIDE_SRCDIR = $(BR2_EXTERNAL_EXTPACK_PATH)/src/protobuf
HOST_PROTOBUF_OVERRIDE_SRCDIR = $(BR2_EXTERNAL_EXTPACK_PATH)/src/protobuf
PROTOBUF_AUTORECONF = YES
HOST_PROTOBUF_AUTORECONF = YES
endif

################################################################################
# FLATBUFFERS
################################################################################
ifeq ($(BR2_PACKAGE_FLATBUFFERS),y)
FLATBUFFERS_OVERRIDE_SRCDIR = $(BR2_EXTERNAL_EXTPACK_PATH)/src/flatbuffers
HOST_FLATBUFFERS_OVERRIDE_SRCDIR = $(BR2_EXTERNAL_EXTPACK_PATH)/src/flatbuffers
endif
