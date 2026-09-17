#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include "substrate.h"
#include "lua_script.h" // Chứa mảng byte của file Lua (Autodancehex_lua)

extern "C" {
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
}

static lua_State *L = NULL;
static BOOL isLuaLoaded = NO;
static dispatch_source_t renderTimer = nil;

// 1. Hàm nạp script Lua nhúng từ bộ nhớ
static void initLuaScriptEmbedded() {
    if (isLuaLoaded) return;

    L = luaL_newstate();
    if (!L) return;
    luaL_openlibs(L);

    // Nạp dữ liệu từ lua_script.h
    if (luaL_loadbuffer(L, (const char *)Autodancehex_lua, Autodancehex_lua_len, "AutoDanceHex.lua") == LUA_OK) {
        if (lua_pcall(L, 0, LUA_MULTRET, 0) == LUA_OK) {
            isLuaLoaded = YES;
            NSLog(@"[AutoDanceHex] Đã nạp script Lua thành công vào memory!");
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

// 2. Hàm gọi liên tục hàm OnDraw() trong Lua mỗi frame (khoảng 60 FPS)
static void executeLuaDraw() {
    if (!isLuaLoaded || !L) return;

    lua_getglobal(L, "OnDraw");
    if (lua_isfunction(L, -1)) {
        if (lua_pcall(L, 0, 0, 0) != LUA_OK) {
            const char *err = lua_tostring(L, -1);
            // Tránh spam log quá nhiều nếu lỗi nhẹ
            lua_pop(L, 1);
        }
    } else {
        lua_pop(L, 1);
    }
}

// 3. Khởi tạo vòng lặp render ngầm độc lập
static void startRenderLoop() {
    if (renderTimer) return;
    
    dispatch_queue_t queue = dispatch_get_main_queue();
    renderTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    
    // Đặt tần số quét ~60 FPS (0.0166 giây / lần)
    dispatch_source_set_timer(renderTimer, dispatch_time(DISPATCH_TIME_NOW, 0), 0.01666 * NSEC_PER_SEC, 0.001 * NSEC_PER_SEC);
    
    dispatch_source_set_event_handler(renderTimer, ^{
        executeLuaDraw();
    });
    
    dispatch_resume(renderTimer);
}

// Entry point khi dylib được tiêm vào game Au 2
__attribute__((constructor)) static void entry() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        initLuaScriptEmbedded();
        startRenderLoop();
        NSLog(@"[AutoDanceHex] Tweak đã khởi chạy vòng lặp Lua thành công!");
    });
}
