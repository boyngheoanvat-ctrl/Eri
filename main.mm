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
static dispatch_source_t renderTimer = nil;

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

// Vòng lặp chạy ngầm gọi hàm OnDraw định kỳ (~60 fps)
static void startRenderLoop() {
    if (renderTimer) return;
    
    dispatch_queue_t queue = dispatch_get_main_queue();
    renderTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    
    dispatch_source_set_timer(renderTimer, dispatch_time(DISPATCH_TIME_NOW, 0), 0.01666 * NSEC_PER_SEC, 0.001 * NSEC_PER_SEC);
    
    dispatch_source_set_event_handler(renderTimer, ^{
        if (!isLuaLoaded || !L) return;

        lua_getglobal(L, "OnDraw");
        if (lua_isfunction(L, -1)) {
            if (lua_pcall(L, 0, 0, 0) != LUA_OK) {
                lua_pop(L, 1);
            }
        } else {
            lua_pop(L, 1);
        }
    });
    
    dispatch_resume(renderTimer);
}

// Khởi chạy khi dylib được tiêm vào game
__attribute__((constructor)) static void entry() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        initLuaScriptEmbedded();
        startRenderLoop();
        NSLog(@"[AutoDanceHex] Tweak đã khởi chạy thành công hoàn toàn!");
    });
}
