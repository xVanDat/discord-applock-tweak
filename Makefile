TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES := Discord
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DiscordAppLock

DiscordAppLock_FILES = Tweak.x
DiscordAppLock_CFLAGS = -fobjc-arc -Wno-unused-variable -Wno-error
DiscordAppLock_FRAMEWORKS = UIKit LocalAuthentication CoreGraphics QuartzCore AudioToolbox

include $(THEOS_MAKE_PATH)/tweak.mk
