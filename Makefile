SDK_PATH := $(shell xcrun --sdk iphoneos --show-sdk-path)
CC := clang++

CFLAGS := -isysroot $(SDK_PATH) \
          -arch arm64 -arch arm64e \
          -mios-version-min=14.0 \
          -fobjc-arc -std=c++17 -O2 -Wall

LDFLAGS := -framework Foundation \
          -framework UIKit \
          -undefined dynamic_lookup

TARGET := EriMod.dylib

all: $(TARGET)

$(TARGET): Tweak.xm
	$(CC) $(CFLAGS) -shared -o $@ -x objective-c++ $< $(LDFLAGS)
	@echo "✅ Build xong: $(TARGET)"

clean:
	rm -f $(TARGET)
