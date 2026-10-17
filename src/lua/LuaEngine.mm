#import "LuaEngine.h"
#import <UIKit/UIKit.h>
#import <mach/mach.h>
#import <sys/mman.h>
#import <mach-o/dyld.h>

extern "C" {
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
// Khai báo hàm xoá cache lệnh CPU ARM64
void sys_icache_invalidate(void *start, size_t len);
}

static UIView *floatingMenuContainer = nil;
static UIButton *floatingLuaIcon = nil;
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

- (BOOL)isAvailable { return YES; }

// ==========================================
// HÀM PATCH BỘ NHỚ AN TOÀN TRÊN IOS (vm_protect)
// ==========================================
static BOOL PatchMemoryARM64(uintptr_t address, uint32_t value) {
    if (address < 0x100000000) return NO;
    
    vm_prot_t protection = VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY;
    kern_return_t kr = vm_protect(mach_task_self(), (vm_address_t)address, sizeof(uint32_t), FALSE, protection);
    
    if (kr == KERN_SUCCESS) {
        *(uint32_t *)address = value;
        // Phôi phục lại quyền Execute
        vm_protect(mach_task_self(), (vm_address_t)address, sizeof(uint32_t), FALSE, VM_PROT_READ | VM_PROT_EXECUTE);
        // Xóa instruction cache của CPU ARM64
        sys_icache_invalidate((void *)address, sizeof(uint32_t));
        return YES;
    }
    return NO;
}

// ==========================================
// LUA BRIDGE IMPLEMENTATION (UI & GG)
// ==========================================

static int l_create_window(lua_State *L) {
    const char *title = lua_tostring(L, 1);
    double width = lua_tonumber(L, 2);
    double height = lua_tonumber(L, 3);
    
    if (width <= 0) width = 240;
    if (height <= 0) height = 310;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (floatingMenuContainer) {
            [floatingMenuContainer removeFromSuperview];
            floatingMenuContainer = nil;
        }
        if (floatingLuaIcon) {
            [floatingLuaIcon removeFromSuperview];
            floatingLuaIcon = nil;
        }

        UIWindow *keyWindow = nil;
        for (UIWindow *win in [UIApplication sharedApplication].windows) {
            if (win.isKeyWindow) { keyWindow = win; break; }
        }
        if (!keyWindow) keyWindow = [UIApplication sharedApplication].delegate.window;
        if (!keyWindow) return;

        CGFloat screenW = keyWindow.bounds.size.width;

        // 1. Tạo Container Menu Nổi chính
        floatingMenuContainer = [[UIView alloc] initWithFrame:CGRectMake((screenW - width) / 2, 80, width, height)];
        floatingMenuContainer.backgroundColor = [UIColor colorWithRed:0.10 green:0.12 blue:0.16 alpha:0.95];
        floatingMenuContainer.layer.cornerRadius = 12;
        floatingMenuContainer.layer.borderWidth = 1.2;
        floatingMenuContainer.layer.borderColor = [UIColor colorWithRed:0.0 green:0.85 blue:0.55 alpha:1.0].CGColor;
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:[LuaEngine shared] action:@selector(handlePanMenu:)];
        [floatingMenuContainer addGestureRecognizer:pan];

        // Tiêu đề
        UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, width - 44, 28)];
        titleLbl.text = title ? [NSString stringWithUTF8String:title] : @"LUA MOD MENU";
        titleLbl.textColor = [UIColor colorWithRed:0.0 green:0.85 blue:0.55 alpha:1.0];
        titleLbl.font = [UIFont boldSystemFontOfSize:13];
        [floatingMenuContainer addSubview:titleLbl];

        // Nút thu nhỏ Menu (✕)
        UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        closeBtn.frame = CGRectMake(width - 32, 8, 24, 24);
        [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
        [closeBtn setTitleColor:[UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0] forState:UIControlStateNormal];
        [closeBtn addTarget:[LuaEngine shared] action:@selector(minimizeMenu) forControlEvents:UIControlEventTouchUpInside];
        [floatingMenuContainer addSubview:closeBtn];

        // ScrollView chứa các nút gạt
        UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(8, 40, width - 16, height - 48)];
        scrollView.tag = 8888;
        scrollView.contentSize = CGSizeMake(width - 16, 400);
        [floatingMenuContainer addSubview:scrollView];

        // 2. Tạo Icon Tròn Nổi Mở Lại Menu (Lua Floating Icon)
        floatingLuaIcon = [UIButton buttonWithType:UIButtonTypeCustom];
        floatingLuaIcon.frame = CGRectMake(15, 120, 44, 44);
        floatingLuaIcon.backgroundColor = [UIColor colorWithRed:0.0 green:0.85 blue:0.55 alpha:0.9];
        floatingLuaIcon.layer.cornerRadius = 22;
        floatingLuaIcon.layer.borderWidth = 1.5;
        floatingLuaIcon.layer.borderColor = [UIColor whiteColor].CGColor;
        [floatingLuaIcon setTitle:@"LUA" forState:UIControlStateNormal];
        [floatingLuaIcon setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        floatingLuaIcon.titleLabel.font = [UIFont boldSystemFontOfSize:11];
        
        UIPanGestureRecognizer *iconPan = [[UIPanGestureRecognizer alloc] initWithTarget:[LuaEngine shared] action:@selector(handlePanIcon:)];
        [floatingLuaIcon addGestureRecognizer:iconPan];
        [floatingLuaIcon addTarget:[LuaEngine shared] action:@selector(expandMenu) forControlEvents:UIControlEventTouchUpInside];

        [keyWindow addSubview:floatingMenuContainer];
        [keyWindow addSubview:floatingLuaIcon];
        
        floatingLuaIcon.hidden = YES; // Mặc định hiện Menu, ẩn Icon
    });

    return 0;
}

static int l_add_label(lua_State *L) {
    const char *text = lua_tostring(L, 1);
    if (!text) return 0;
    NSString *labelStr = [NSString stringWithUTF8String:text];

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!floatingMenuContainer) return;
        UIScrollView *scrollView = [floatingMenuContainer viewWithTag:8888];
        if (!scrollView) return;

        CGFloat currentY = 0;
        for (UIView *sub in scrollView.subviews) {
            currentY = MAX(currentY, CGRectGetMaxY(sub.frame) + 6);
        }

        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(4, currentY, scrollView.bounds.size.width - 8, 22)];
        lbl.text = labelStr;
        lbl.textColor = [UIColor whiteColor];
        lbl.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        [scrollView addSubview:lbl];
        scrollView.contentSize = CGSizeMake(scrollView.bounds.size.width, currentY + 28);
    });
    return 0;
}

static int l_add_toggle(lua_State *L) {
    const char *name = lua_tostring(L, 1);
    if (!name) return 0;
    NSString *toggleName = [NSString stringWithUTF8String:name];

    if (!luaCallbacks) luaCallbacks = [NSMutableDictionary dictionary];
    lua_pushvalue(L, 2);
    int ref = luaL_ref(L, LUA_REGISTRYINDEX);
    [luaCallbacks setObject:@(ref) forKey:toggleName];

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!floatingMenuContainer) return;
        UIScrollView *scrollView = [floatingMenuContainer viewWithTag:8888];
        if (!scrollView) return;

        CGFloat currentY = 0;
        for (UIView *sub in scrollView.subviews) {
            currentY = MAX(currentY, CGRectGetMaxY(sub.frame) + 6);
        }

        UIView *row = [[UIView alloc] initWithFrame:CGRectMake(4, currentY, scrollView.bounds.size.width - 8, 34)];
        
        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(4, 2, row.bounds.size.width - 56, 30)];
        lbl.text = toggleName;
        lbl.textColor = [UIColor colorWithWhite:0.9 alpha:1.0];
        lbl.font = [UIFont systemFontOfSize:11];
        [row addSubview:lbl];

        UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(row.bounds.size.width - 50, 2, 45, 30)];
        sw.transform = CGAffineTransformMakeScale(0.7, 0.7);
        sw.onTintColor = [UIColor colorWithRed:0.0 green:0.85 blue:0.55 alpha:1.0];
        sw.accessibilityIdentifier = toggleName;
        [sw addTarget:[LuaEngine shared] action:@selector(didToggleSwitch:) forControlEvents:UIControlEventValueChanged];
        [row addSubview:sw];

        [scrollView addSubview:row];
        scrollView.contentSize = CGSizeMake(scrollView.bounds.size.width, currentY + 40);
    });
    return 0;
}

static int l_show_window(lua_State *L) { return 0; }

// Patch Memory qua GG Bridge
static int l_gg_set_values(lua_State *L) {
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

                if (addr > 0) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        BOOL ok = PatchMemoryARM64((uintptr_t)addr, val);
                        if (ok) {
                            NSLog(@"[LuaPatch Thành Công] Address: 0x%llX -> Value: 0x%X", addr, val);
                        } else {
                            NSLog(@"[LuaPatch Lỗi] Lỗi vm_protect tại 0x%llX", addr);
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
    if (msg) NSLog(@"[GG Toast] %s", msg);
    return 0;
}

// ==========================================
// THAO TÁC GIAO DIỆN NỔI
// ==========================================

- (void)handlePanMenu:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:floatingMenuContainer.superview];
    floatingMenuContainer.center = CGPointMake(floatingMenuContainer.center.x + translation.x, floatingMenuContainer.center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:floatingMenuContainer.superview];
}

- (void)handlePanIcon:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:floatingLuaIcon.superview];
    floatingLuaIcon.center = CGPointMake(floatingLuaIcon.center.x + translation.x, floatingLuaIcon.center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:floatingLuaIcon.superview];
}

- (void)minimizeMenu {
    floatingMenuContainer.hidden = YES;
    floatingLuaIcon.hidden = NO;
}

- (void)expandMenu {
    floatingMenuContainer.hidden = NO;
    floatingLuaIcon.hidden = YES;
}

- (void)didToggleSwitch:(UISwitch *)sender {
    NSString *key = sender.accessibilityIdentifier;
    if (!key || !luaCallbacks || !self.L) return;
    NSNumber *refNum = [luaCallbacks objectForKey:key];
    if (!refNum) return;

    lua_State *L = self.L;
    lua_rawgeti(L, LUA_REGISTRYINDEX, refNum.intValue);
    lua_pushboolean(L, sender.isOn);
    if (lua_pcall(L, 1, 0, 0) != 0) {
        const char *err = lua_tostring(L, -1);
        NSLog(@"[Lua Callback Lỗi]: %s", err ? err : "unknown");
        lua_pop(L, 1);
    }
}

- (NSString *)runScript:(NSString *)script {
    if (!script) return @"[Lua] Script rỗng";

    lua_State *L = luaL_newstate();
    if (!L) return @"[Lua] Không tạo được lua_State";

    luaL_openlibs(L);
    self.L = L;

    lua_newtable(L);
    lua_pushcfunction(L, l_create_window); lua_setfield(L, -2, "CreateWindow");
    lua_pushcfunction(L, l_add_label);     lua_setfield(L, -2, "AddLabel");
    lua_pushcfunction(L, l_add_toggle);    lua_setfield(L, -2, "AddToggle");
    lua_pushcfunction(L, l_show_window);   lua_setfield(L, -2, "Show");
    lua_setglobal(L, "UI");

    lua_newtable(L);
    lua_pushcfunction(L, l_gg_set_values); lua_setfield(L, -2, "setValues");
    lua_pushcfunction(L, l_gg_toast);      lua_setfield(L, -2, "toast");
    lua_pushinteger(L, 4); lua_setfield(L, -2, "TYPE_DWORD");
    lua_setglobal(L, "gg");

    int status = luaL_dostring(L, script.UTF8String);
    NSString *result;
    if (status != 0) {
        const char *err = lua_tostring(L, -1);
        result = [NSString stringWithFormat:@"[Lua] Lỗi: %s", err ? err : "unknown"];
        lua_pop(L, 1);
        lua_close(L);
        self.L = NULL;
    } else {
        result = @"[Lua] Đã nạp Menu Lua thành công!";
    }
    return result;
}

- (void)stop {
    if (floatingMenuContainer) [floatingMenuContainer removeFromSuperview];
    if (floatingLuaIcon) [floatingLuaIcon removeFromSuperview];
    if (self.L) { lua_close(self.L); self.L = NULL; }
}

@end
