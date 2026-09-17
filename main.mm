#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include "substrate.h"

// Khai báo thư viện Lua
extern "C" {
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
}

static lua_State *L = NULL;
static BOOL isLuaLoaded = NO;

// Hàm nạp file Lua từ thư mục chứa tweak trên thiết bị
static void initLuaScript() {
    if (isLuaLoaded) return;

    L = luaL_newstate();
    if (!L) return;

    luaL_openlibs(L);

    // Tìm file AutoDanceHex.lua chung thư mục với dylib tweak (hoặc đường dẫn rootless chuẩn)
    NSString *scriptPath = @"/Library/MobileSubstrate/DynamicLibraries/AutoDanceHex.lua";
    
    // Nếu không tìm thấy, thử tìm trong thư mục ứng dụng hiện tại
    if (![[NSFileManager defaultManager] fileExistsAtPath:scriptPath]) {
        NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
        scriptPath = [bundlePath stringByAppendingPathComponent:@"AutoDanceHex.lua"];
    }

    if (scriptPath && [[NSFileManager defaultManager] fileExistsAtPath:scriptPath]) {
        if (luaL_dofile(L, [scriptPath UTF8String]) == LUA_OK) {
            isLuaLoaded = YES;
            NSLog(@"[AutoDanceHex] Đã nạp script Lua thành công từ: %@", scriptPath);
        } else {
            const char *err = lua_tostring(L, -1);
            NSLog(@"[AutoDanceHex] Lỗi Lua: %s", err);
            lua_pop(L, 1);
        }
    } else {
        NSLog(@"[AutoDanceHex] Không tìm thấy file AutoDanceHex.lua! Hãy chắc chắn bạn đã copy file này vào chung thư mục chứa dylib.");
    }
}

// Vòng lặp gọi hàm OnDraw từ Lua mỗi khung hình (Frame)
@interface LuaRenderLoop : NSObject
@end

@implementation LuaRenderLoop
+ (void)setupDisplayLink {
    CADisplayLink *link = [CADisplayLink displayLinkWithTarget:self selector:@selector(renderFrame:)];
    [link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

+ (void)renderFrame:(CADisplayLink *)sender {
    if (!isLuaLoaded || !L) return;

    lua_getglobal(L, "OnDraw");
    if (lua_isfunction(L, -1)) {
        if (lua_pcall(L, 0, 0, 0) != LUA_OK) {
            lua_pop(L, 1);
        }
    } else {
        lua_pop(L, 1);
    }
}
@end

// Khởi chạy ngay khi tweak được inject vào game
__attribute__((constructor)) static void entry() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        initLuaScript();
        [LuaRenderLoop setupDisplayLink];
        NSLog(@"[AutoDanceHex] Đã khởi chạy vòng lặp render trực tiếp!");
    });
}
