#import "LuaEngine.h"
#import <UIKit/UIKit.h>
#import <dlfcn.h>

// Include Lua headers
extern "C" {
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
}

// Biến toàn cục quản lý cửa sổ nổi UI trong game
static UIWindow *floatingMenuWindow = nil;
static UIView *floatingContainer = nil;
static NSMutableDictionary *luaCallbacks = nil;

@interface LuaEngine ()
@property (nonatomic, assign) lua_State *L;
@end

@implementation LuaEngine

+ (instancetype)shared {
    static LuaEngine *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[LuaEngine alloc] init]; });
    return instance;
}

- (BOOL)isAvailable {
    return YES;
}

// ==========================================
// CÁC HÀM CẦU NỐI (LUA BRIDGE IMPLEMENTATION)
// ==========================================

// 1. Tạo cửa sổ nổi: UI.CreateWindow(title, width, height)
static int l_create_window(lua_State *L) {
    const char *title = lua_tostring(L, 1);
    double width = lua_tonumber(L, 2);
    double height = lua_tonumber(L, 3);
    
    if (width <= 0) width = 240;
    if (height <= 0) height = 320;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (floatingMenuWindow) {
            [floatingMenuWindow setHidden:YES];
            floatingMenuWindow = nil;
        }

        UIWindowScene *scene = nil;
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]]) {
                scene = (UIWindowScene *)s;
                break;
            }
        }

        if (scene) {
            floatingMenuWindow = [[UIWindow alloc] initWithWindowScene:scene];
        } else {
            floatingMenuWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        }

        floatingMenuWindow.windowLevel = UIWindowLevelAlert + 999;
        floatingMenuWindow.backgroundColor = [UIColor clearColor];

        UIViewController *vc = [[UIViewController alloc] init];
        floatingMenuWindow.rootViewController = vc;

        // Container chính của Menu (Bo góc, màu tối trong suốt phong cách mod menu)
        CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
        CGFloat screenH = [UIScreen mainScreen].bounds.size.height;
        
        floatingContainer = [[UIView alloc] initWithFrame:CGRectMake((screenW - width) / 2, (screenH - height) / 2, width, height)];
        floatingContainer.backgroundColor = [UIColor colorWithRed:0.12 green:0.14 blue:0.18 alpha:0.92];
        floatingContainer.layer.cornerRadius = 10;
        floatingContainer.layer.borderWidth = 1.0;
        floatingContainer.layer.borderColor = [UIColor colorWithRed:0.0 green:0.85 blue:0.55 alpha:1.0].CGColor;
        
        // Cho phép kéo thả menu nổi di chuyển trên màn hình
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:[LuaEngine shared] action:@selector(handlePan:)];
        [floatingContainer addGestureRecognizer:pan];
        floatingContainer.userInteractionEnabled = YES;

        // Tiêu đề Menu
        UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, width - 44, 30)];
        titleLbl.text = title ? [NSString stringWithUTF8String:title] : @"MOD MENU";
        titleLbl.textColor = [UIColor colorWithRed:0.0 green:0.85 blue:0.55 alpha:1.0];
        titleLbl.font = [UIFont boldSystemFontOfSize:13];
        [floatingContainer addSubview:titleLbl];

        // Nút thu nhỏ / đóng menu (X)
        UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        closeBtn.frame = CGRectMake(width - 34, 8, 26, 26];
        [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
        [closeBtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
        [closeBtn addTarget:[LuaEngine shared] action:@selector(closeFloatingMenu) forControlEvents:UIControlEventTouchUpInside];
        [floatingContainer addSubview:closeBtn];

        // Vùng chứa các control (Toggle, Label)
        UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(8, 44, width - 16, height - 52)];
        scrollView.tag = 8888; // Tag để tìm lại và add control
        scrollView.contentSize = CGSizeMake(width - 16, 400);
        [floatingContainer addSubview:scrollView];

        [vc.view addSubview:floatingContainer];
        [floatingMenuWindow makeKeyAndVisible];
    });

    return 0;
}

// 2. Thêm Nhãn (Label): UI.AddLabel(text)
static int l_add_label(lua_State *L) {
    const char *text = lua_tostring(L, 1);
    if (!text) return 0;
    
    NSString *labelStr = [NSString stringWithUTF8String:text];

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!floatingContainer) return;
        UIScrollView *scrollView = [floatingContainer viewWithTag:8888];
        if (!scrollView) return;

        CGFloat currentY = 0;
        for (UIView *sub in scrollView.subviews) {
            currentY = MAX(currentY, CGRectGetMaxY(sub.frame) + 6);
        }

        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(4, currentY, scrollView.bounds.size.width - 8, 24)];
        lbl.text = labelStr;
        lbl.textColor = [UIColor whiteColor];
        lbl.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        [scrollView addSubview:lbl];
        
        scrollView.contentSize = CGSizeMake(scrollView.bounds.size.width, currentY + 30);
    });

    return 0;
}

// 3. Thêm Nút Gạt (Toggle Switch): UI.AddToggle(name, callback)
static int l_add_toggle(lua_State *L) {
    const char *name = lua_tostring(L, 1);
    if (!name) return 0;
    
    NSString *toggleName = [NSString stringWithUTF8String:name];

    // Lưu lại hàm callback Lua để gọi khi bật/tắt
    if (!luaCallbacks) luaCallbacks = [NSMutableDictionary dictionary];
    
    lua_pushvalue(L, 2); // Đẩy hàm callback lên đỉnh stack
    int ref = luaL_ref(L, LUA_REGISTRYINDEX); // Lưu vào registry
    [luaCallbacks setObject:@(ref) forKey:toggleName];

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!floatingContainer) return;
        UIScrollView *scrollView = [floatingContainer viewWithTag:8888];
        if (!scrollView) return;

        CGFloat currentY = 0;
        for (UIView *sub in scrollView.subviews) {
            currentY = MAX(currentY, CGRectGetMaxY(sub.frame) + 6);
        }

        UIView *row = [[UIView alloc] initWithFrame:CGRectMake(4, currentY, scrollView.bounds.size.width - 8, 34)];
        
        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(4, 2, row.bounds.size.width - 60, 30)];
        lbl.text = toggleName;
        lbl.textColor = [UIColor colorWithWhite:0.9 alpha:1.0];
        lbl.font = [UIFont systemFontOfSize:11];
        [row addSubview:lbl];

        UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(row.bounds.size.width - 52, 2, 50, 30)];
        sw.transform = CGAffineTransformMakeScale(0.75, 0.75);
        sw.onTintColor = [UIColor colorWithRed:0.0 green:0.85 blue:0.55 alpha:1.0];
        sw.accessibilityIdentifier = toggleName;
        [sw addTarget:[LuaEngine shared] action:@selector(didToggleSwitch:) forControlEvents:UIControlEventValueChanged];
        [row addSubview:sw];

        [scrollView addSubview:row];
        scrollView.contentSize = CGSizeMake(scrollView.bounds.size.width, currentY + 40);
    });

    return 0;
}

// 4. Hiển thị Menu: UI.Show()
static int l_show_window(lua_State *L) {
    // Đã hiển thị ngay khi tạo window
    return 0;
}

// 5. Hàm giả lập gg.setValues để patch RVA
static int l_gg_set_values(lua_State *L) {
    // Đọc bảng table truyền vào từ Lua
    if (lua_istable(L, 1)) {
        lua_pushnil(L);
        while (lua_next(L, 1) != 0) {
            if (lua_istable(L, -1)) {
                lua_getfield(L, -1, "address");
                uint64_t addr = (uint64_t)lua_tonumber(L, -1);
                lua_pop(L, 1);

                lua_getfield(L, -1, "value");
                uint32_t val = (uint32_t)lua_tointeger(L, -1);
                lua_pop(L, 1);

                // Thực hiện ghi đè bộ nhớ tại địa chỉ VA
                if (addr > 0) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        // Ghi giá trị vào vùng nhớ game
                        uint32_t *targetPtr = (uint32_t *)addr;
                        // Cấp quyền ghi bộ nhớ nếu cần
                        // vm_protect...
                        @try {
                            *targetPtr = val;
                            NSLog(@"[LuaPatch] Đã ghi thành công giá trị 0x%X vào địa chỉ 0x%llX", val, addr);
                        } @catch (NSException *exception) {
                            NSLog(@"[LuaPatch Lỗi] Không thể ghi bộ nhớ: %@", exception.reason);
                        }
                    });
                }
            }
            lua_pop(L, 1);
        }
    }
    return 0;
}

static int l_gg_toast(lua_State *L) {
    const char *msg = lua_tostring(L, 1);
    if (msg) {
        NSLog(@"[GG Toast] %s", msg);
    }
    return 0;
}

// ==========================================
// QUẢN LÝ SỰ KIỆN UI NỔI
// ==========================================

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:floatingContainer.superview];
    CGPoint center = floatingContainer.center;
    floatingContainer.center = CGPointMake(center.x + translation.x, center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:floatingContainer.superview];
}

- (void)closeFloatingMenu {
    if (floatingMenuWindow) {
        [floatingMenuWindow setHidden:YES];
        floatingMenuWindow = nil;
        floatingContainer = nil;
    }
}

- (void)didToggleSwitch:(UISwitch *)sender {
    NSString *key = sender.accessibilityIdentifier;
    if (!key || !luaCallbacks || !self.L) return;

    NSNumber *refNum = [luaCallbacks objectForKey:key];
    if (!refNum) return;

    lua_State *L = self.L;
    lua_rawgeti(L, LUA_REGISTRYINDEX, refNum.intValue); // Lấy hàm callback từ registry
    
    lua_pushboolean(L, sender.isOn); // Truyền trạng thái true/false vào hàm

    if (lua_pcall(L, 1, 0, 0) != 0) {
        const char *err = lua_tostring(L, -1);
        NSLog(@"[Lua Error] Callback failed: %s", err ? err : "unknown");
        lua_pop(L, 1);
    }
}

// ==========================================
// THỰC THI SCRIPT LUA
// ==========================================

- (NSString *)runScript:(NSString *)script {
    if (!script) return @"[Lua] Script rỗng";

    lua_State *L = luaL_newstate();
    if (!L) return @"[Lua] Không tạo được lua_State";

    luaL_openlibs(L);
    self.L = L;

    // Đăng ký bảng UI vào Lua
    lua_newtable(L);
    lua_pushcfunction(L, l_create_window); lua_setfield(L, -2, "CreateWindow");
    lua_pushcfunction(L, l_add_label);     lua_setfield(L, -2, "AddLabel");
    lua_pushcfunction(L, l_add_toggle);    lua_setfield(L, -2, "AddToggle");
    lua_pushcfunction(L, l_show_window);   lua_setfield(L, -2, "Show");
    lua_setglobal(L, "UI");

    // Đăng ký bảng gg giả lập vào Lua
    lua_newtable(L);
    lua_pushcfunction(L, l_gg_set_values); lua_setfield(L, -2, "setValues");
    lua_pushcfunction(L, l_gg_toast);      lua_setfield(L, -2, "toast");
    lua_pushinteger(L, 4); lua_setfield(L, -2, "TYPE_DWORD");
    lua_setglobal(L, "gg");

    // Chạy script Lua của ngài
    int status = luaL_dostring(L, script.UTF8String);

    NSString *result;
    if (status != 0) {
        const char *err = lua_tostring(L, -1);
        result = [NSString stringWithFormat:@"[Lua] Lỗi: %s", err ? err : "unknown"];
        lua_pop(L, 1);
        lua_close(L);
        self.L = NULL;
    } else {
        result = @"[Lua] Tạo bảng menu nổi thành công!";
    }

    return result;
}

- (void)stop {
    [self closeFloatingMenu];
    if (self.L) {
        lua_close(self.L);
        self.L = NULL;
    }
}

@end
