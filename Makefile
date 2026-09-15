TARGET := iphone:clang:latest:14.0
ARCHS := arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AutoDanceTweak
AutoDanceTweak_FILES = main.mm
AutoDanceTweak_FRAMEWORKS = Foundation
AutoDanceTweak_LIBRARIES = substrate
AutoDanceTweak_CFLAGS = -fobjc-arc -std=c++17

include $(THEOS_MAKE_PATH)/tweak.mk
