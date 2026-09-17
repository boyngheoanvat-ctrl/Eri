#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include "substrate.h"
#include "lua_script.h"

// Khai báo thư viện Lua
extern "C" {
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
}

static lua_State *L = NULL;
static BOOL isLuaLoaded = NO;

// Nạp script Lua từ bộ nhớ nhúng trong dylib
static void initLuaScriptEmbedded() {
    if (isLuaLoaded) return;

    L = luaL_newstate();
    if (!L) return;

    luaL_openlibs(L);

    if (luaL_loadbuffer(L, (const char *)Autodancehex_lua, Autodancehex_lua_len, "AutoDanceHex.lua") == LUA_OK) {
        if (lua_pcall(L, 0, LUA_MULTRET, 0) == LUA_OK) {
            isLuaLoaded = YES;
            NSLog(@"[AutoDanceHex] Đã nạp script Lua nhúng thành công!");
        } else {
            const char *err = lua_tostring(L, -1);
            NSLog(@"[AutoDanceHex] Lỗi chạy script Lua: %s", err);
            lua_pop(L, 1);
        }
    } else {
        const char *err = lua_tostring(L, -1);
        NSLog(@"[AutoDanceHex] Lỗi load buffer Lua: %s", err);
        lua_pop(L, 1);
    }
}

// Vòng lặp render tự động hiển thị mỗi khung hình
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

// Khởi chạy khi dylib được tiêm vào game
__attribute__((constructor)) static void entry() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        initLuaScriptEmbedded();
        [LuaRenderLoop setupDisplayLink];
        NSLog(@"[AutoDanceHex] Tweak đã khởi chạy thành công hoàn toàn!");
    });
}
