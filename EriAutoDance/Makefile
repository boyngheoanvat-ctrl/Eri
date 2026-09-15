THEOS_DEVICE_IP = 127.0.0.1
TARGET := iphone:clang:latest:14.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = EriAutoDance

EriAutoDance_FILES = main.mm
EriAutoDance_CFLAGS = -fobjc-arc
EriAutoDance_CCFLAGS = -std=c++11 -fno-rtti -fno-exceptions

include $(THEOS_MAKE_PATH)/tweak.mk
