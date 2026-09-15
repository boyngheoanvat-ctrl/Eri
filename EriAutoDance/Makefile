THEOS_DEVICE_IP = 127.0.0.1
TARGET := iphone:clang:latest:14.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = EriAutoDance

EriAutoDance_FILES = main.mm

# Dòng này cực kỳ quan trọng để Theos tìm thấy lua.h trong thư mục hiện tại
EriAutoDance_CFLAGS = -fobjc-arc -I.

include $(THEOS_MAKE_PATH)/tweak.mk
