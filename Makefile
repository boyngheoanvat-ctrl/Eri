ARCHS = arm64
TARGET = iphone:clang:15.6:14.0
FINALPACKAGE = 1
FOR_RELEASE = 1
WARNINGS = 1
SDKVERSION = 15.6

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = 34306jit

# === Framework & thư viện ===
$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation Metal MetalKit
$(TWEAK_NAME)_CCFLAGS = -fno-rtti -fvisibility=hidden
$(TWEAK_NAME)_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
$(TWEAK_NAME)_LDFLAGS = -L5Toubun -ldobby
$(TWEAK_NAME)_FILES = ImGuiDrawView.mm Esp/JHPP.m Esp/JHUIViewControllerDecoupler.m Esp/ImGuiLoad.m \
                       IMGUI/Il2cpp.cpp IMGUI/imgui_demo.cpp IMGUI/imgui_tables.cpp \
                       IMGUI/imgui_impl_metal.mm IMGUI/imgui.cpp IMGUI/imgui_draw.cpp \
                       IMGUI/imgui_widgets.cpp Esp/PubgLoad.mm

# === QUAN TRỌNG: Copy file plist vào gói ===
$(TWEAK_NAME)_EXTRA_FILES = 34306jit.plist

include $(THEOS_MAKE_PATH)/tweak.mk
