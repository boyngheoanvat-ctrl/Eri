target := iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = EriAutoDance

EriAutoDance_FILES = main.mm ImGui/imgui.cpp ImGui/imgui_draw.cpp ImGui/imgui_tables.cpp ImGui/imgui_widgets.cpp
EriAutoDance_CFLAGS = -fobjc-arc -I. -IImGui

include $(THEOS_MAKE_PATH)/library.mk

