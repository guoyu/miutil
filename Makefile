#
# Copyright (C) 2007-2011 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=miutil
PKG_VERSION:=1.1
PKG_RELEASE:=1

PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/miutil
  SECTION:=net
  CATEGORY:=XiaoQiang
  DEPENDS:=+luci-lib-core +luci-lib-sys +luci-lib-web +luci-lib-lua-cjson
  TITLE:=Xiaomi Util
endef

define Build/Prepare
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/miutil/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/mi
	$(CP) ./files/mi/* $(1)/usr/lib/lua/mi
	$(INSTALL_DIR) $(1)/etc/config
	$(CP) ./files/etc/config/* $(1)/etc/config
endef

$(eval $(call BuildPackage,miutil))
