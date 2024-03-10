include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=tcp-bbr-mod
PKG_RELEASE:=3

include $(INCLUDE_DIR)/package.mk

define KernelPackage/tcp-bbr-mod
	SUBMENU:=Network Support
	TITLE:=BBR TCP congestion control V3 from Google (test)
	DEPENDS:=@!LINUX_4_13
	FILES:=$(PKG_BUILD_DIR)/tcp_bbr_mod.ko
	AUTOLOAD:=$(call AutoProbe,tcp_bbr_mod)
endef

define KernelPackage/tcp-bbr-mod/description
	 Kernel module for BBR V3 (Bottleneck Bandwidth and RTT) TCP congestion
 control. It requires the fq ("Fair Queue") pacing packet scheduler.
 For kernel 4.13+, TCP internal pacing is implemented as fallback.
endef

EXTRA_KCONFIG:= \
    

EXTRA_CFLAGS:= \
	$(patsubst CONFIG_%, -DCONFIG_%=1, $(patsubst %=m,%,$(filter %=m,$(EXTRA_KCONFIG)))) \
	$(patsubst CONFIG_%, -DCONFIG_%=1, $(patsubst %=y,%,$(filter %=y,$(EXTRA_KCONFIG)))) \

MAKE_OPTS:= \
	ARCH="$(LINUX_KARCH)" \
	CROSS_COMPILE="$(TARGET_CROSS)" \
	SUBDIRS="$(PKG_BUILD_DIR)" \
	EXTRA_CFLAGS="$(EXTRA_CFLAGS)" \
	$(EXTRA_KCONFIG)

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

define Build/Compile
	$(MAKE) -C "$(LINUX_DIR)" \
	$(MAKE_OPTS) \
	modules
endef

$(eval $(call KernelPackage,tcp-bbr-mod))
