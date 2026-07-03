################################################################################
#
# farmhash
#
################################################################################

FARMHASH_VERSION = 0d859a811870d10f53a594927d0d0b97573ad06d
FARMHASH_SITE = $(call github,google,farmhash,$(FARMHASH_VERSION))
FARMHASH_LICENSE = MIT
FARMHASH_LICENSE_FILES = COPYING
FARMHASH_INSTALL_STAGING = YES
FARMHASH_INSTALL_TARGET = YES

FARMHASH_CONF_ENV = CXXFLAGS="$(TARGET_CXXFLAGS) -std=c++11"

define FARMHASH_POST_INSTALL_TARGET_RM_FILES
	rm -rf $(TARGET_DIR)/usr/include
	rm -rf $(TARGET_DIR)/usr/share/doc
endef

FARMHASH_POST_INSTALL_TARGET_HOOKS += FARMHASH_POST_INSTALL_TARGET_RM_FILES

$(eval $(autotools-package))
