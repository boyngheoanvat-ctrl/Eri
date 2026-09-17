#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// Nếu bạn sử dụng C API của Lua (LuaJIT / Lua 5.1)
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

// Nội dung script Lua v7.2 của bạn được đưa vào chuỗi C++ / C-string
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

print("[HexControl] Lua script loaded successfully!")
)lua";

// Hàm khởi chạy chính khi dylib được inject vào tiến trình ứng dụng
__attribute__((constructor)) static void entryPoint() {
    @autoreleasepool {
        NSLog(@"[EriOS] AutoDance HexControl v7.2 dylib injected successfully!");
        
        // Khởi tạo Lua State
        lua_State *L = luaL_newstate();
        if (L) {
            luaL_openlibs(L);
            
            // Thực thi đoạn script Lua
            if (luaL_dostring(L, luaScriptContent) != LUA_OK) {
                const char *err = lua_tostring(L, -1);
                NSLog(@"[HexControl] Lỗi thực thi Lua script: %s", err);
                lua_pop(L, 1);
            }
            
            // Lưu ý: State L có thể được giữ lại để gọi các hàm OnDraw, OnStop từ hook ImGui của game nếu cần.
        } else {
            NSLog(@"[HexControl] Không thể khởi tạo Lua state.");
        }
    }
}
