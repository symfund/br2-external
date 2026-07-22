################################################################################
#
# adb (Android Debug Bridge)
#
################################################################################

ADB_VERSION = 1.0
#ADB_SOURCE =
ADB_SITE = $(BR2_EXTERNAL_EXTPACK_PATH)/package/adb/files
ADB_SITE_METHOD = local
ADB_LICENSE = Public Domain

ADB_DEPENDENCIES = android-tools monit

define ADB_LINUX_CONFIG_FIXUPS
	$(call KCONFIG_ENABLE_OPT,CONFIG_USB_CONFIGFS)
	$(call KCONFIG_ENABLE_OPT,CONFIG_USB_CONFIGFS_F_FS)
	$(call KCONFIG_DISABLE_OPT,CONFIG_USB_MASS_STORAGE)
	$(if $(BR2_EXTPACK_ADB_SERIAL),
		$(call KCONFIG_ENABLE_OPT,CONFIG_USB_CONFIGFS_ACM)
	)
	$(if $(BR2_EXTPACK_ADB_NETWORK),
		$(call KCONFIG_ENABLE_OPT,CONFIG_USB_CONFIGFS_RNDIS)
	)
	$(if $(BR2_EXTPACK_ADB_STORAGE),
		$(call KCONFIG_ENABLE_OPT,CONFIG_USB_CONFIGFS_MASS_STORAGE)
	)
endef

ADB_LINUX_CONFIG_FIXUPS_CMDS = $(ADB_LINUX_CONFIG_FIXUPS)

define ADB_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(BR2_EXTERNAL_EXTPACK_PATH)/package/adb/files/S99adbd \
		$(TARGET_DIR)/etc/init.d/S99adbd
endef

$(eval $(generic-package))
