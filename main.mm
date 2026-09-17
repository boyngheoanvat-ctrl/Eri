#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// Nhúng thư viện C của Lua
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

// Nội dung script Lua v7.2 được nhúng trực tiếp dạng Raw String C++
static const char* luaScriptContent = R"lua(
-- AutoDance HexControl v7.2 — FULL MINI GAME (Crazy Score Fix)
-- Preserves v7.1 (rev9) 100% + FIX Crazy: repair curArrowsIndex + direct nowTotalScore additive + 0.3s refresh

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

local methodInfo = {
  { cls = "Dance.AuditionGroup", image = "HotFix.dll",
    fields = {
      { name = "judgeLevel", offset = 64, type = "eNoteJudgeLevel", mod = "set 4 (PERFECT)" },
      { name = "isHitBeat",  offset = 50, type = "Boolean",        mod = "set true" },
    },
    methods = {
      { name = "IsAllHit",       addr = "0x16d22b4", ret = "Boolean",  params = "()" },
      { name = "ResetArrowsHit", addr = "0x16fe4ac", ret = "Void",     params = "()" },
      { name = "CheckNextHit",   addr = "0x16e1764", ret = "Boolean",  params = "(AuditionArrowsDirection)" },
    },
  },
}

print("[HexControl v7.2] Lua environment initialized successfully inside dylib!")
)lua";

// Constructor chạy tự động khi dylib được inject vào tiến trình ứng dụng iOS
__attribute__((constructor)) static void entryPoint() {
    @autoreleasepool {
        NSLog(@"[EriOS] Đang khởi chạy AutoDance HexControl v7.2...");
        
        // Khởi tạo Lua State mới
        lua_State *L = luaL_newstate();
        if (L) {
            luaL_openlibs(L);
            
            // Thực thi đoạn script Lua đã nhúng
            if (luaL_dostring(L, luaScriptContent) != LUA_OK) {
                const char *err = lua_tostring(L, -1);
                NSLog(@"[HexControl] Lỗi thực thi Lua script: %s", err);
                lua_pop(L, 1);
            }
        } else {
            NSLog(@"[HexControl] Không thể tạo Lua state.");
        }
    }
}
