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

// Nạp script Lua từ bộ nhớ nhúng
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

// Lấy cửa sổ game hiện tại an toàn
static UIWindow *getCurrentWindow() {
    UIWindow *foundWindow = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            for (UIWindow *window in windowScene.windows) {
                if (window.isKeyWindow) {
                    return window;
                }
                if (!foundWindow) {
                    foundWindow = window;
                }
            }
        }
    }
    return foundWindow;
}

// Hiển thị Menu UIKit nổi trên màn hình Au 2 khi chạm 2 ngón tay
@interface AutoDanceMenuController : NSObject
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

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"AutoDance Hex v7.2"
                                                                     message:@"Đã kích hoạt menu điều khiển Au 2:"
                                                              preferredStyle:UIAlertControllerStyleAlert];

        // Nút bật tính năng Audition Mod
        [alert addAction:[UIAlertAction actionWithTitle:@"🟢 Bật Auto Arrow" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            if (L) {
                lua_getglobal(L, "state");
                if (lua_istable(L, -1)) {
                    lua_pushboolean(L, 1);
                    lua_setfield(L, -2, "activeOn");
                }
                lua_pop(L, 1);
            }
            [self showToast:@"Đã bật Auto Arrow!"];
        }]];

        // Nút bật Taiko Mod
        [alert addAction:[UIAlertAction actionWithTitle:@"🎯 Bật Taiko Mode" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            if (L) {
                lua_getglobal(L, "state");
                if (lua_istable(L, -1)) {
                    lua_pushboolean(L, 1);
                    lua_setfield(L, -2, "taikoOn");
                }
                lua_pop(L, 1);
            }
            [self showToast:@"Đã bật Taiko Mode!"];
        }]];

        // Nút bật Full Mini Game & Crazy Score Fix
        [alert addAction:[UIAlertAction actionWithTitle:@"⚡ Bật Full Mini Game" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            if (L) {
                lua_getglobal(L, "state");
                if (lua_istable(L, -1)) {
                    lua_pushboolean(L, 1);
                    lua_setfield(L, -2, "miniOn");
                }
                lua_pop(L, 1);
            }
            [self showToast:@"Đã bật Full Mini Game & Crazy Score!"];
        }]];

        // Nút Đóng
        [alert addAction:[UIAlertAction actionWithTitle:@"Đóng Menu" style:UIAlertActionStyleCancel handler:nil]];

        [rootVC presentViewController:alert animated:YES completion:nil];
    });
}

+ (void)showToast:(NSString *)message {
    UIWindow *window = getCurrentWindow();
    if (!window) return;
    
    UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake(50, window.frame.size.height - 150, window.frame.size.width - 100, 40)];
    toast.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.8];
    toast.textColor = [UIColor whiteColor];
    toast.textAlignment = NSTextAlignmentCenter;
    toast.font = [UIFont boldSystemFontOfSize:14];
    toast.text = message;
    toast.layer.cornerRadius = 10;
    toast.clipsToBounds = YES;
    [window addSubview:toast];
    
    [UIView animateWithDuration:2.0 animations:^{
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
        [MenuGestureHandler setupGesture];
        NSLog(@"[AutoDanceHex] Tweak đã khởi chạy thành công!");
    });
}
