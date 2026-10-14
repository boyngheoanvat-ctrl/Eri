ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = libtool

libtool_FILES = \
    src/libtool.mm \
    src/FloatingButton.mm \
    src/core/ToolWindow.mm \
    src/core/ToolViewController.mm \
    src/core/ToolTheme.mm \
    src/core/ToolGestureManager.mm \
    src/ui/ToolRailButton.mm \
    src/ai/AIChatVC.mm \
    src/ai/AIProvider.mm \
    src/ai/AITool.mm \
    src/ai/AIMemoryTool.mm \
    src/memory/MemoryResult.mm \
    src/memory/MemoryEditor.mm \
    src/dump/IL2CPPResolver.mm \
    src/dump/DumperVC.mm

libtool_CFLAGS = -fobjc-arc -Isrc -Isrc/core -Isrc/ui -Isrc/ai -Isrc/dump -Wno-everything
libtool_FRAMEWORKS = Foundation UIKit CoreGraphics
libtool_LIBRARIES = objc
libtool_INSTALL_PATH = /Library/MobileSubstrate/DynamicLibraries

include $(THEOS_MAKE_PATH)/library.mk
