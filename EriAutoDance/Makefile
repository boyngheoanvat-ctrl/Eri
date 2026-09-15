THEOS_DEVICE_IP = 127.0.0.1
TARGET := iphone:clang:latest:14.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = EriAutoDance

# Khai báo file main.mm và toàn bộ mã nguồn .c của Lua để tiến hành biên dịch tĩnh cùng tweak
EriAutoDance_FILES = main.mm lapi.c lauxlib.c lbaselib.c lcode.c lcorolib.c lctype.c ldblib.c ldebug.c ldo.c ldump.c lfunc.c lgc.c linit.c liolib.c llex.c lmathlib.c lmem.c loadlib.c lobject.c lopcodes.c lparser.c lstate.c lstring.c lstrlib.c ltable.c ltablib.c ltm.c lundump.c lutf8lib.c lvm.c lzio.c

# Thêm cờ biên dịch để nhận diện đường dẫn header tại thư mục hiện tại (.)
EriAutoDance_CFLAGS = -fobjc-arc -I.

include $(THEOS_MAKE_PATH)/tweak.mk
