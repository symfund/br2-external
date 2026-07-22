ifneq ($(qstrip $(USR_ARM_TRUSTED_FIRMWARE_SRCDIR)),)
ARM_TRUSTED_FIRMWARE_OVERRIDE_SRCDIR=$(qstrip $(USR_ARM_TRUSTED_FIRMWARE_SRCDIR))
endif

ifneq ($(qstrip $(USR_UBOOT_SRCDIR)),)
UBOOT_OVERRIDE_SRCDIR=$(qstrip $(USR_UBOOT_SRCDIR))
endif

ifneq ($(qstrip $(USR_OPTEE_OS_SRCDIR)),)
OPTEE_OS_OVERRIDE_SRCDIR=$(qstrip $(USR_OPTEE_OS_SRCDIR))
endif

ifneq ($(qstrip $(USR_LINUX_SRCDIR)),)
LINUX_OVERRIDE_SRCDIR=$(qstrip $(USR_LINUX_SRCDIR))
endif

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

define MONIT_INSTALL_INIT_SYSV
	$(INSTALL) -d -m 0700 $(TARGET_DIR)/etc/monit.d

	$(INSTALL) -D -m 0600 $(BR2_EXTERNAL_EXTPACK_PATH)/package/monit/files/monitrc \
		$(TARGET_DIR)/etc/monitrc

	$(INSTALL) -D -m 0600 $(BR2_EXTERNAL_EXTPACK_PATH)/package/monit/files/adbd.conf \
		$(TARGET_DIR)/etc/monit.d/adbd.conf

	$(INSTALL) -D -m 0755 $(BR2_EXTERNAL_EXTPACK_PATH)/package/monit/files/check-usb-state.sh \
		$(TARGET_DIR)/usr/bin/check-usb-state.sh

	$(INSTALL) -D -m 0755 $(BR2_EXTERNAL_EXTPACK_PATH)/package/monit/files/S99monit \
		$(TARGET_DIR)/etc/init.d/S99monit
endef
