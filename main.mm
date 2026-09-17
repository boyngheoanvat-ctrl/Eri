#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include "substrate.h"
#include "lua_script.h"

extern "C" {
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
}

static lua_State *L = NULL;
static BOOL isLuaLoaded = NO;
static dispatch_source_t modLoopTimer = nil;

// 1. Nạp script Lua từ bộ nhớ nhúng
static void initLuaScriptEmbedded() {
    if (isLuaLoaded) return;

    L = luaL_newstate();
    if (!L) return;
    luaL_openlibs(L);

    if (luaL_loadbuffer(L, (const char *)Autodancehex_lua, Autodancehex_lua_len, "AutoDanceHex.lua") == LUA_OK) {
        if (lua_pcall(L, 0, LUA_MULTRET, 0) == LUA_OK) {
            isLuaLoaded = YES;
            NSLog(@"[AutoDanceHex] Đã nạp script Lua thành công!");
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

// 2. Vòng lặp gọi hàm Lua liên tục
static void executeLuaModLoop() {
    if (!isLuaLoaded || !L) return;

    lua_getglobal(L, "state");
    if (lua_istable(L, -1)) {
        lua_getfield(L, -1, "miniOn");
        BOOL miniOn = lua_toboolean(L, -1);
        lua_pop(L, 1);

        lua_getfield(L, -1, "activeOn");
        BOOL activeOn = lua_toboolean(L, -1);
        lua_pop(L, 1);

        lua_getfield(L, -1, "taikoOn");
        BOOL taikoOn = lua_toboolean(L, -1);
        lua_pop(L, 1);
        
        lua_pop(L, 1); // pop state table

        if (miniOn) {
            lua_getglobal(L, "applyMiniMod");
            if (lua_isfunction(L, -1)) { lua_pcall(L, 0, 0, 0); } else { lua_pop(L, 1); }

            lua_getglobal(L, "repairCrazyKeys");
            if (lua_isfunction(L, -1)) { lua_pcall(L, 0, 0, 0); } else { lua_pop(L, 1); }

            lua_getglobal(L, "applyCrazyScoreFix");
            if (lua_isfunction(L, -1)) { lua_pcall(L, 0, 0, 0); } else { lua_pop(L, 1); }
        }

        if (activeOn) {
            lua_getglobal(L, "applyAuditionMod");
            if (lua_isfunction(L, -1)) { lua_pcall(L, 0, 0, 0); } else { lua_pop(L, 1); }
        }

        if (taikoOn) {
            lua_getglobal(L, "applyTaikoMod");
            if (lua_isfunction(L, -1)) { lua_pcall(L, 0, 0, 0); } else { lua_pop(L, 1); }
        }
    } else {
        lua_pop(L, 1);
    }
}

static void startModLoop() {
    if (modLoopTimer) return;
    dispatch_queue_t queue = dispatch_get_main_queue();
    modLoopTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(modLoopTimer, dispatch_time(DISPATCH_TIME_NOW, 0), 0.05 * NSEC_PER_SEC, 0.01 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(modLoopTimer, ^{
        executeLuaModLoop();
    });
    dispatch_resume(modLoopTimer);
}

// Lấy cửa sổ game hiện tại an toàn
static UIWindow *getCurrentWindow() {
    UIWindow *foundWindow = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            for (UIWindow *window in windowScene.windows) {
                if (window.isKeyWindow) { return window; }
                if (!foundWindow) { foundWindow = window; }
            }
        }
    }
    return foundWindow;
}

@interface AutoDanceMenuController : NSObject
+ (void)showMenu;
+ (void)showToast:(NSString *)message;
@end

@implementation AutoDanceMenuController

+ (void)showMenu {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = getCurrentWindow();
        if (!window) return;

        UIViewController *rootVC = window.rootViewController;
        while (rootVC.presentedViewController) {
            rootVC = rootVC.presentedViewController;
        }

        // Đọc trạng thái từ Lua state để hiển thị tiêu đề menu chuẩn xác
        BOOL activeOn = NO, taikoOn = NO, miniOn = NO;
        if (L) {
            lua_getglobal(L, "state");
            if (lua_istable(L, -1)) {
                lua_getfield(L, -1, "activeOn"); activeOn = lua_toboolean(L, -1); lua_pop(L, 1);
                lua_getfield(L, -1, "taikoOn"); taikoOn = lua_toboolean(L, -1); lua_pop(L, 1);
                lua_getfield(L, -1, "miniOn"); miniOn = lua_toboolean(L, -1); lua_pop(L, 1);
            }
            lua_pop(L, 1);
        }

        NSString *msg = [NSString stringWithFormat:@"Trạng thái hiện tại:\n• Auto Arrow: %@\n• Taiko Mode: %@\n• Full Mini Game: %@",
                         activeOn ? @"🟢 BẬT" : @"🔴 TẮT",
                         taikoOn ? @"🟢 BẬT" : @"🔴 TẮT",
                         miniOn ? @"🟢 BẬT" : @"🔴 TẮT"];

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"AutoDance Hex v7.2"
                                                                     message:msg
                                                              preferredStyle:UIAlertControllerStyleAlert];

        // Nút chuyển đổi Auto Arrow
        [alert addAction:[UIAlertAction actionWithTitle:activeOn ? @"🔴 Tắt Auto Arrow" : @"🟢 Bật Auto Arrow" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            BOOL newState = !activeOn;
            if (L) {
                lua_getglobal(L, "state");
                if (lua_istable(L, -1)) {
                    lua_pushboolean(L, newState);
                    lua_setfield(L, -2, "activeOn");
                }
                lua_pop(L, 1);
            }
            [self showToast:newState ? @"Đã Bật Auto Arrow!" : @"Đã Tắt Auto Arrow!"];
        }]];

        // Nút chuyển đổi Taiko Mode
        [alert addAction:[UIAlertAction actionWithTitle:taikoOn ? @"🔴 Tắt Taiko Mode" : @"🟢 Bật Taiko Mode" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            BOOL newState = !taikoOn;
            if (L) {
                lua_getglobal(L, "state");
                if (lua_istable(L, -1)) {
                    lua_pushboolean(L, newState);
                    lua_setfield(L, -2, "taikoOn");
                }
                lua_pop(L, 1);
            }
            [self showToast:newState ? @"Đã Bật Taiko Mode!" : @"Đã Tắt Taiko Mode!"];
        }]];

        // Nút chuyển đổi Full Mini Game
        [alert addAction:[UIAlertAction actionWithTitle:miniOn ? @"🔴 Tắt Full Mini Game" : @"🟢 Bật Full Mini Game" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            BOOL newState = !miniOn;
            if (L) {
                lua_getglobal(L, "state");
                if (lua_istable(L, -1)) {
                    lua_pushboolean(L, newState);
                    lua_setfield(L, -2, "miniOn");
                }
                lua_pop(L, 1);
            }
            [self showToast:newState ? @"Đã Bật Full Mini Game!" : @"Đã Tắt Full Mini Game!"];
        }]];

        // Nút Đóng
        [alert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];

        [rootVC presentViewController:alert animated:YES completion:nil];
    });
}

+ (void)showToast:(NSString *)message {
    UIWindow *window = getCurrentWindow();
    if (!window) return;
    
    UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake(40, window.frame.size.height - 160, window.frame.size.width - 80, 45)];
    toast.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:0.9];
    toast.textColor = [UIColor whiteColor];
    toast.textAlignment = NSTextAlignmentCenter;
    toast.font = [UIFont boldSystemFontOfSize:15];
    toast.text = message;
    toast.layer.cornerRadius = 12;
    toast.clipsToBounds = YES;
    [window addSubview:toast];
    
    [UIView animateWithDuration:2.5 animations:^{
        toast.alpha = 0.0;
    } completion:^(BOOL finished) {
        [toast removeFromSuperview];
    }];
}

@end

// Bắt sự kiện chạm 2 ngón tay
@interface MenuGestureHandler : NSObject
@end

@implementation MenuGestureHandler
+ (void)setupGesture {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = getCurrentWindow();
        if (window) {
            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTwoFingerTap:)];
            tap.numberOfTouchesRequired = 2;
            [window addGestureRecognizer:tap];
            NSLog(@"[AutoDanceHex] Đã thiết lập thành công cử chỉ chạm 2 ngón tay mở menu!");
        }
    });
}

+ (void)handleTwoFingerTap:(UITapGestureRecognizer * __unused)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        [AutoDanceMenuController showMenu];
    }
}
@end

// Khởi chạy khi dylib được tiêm vào game
__attribute__((constructor)) static void entry() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        initLuaScriptEmbedded();
        startModLoop();
        [MenuGestureHandler setupGesture];
        NSLog(@"[AutoDanceHex] Tweak đã khởi chạy thành công!");
    });
}
