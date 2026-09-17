# Makefile — Eri Mod | FIXED BUILD
SDK_PATH := $(shell xcrun --sdk iphoneos --show-sdk-path)
CC := clang++

CFLAGS := -isysroot $(SDK_PATH) \
          -arch arm64 -arch arm64e \
          -mios-version-min=14.0 \
          -fobjc-arc -std=c++17 -O2 -Wall

LDFLAGS := -framework Foundation \
          -framework UIKit \
          -framework CoreGraphics \
          -framework Dispatch \
          -lsubstrate

TARGET := EriMod.dylib

all: $(TARGET)

$(TARGET): main.mm
	$(CC) $(CFLAGS) -shared -o $@ $^ $(LDFLAGS)
	@echo "✅ Biên dịch xong: $(TARGET)"

clean:
	rm -f $(TARGET)
