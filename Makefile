TARGET := iphone:clang:latest:14.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := AutoDanceHex
AutoDanceHex_FILES = main.mm
AutoDanceHex_FRAMEWORKS = UIKit Foundation Security
AutoDanceHex_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -I$(THEOS)/include -I$(THEOS)/vendor/include

include $(THEOS_MAKE_PATH)/tweak.mk
