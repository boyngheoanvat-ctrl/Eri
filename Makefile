ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = libtool

# Tự động quét toàn bộ file .mm, .m, .cpp, .c trong thư mục src/ và các thư mục con
libtool_FILES = $(shell find src -name '*.mm' -o -name '*.m' -o -name '*.cpp' -o -name '*.c')

libtool_CFLAGS = -fobjc-arc -std=c++17 \
    -I. \
    $(shell find src -type d -exec echo -I{} ;) \
    -Ilibs \
    -Wno-everything

libtool_LDFLAGS = -Llibs -llua

libtool_FRAMEWORKS = Foundation UIKit CoreGraphics QuartzCore
libtool_LIBRARIES = objc
libtool_INSTALL_PATH = /Library/MobileSubstrate/DynamicLibraries

include $(THEOS_MAKE_PATH)/library.mk
