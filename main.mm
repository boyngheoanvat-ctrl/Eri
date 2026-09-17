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
static BOOL isMenuVisible = YES; // Trạng thái ẩn/hiện menu
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

// Hàm gọi thực thi OnDraw từ Lua (chỉ gọi khi menu đang bật)
static void executeLuaDraw() {
    if (!isLuaLoaded || !L || !isMenuVisible) return;

    lua_getglobal(L, "OnDraw");
    if (lua_isfunction(L, -1)) {
        if (lua_pcall(L, 0, 0, 0) != LUA_OK) {
            const char *err = lua_tostring(L, -1);
            NSLog(@"[AutoDanceHex] Lỗi gọi OnDraw: %s", err);
            lua_pop(L, 1);
        }
    } else {
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
        executeLuaDraw();
    });
    
    dispatch_resume(renderTimer);
}

// Gesture lắng nghe sự kiện chạm 2 ngón tay để ẩn/hiện menu
@interface MenuGestureHandler : NSObject
@end

@implementation MenuGestureHandler
+ (void)setupGesture {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = nil;
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (window.isKeyWindow) {
                keyWindow = window;
                break;
            }
        }
        if (!keyWindow && [UIApplication sharedApplication].windows.count > 0) {
            keyWindow = [UIApplication sharedApplication].windows[0];
        }

        if (keyWindow) {
            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTwoFingerTap:)];
            tap.numberOfTouchesRequired = 2; // Yêu cầu chạm 2 ngón tay cùng lúc
            [keyWindow addGestureRecognizer:tap];
            NSLog(@"[AutoDanceHex] Đã thiết lập cử chỉ chạm 2 ngón tay ẩn/hiện menu!");
        }
    });
}

+ (void)handleTwoFingerTap:(UITapGestureRecognizer * __unused)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        // Đảo trạng thái ẩn/hiện
        isMenuVisible = !isMenuVisible;
        
        NSLog(@"[AutoDanceHex] Trạng thái hiển thị menu: %@", isMenuVisible ? @"HIỆN" : @"ẨN");
    }
}
@end

// Khởi chạy khi dylib được tiêm vào game
__attribute__((constructor)) static void entry() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        initLuaScriptEmbedded();
        startRenderLoop();
        [MenuGestureHandler setupGesture];
        NSLog(@"[AutoDanceHex] Tweak đã khởi chạy hoàn tất với cử chỉ 2 ngón tay ẩn/hiện!");
    });
}
