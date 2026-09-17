#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include "substrate.h"

extern "C" {
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
}

static lua_State *L = NULL;
static BOOL isLuaLoaded = NO;
static dispatch_source_t modLoopTimer = nil;

// Script Lua chuẩn v7.2 đã được tinh chỉnh lại cơ chế bắt lỗi class an toàn tuyệt đối
static const char *kLuaScriptContent = R"lua(
local state = {
  activeOn = false,
  taikoOn = false,
  miniOn = false,
  status = "Đã kích hoạt Lua Engine chuẩn v7.2",
  PERFECT = 4,
  stats = { modified = 0, taiko = 0, mini = 0, crazy = 0 },
  lastCheck = 0,
  lastTaikoCheck = 0,
  lastMiniCheck = 0,
}

local originals = {}

local function safeLog(msg)
  pcall(function() print("[Lua Debug] " .. tostring(msg)) end)
end

local function restoreOriginal()
  local restored = 0
  for _, rec in pairs(originals) do
    local o = rec.obj
    if o then
      pcall(function()
        for f, v in pairs(rec.vals) do
          if v ~= nil then o[f] = v end
        end
      end)
      restored = restored + 1
    end
  end
  originals = {}
  return restored
end

-- 1. Auto Audition Hook an toàn
local function applyAuditionMod()
  local count = 0
  local success, err = pcall(function()
    if not Class or not Class.fromName then return end
    local cls = Class.fromName("Dance.AuditionGroup")
    if cls and cls.findObjects then
      local objs = cls:findObjects()
      if objs and objs.count and objs.count > 0 then
        for i = 1, objs.count do
          local g = objs[i]
          if g then
            local gkey = "group:" .. tostring(g)
            if not originals[gkey] then
              originals[gkey] = { obj = g, vals = { judgeLevel = g.judgeLevel, isHitBeat = g.isHitBeat } }
            end
            g.judgeLevel = state.PERFECT
            g.isHitBeat = true
            count = count + 1
          end
        end
      end
    end
  end)
  if not success then safeLog("AuditionMod error: " .. tostring(err)) end
  return count
end

-- 2. Auto Taiko Hook an toàn
local function applyTaikoMod()
  local count = 0
  local success, err = pcall(function()
    if not Class or not Class.fromName then return end
    local cls = Class.fromName("UI_TaikoNoteBase")
    if cls and cls.findObjects then
      local notes = cls:findObjects()
      if notes and notes.count and notes.count > 0 then
        for i = 1, notes.count do
          local n = notes[i]
          if n then
            local nkey = "taiko:" .. tostring(n)
            if not originals[nkey] then
              originals[nkey] = { obj = n, vals = { JudgeLevel = n.JudgeLevel, isJudgeLevel = n.isJudgeLevel, IsHit = n.IsHit } }
            end
            n.JudgeLevel = state.PERFECT
            n.isJudgeLevel = true
            pcall(function() n.IsHit = true end)
            count = count + 1
          end
        end
      end
    end
  end)
  if not success then safeLog("TaikoMod error: " .. tostring(err)) end
  return count
end

-- 3. Full Mini Game Hook an toàn
local MINI_CLASSES = {
  "Modules.UI.UI_DanceBallSingleNote",
  "Modules.UI.UI_DanceBallLongNote",
  "Modules.UI.UI_Note_VOS",
  "DynamicGroup",
  "DynamicOneBeatKeys"
}

local function applyMiniMod()
  local total = 0
  local success, err = pcall(function()
    if not Class or not Class.fromName then return end
    for _, className in ipairs(MINI_CLASSES) do
      local cls = Class.fromName(className)
      if cls and cls.findObjects then
        local objs = cls:findObjects()
        if objs and objs.count then
          for i = 1, objs.count do
            local o = objs[i]
            if o then
              local mkey = "mini:" .. tostring(o)
              if not originals[mkey] then
                originals[mkey] = { obj = o, vals = { judgeLevel = o.judgeLevel } }
              end
              pcall(function() o.judgeLevel = 4 end)
              pcall(function() o.isJudge = true end)
              pcall(function() o.JudgeRatio = 100 end)
              total = total + 1
            end
          end
        end
      end
    end
  end)
  if not success then safeLog("MiniMod error: " .. tostring(err)) end
  return total
end

-- Hàm vòng lặp gọi từ Objective-C định kỳ
function OnDraw()
  local currentTime = os.time()
  if state.activeOn and (currentTime - state.lastCheck >= 1) then
    state.lastCheck = currentTime
    state.stats.modified = applyAuditionMod()
  end
  if state.taikoOn and (currentTime - state.lastTaikoCheck >= 1) then
    state.lastTaikoCheck = currentTime
    state.stats.taiko = applyTaikoMod()
  end
  if state.miniOn and (currentTime - state.lastMiniCheck >= 1) then
    state.lastMiniCheck = currentTime
    state.stats.mini = applyMiniMod()
  end
end

function OnStop()
  state.activeOn = false
  state.taikoOn = false
  state.miniOn = false
  restoreOriginal()
end
)lua";

// Khởi tạo Lua State và nạp script
static void initLuaScriptEmbedded() {
    if (isLuaLoaded) return;

    L = luaL_newstate();
    if (!L) return;
    luaL_openlibs(L);

    if (luaL_loadstring(L, kLuaScriptContent) == LUA_OK) {
        if (lua_pcall(L, 0, LUA_MULTRET, 0) == LUA_OK) {
            isLuaLoaded = YES;
            NSLog(@"[AutoDanceHex v7.2] Khởi tạo Lua Engine thành công!");
        } else {
            NSLog(@"[AutoDanceHex v7.2] Lỗi chạy Lua Script: %s", lua_tostring(L, -1));
            lua_pop(L, 1);
        }
    } else {
        NSLog(@"[AutoDanceHex v7.2] Lỗi biên dịch chuỗi Lua: %s", lua_tostring(L, -1));
        lua_pop(L, 1);
    }
}

// Gọi hàm OnDraw() từ Lua mỗi chu kỳ
static void executeLuaModLoop() {
    if (!isLuaLoaded || !L) return;
    lua_getglobal(L, "OnDraw");
    if (lua_isfunction(L, -1)) {
        if (lua_pcall(L, 0, 0, 0) != LUA_OK) {
            NSLog(@"[AutoDanceHex v7.2] Lỗi trong OnDraw: %s", lua_tostring(L, -1));
            lua_pop(L, 1);
        }
    } else {
        lua_pop(L, 1);
    }
}

static void startModLoop() {
    if (modLoopTimer) return;
    dispatch_queue_t queue = dispatch_get_main_queue();
    modLoopTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    // Chạy tần suất 0.3s để bắt nhịp game cực mượt mà
    dispatch_source_set_timer(modLoopTimer, dispatch_time(DISPATCH_TIME_NOW, 0), 0.3 * NSEC_PER_SEC, 0.05 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(modLoopTimer, ^{
        executeLuaModLoop();
    });
    dispatch_resume(modLoopTimer);
}

// Lấy UIWindow hiện tại của game
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

// Giao diện Menu quản lý qua UIKit Alert (Tương thích 100% với môi trường gọi lệnh)
@interface AutoDanceMenuController : NSObject
+ (void)showMenu;
+ (void)showToast:(NSString *)msg;
@end

@implementation AutoDanceMenuController

+ (void)showMenu {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = getCurrentWindow();
        if (!window) return;
        
        UIViewController *rootVC = window.rootViewController;
        while (rootVC.presentedViewController) { rootVC = rootVC.presentedViewController; }

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

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"AutoDance Hex v7.2 (Lua Engine)"
                                                                     message:@"Chọn tính năng mod:"
                                                              preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:[UIAlertAction actionWithTitle:activeOn ? @"[ ✅ ] Auto Arrow (Audition): BẬT" : @"[ ❌ ] Auto Arrow (Audition): TẮT" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            BOOL newState = !activeOn;
            if (L) {
                lua_getglobal(L, "state");
                if (lua_istable(L, -1)) { lua_pushboolean(L, newState); lua_setfield(L, -2, "activeOn"); }
                lua_pop(L, 1);
            }
            [self showToast:newState ? @"Đã Bật Auto Arrow" : @"Đã Tắt Auto Arrow"];
        }]];

        [alert addAction:[UIAlertAction actionWithTitle:taikoOn ? @"[ ✅ ] Auto Taiko Mode: BẬT" : @"[ ❌ ] Auto Taiko Mode: TẮT" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            BOOL newState = !taikoOn;
            if (L) {
                lua_getglobal(L, "state");
                if (lua_istable(L, -1)) { lua_pushboolean(L, newState); lua_setfield(L, -2, "taikoOn"); }
                lua_pop(L, 1);
            }
            [self showToast:newState ? @"Đã Bật Taiko Mode" : @"Đã Tắt Taiko Mode"];
        }]];

        [alert addAction:[UIAlertAction actionWithTitle:miniOn ? @"[ ✅ ] FULL MINI GAME: BẬT" : @"[ ❌ ] FULL MINI GAME: TẮT" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            BOOL newState = !miniOn;
            if (L) {
                lua_getglobal(L, "state");
                if (lua_istable(L, -1)) { lua_pushboolean(L, newState); lua_setfield(L, -2, "miniOn"); }
                lua_pop(L, 1);
            }
            [self showToast:newState ? @"Đã Bật Full Mini Game" : @"Đã Tắt Full Mini Game"];
        }]];

        [alert addAction:[UIAlertAction actionWithTitle:@"Đóng Menu" style:UIAlertActionStyleCancel handler:nil]];
        [rootVC presentViewController:alert animated:YES completion:nil];
    });
}

+ (void)showToast:(NSString *)msg {
    UIWindow *window = getCurrentWindow();
    if (!window) return;
    UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake(40, window.frame.size.height - 150, window.frame.size.width - 80, 42)];
    toast.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.85];
    toast.textColor = [UIColor cyanColor];
    toast.textAlignment = NSTextAlignmentCenter;
    toast.font = [UIFont boldSystemFontOfSize:14];
    toast.text = msg;
    toast.layer.cornerRadius = 10;
    toast.clipsToBounds = YES;
    [window addSubview:toast];
    [UIView animateWithDuration:2.2 animations:^{ toast.alpha = 0.0; } completion:^(BOOL finished) { [toast removeFromSuperview]; }];
}

@end

// Trình lắng nghe chạm 2 ngón tay mở Menu
@interface AutoDanceGestureLoader : NSObject
@end

@implementation AutoDanceGestureLoader
+ (void)load {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        initLuaScriptEmbedded();
        startModLoop();
        UIWindow *window = getCurrentWindow();
        if (window) {
            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
            tap.numberOfTouchesRequired = 2;
            [window addGestureRecognizer:tap];
            NSLog(@"[AutoDanceHex v7.2] Đã kích hoạt thành công gesture 2 ngón tay!");
        }
    });
}

+ (void)handleTap:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        [AutoDanceMenuController showMenu];
    }
}
@end
