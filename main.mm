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

// Hiển thị Menu Native UIKit (Chắc chắn hiện lên trên màn hình Au 2)
@interface AutoDanceMenuController : NSObject
@end

@implementation AutoDanceMenuController

+ (void)showMenu {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = nil;
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (w.isKeyWindow) {
                window = w;
                break;
            }
        }
        if (!window && [UIApplication sharedApplication].windows.count > 0) {
            window = [UIApplication sharedApplication].windows[0];
        }

        UIViewController *rootVC = window.rootViewController;
        while (rootVC.presentedViewController) {
            rootVC = rootVC.presentedViewController;
        }

        // Tạo bảng điều khiển menu UIKit
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"AutoDance Hex v7.2"
                                                                     message:@"Chọn tính năng hack/mod cho Au 2:"
                                                              preferredStyle:UIAlertControllerStyleAlert];

        // Nút Bật/Tắt Auto Arrow
        [alert addAction:[UIAlertAction actionWithTitle:@"🟢 Bật/Tắt Auto Arrow" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            if (L) {
                // Gọi hàm Lua tương ứng nếu có
                lua_getglobal(L, "ToggleAutoArrow");
                if (lua_isfunction(L, -1)) {
                    lua_pcall(L, 0, 0, 0);
                } else {
                    lua_pop(L, 1);
                }
            }
            [self showToast:@"Đã kích hoạt Auto Arrow!"];
        }]];

        // Nút Bật Taiko Mode
        [alert addAction:[UIAlertAction actionWithTitle:@"🎯 Bật Taiko Mode" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self showToast:@"Đã bật chế độ Taiko!"];
        }]];

        // Nút Đóng Menu
        [alert addAction:[UIAlertAction actionWithTitle:@"Đóng Menu" style:UIAlertActionStyleCancel handler:nil]];

        [rootVC presentViewController:alert animated:YES completion:nil];
    });
}

+ (void)showToast:(NSString *)message {
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake(50, window.frame.size.height - 150, window.frame.size.width - 100, 40)];
    toast.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.8];
    toast.textColor = [UIColor whiteOfColor] ? [UIColor whiteColor] : [UIColor whiteColor];
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

// Lắng nghe cử chỉ chạm 2 ngón tay để hiện menu
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
            tap.numberOfTouchesRequired = 2; // Chạm 2 ngón tay đồng thời
            [keyWindow addGestureRecognizer:tap];
            NSLog(@"[AutoDanceHex] Đã cài đặt thành công cử chỉ chạm 2 ngón tay mở menu!");
        }
    });
}

+ (void)handleTwoFingerTap:(UITapGestureRecognizer *)sender {
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
