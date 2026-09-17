# Makefile — Eri Mod
SDK_PATH := $(shell xcrun --sdk iphoneos --show-sdk-path)
CC := clang++
CFLAGS := -isysroot $(SDK_PATH) -fobjc-arc -std=c++17 -O2 -Wall
LDFLAGS := -framework Foundation -lsubstrate

TARGET := EriMod.dylib

all: $(TARGET)

$(TARGET): main.mm
	$(CC) $(CFLAGS) -shared -o $@ $^ $(LDFLAGS)
	@echo "✅ Biên dịch xong: $(TARGET)"

clean:
	rm -f $(TARGET)
