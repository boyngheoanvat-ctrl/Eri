# Makefile — Eri Mod | FIXED UI + Compatibility
SDK_PATH := $(shell xcrun --sdk iphoneos --show-sdk-path)
CC := clang++

# === Sửa quan trọng: Thêm UIKit + Kiến trúc + Phiên bản ===
CFLAGS := -isysroot $(SDK_PATH) \
          -arch arm64 -arch arm64e \
          -mios-version-min:14.0 \
          -fobjc-arc -std=c++17 -O2 -Wall

# === Bắt buộc: Thêm -framework UIKit ===
LDFLAGS := -framework Foundation \
          -framework UIKit \
          -lsubstrate

TARGET := EriMod.dylib

all: $(TARGET)

$(TARGET): main.mm
	$(CC) $(CFLAGS) -shared -o $@ $^ $(LDFLAGS)
	@echo "✅ Biên dịch xong: $(TARGET)"

clean:
	rm -f $(TARGET)
