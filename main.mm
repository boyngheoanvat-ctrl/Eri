#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

extern "C" {
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
}

// Lưu trữ biến Global Lua State để gọi hàm OnDraw từ bên ngoài
static lua_State *globalL = NULL;

static const char* luaScriptContent = R"lua(
-- AutoDance HexControl v7.2 — FULL MINI GAME (Crazy Score Fix)
local state = {
  activeOn = false,
  taikoOn = false,
  miniOn = false,
  status = "Sẵn sàng. Bật toggle để chạy tự động qua các trận.",
  PERFECT = 4,
  stats = { modified = 0, taiko = 0, mini = 0, crazy = 0 },
  lastCheck = 0,
  lastCount = 0,
  lastTaikoCheck = 0,
  lastTaikoCount = 0,
  lastMiniCheck = 0,
  lastMiniCount = 0,
  lastCrazyCheck = 0,
  crazyScore = 0,
  scoredGroups = {},
}

local originals = {}

-- Hàm OnDraw được gọi mỗi frame nếu có cơ chế hook
function OnDraw()
    -- Nếu môi trường hỗ trợ ImGui, menu sẽ vẽ ở đây
end

print("[HexControl v7.2] Lua environment initialized successfully inside dylib!")
)lua";

// Hàm gọi định kỳ để kích hoạt OnDraw trong Lua
void triggerLuaDraw() {
    if (!globalL) return;
    
    // Gọi hàm OnDraw từ Lua script
    lua_getglobal(globalL, "OnDraw");
    if (lua_isfunction(globalL, -1)) {
        if (lua_pcall(globalL, 0, 0, 0) != LUA_OK) {
            const char *err = lua_tostring(globalL, -1);
            NSLog(@"[HexControl] Lỗi gọi OnDraw: %s", err);
            lua_pop(globalL, 1);
        }
    } else {
        lua_pop(globalL, 1);
    }
}

__attribute__((constructor)) static void entryPoint() {
    @autoreleasepool {
        NSLog(@"[EriOS] Đang khởi chạy AutoDance HexControl v7.2...");
        
        globalL = luaL_newstate();
        if (globalL) {
            luaL_openlibs(globalL);
            
            if (luaL_dostring(globalL, luaScriptContent) != LUA_OK) {
                const char *err = lua_tostring(globalL, -1);
                NSLog(@"[HexControl] Lỗi thực thi Lua script: %s", err);
                lua_pop(globalL, 1);
            } else {
                // Tạo một Timer chạy liên tục mỗi 0.03 giây (khoảng 30fps) để gọi triggerLuaDraw vẽ menu
                dispatch_async(dispatch_get_main_queue(), ^{
                    [NSTimer scheduledTimerWithTimeInterval:0.03 repeats:YES block:^(NSTimer * _Nonnull timer) {
                        triggerLuaDraw();
                    }];
                });
            }
        } else {
            NSLog(@"[HexControl] Không thể tạo Lua state.");
        }
    }
}
