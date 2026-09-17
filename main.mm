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

// 2. Vòng lặp gọi hàm Lua liên tục (~20 lần/giây) khi tính năng được bật
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

// Khai báo trước hàm showMenu để gọi lại dạng Checkbox tương tác
@interface AutoDanceMenuController : NSObject
+ (void)showMenu;
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

        // Đọc trạng thái hiện tại từ Lua state
        BOOL activeOn = NO;
        BOOL taikoOn = NO;
        BOOL miniOn = NO;

        if (L) {
            lua_getglobal(L, "state");
            if (lua_istable(L, -1)) {
                lua_getfield(L, -1, "activeOn");
                activeOn = lua_toboolean(L, -1);
                lua_pop(L, 1);

                lua_getfield(L, -1, "taikoOn");
                taikoOn = lua_toboolean(L, -1);
                lua_pop(L, 1);

                lua_getfield(L, -1, "miniOn");
                miniOn = lua_toboolean(L, -1);
                lua_pop(L, 1);
            }
            lua_pop(L, 1);
        }

        // Tạo tiêu đề Checkbox trực quan
        NSString *titleArrow = activeOn ? @"[ ✅ ] Bật Auto Arrow" : @"[ ❌ ] Bật Auto Arrow";
        NSString *titleTaiko = taikoOn ? @"[ ✅ ] Bật Taiko Mode" : @"[ ❌ ] Bật Taiko Mode";
        NSString *titleMini  = miniOn ?  @"[ ✅ ] Bật Full Mini Game" : @"[ ❌ ] Bật Full Mini Game";

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"AutoDance Hex v7.2"
                                                                     message:@"Chọn trạng thái Bật/Tắt tính năng:"
                                                              preferredStyle:UIAlertControllerStyleAlert];

        // 1. Nút Auto Arrow Checkbox
        [alert addAction:[UIAlertAction actionWithTitle:titleArrow style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            if (L) {
                lua_getglobal(L, "state");
                if (lua_istable(L, -1)) {
                    lua_pushboolean(L, !activeOn);
                    lua_setfield(L, -2, "activeOn");
                }
                lua_pop(L, 1);
            }
            [self showToast:activeOn ? @"Đã Tắt Auto Arrow" : @"Đã Bật Auto Arrow"];
            // Tự động bật lại menu để cập nhật dấu check mới
            [self showMenu];
        }]];

        // 2. Nút Taiko Mode Checkbox
        [alert addAction:[UIAlertAction actionWithTitle:titleTaiko style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            if (L) {
                lua_getglobal(L, "state");
                if (lua_istable(L, -1)) {
                    lua_pushboolean(L, !taikoOn);
                    lua_setfield(L, -2, "taikoOn");
                }
                lua_pop(L, 1);
            }
            [self showToast:taikoOn ? @"Đã Tắt Taiko Mode" : @"Đã Bật Taiko Mode"];
            [self showMenu];
        }]];

        // 3. Nút Full Mini Game Checkbox
        [alert addAction:[UIAlertAction actionWithTitle:titleMini style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            if (L) {
                lua_getglobal(L, "state");
                if (lua_istable(L, -1)) {
                    lua_pushboolean(L, !miniOn);
                    lua_setfield(L, -2, "miniOn");
                }
                lua_pop(L, 1);
            }
            [self showToast:miniOn ? @"Đã Tắt Full Mini Game" : @"Đã Bật Full Mini Game"];
            [self showMenu];
        }]];

        // Nút Đóng Menu
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
        startModLoop();
        [MenuGestureHandler setupGesture];
        NSLog(@"[AutoDanceHex] Tweak đã khởi chạy thành công!");
    });
}
