ARCHS = arm64
TARGET = iphone:clang:15.6:14.0

FINALPACKAGE = 1
FOR_RELEASE = 1
WARNINGS = 1
SDKVERSION = 15.6

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = 34306jit

$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation QuartzCore CoreGraphics CoreText AVFoundation Accelerate GLKit SystemConfiguration GameController
$(TWEAK_NAME)_CCFLAGS = -fno-rtti -fvisibility=hidden -DNDEBUG -std=c++11 -I. -I5Toubun
$(TWEAK_NAME)_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-value -I. -I5Toubun -DHAVE_INTTYPES_H -DHAVE_PKCRYPT -DHAVE_STDINT_H -DHAVE_WZAES -DHAVE_ZLIB
$(TWEAK_NAME)_LDFLAGS = 5Toubun/libdobby.a lib/libdaubuoi.a lib/libmonostring.a linh_tinh/spam.a -lresolv -lz -liconv
$(TWEAK_NAME)_FILES = ImGuiDrawView.mm $(wildcard Esp/*.mm) $(wildcard Esp/*.m) $(wildcard IMGUI/*.cpp) $(wildcard IMGUI/*.mm)

include $(THEOS_MAKE_PATH)/tweak.mk
