#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include "substrate.h"

// Khai báo thư viện Lua (Sử dụng LuaJIT chuẩn đi kèm với các nền tảng jailbreak/theos)
extern "C" {
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
}

static lua_State *L = NULL;

// Hàm khởi tạo môi trường Lua và nạp file script
static void initLuaScript() {
    if (L != NULL) return;

    L = luaL_newstate();
    if (L == NULL) {
        NSLog(@"[AutoDanceHex] Không thể khởi tạo Lua state!");
        return;
    }

    luaL_openlibs(L);

    // Lấy đường dẫn tới file AutoDanceHex.lua trong app bundle hoặc thư mục tài nguyên tweak
    NSString *scriptPath = [[NSBundle mainBundle] pathForResource:@"AutoDanceHex" ofType:@"lua"];
    if (!scriptPath) {
        // Fallback đường dẫn tuyệt đối thường dùng trong rootless/rootful tweak
        scriptPath = @"/Library/MobileSubstrate/DynamicLibraries/AutoDanceHex.lua";
    }

    if ([[NSFileManager defaultManager] fileExistsAtPath:scriptPath]) {
        if (luaL_dofile(L, [scriptPath UTF8String]) != LUA_OK) {
            const char *err = lua_tostring(L, -1);
            NSLog(@"[AutoDanceHex] Lỗi chạy script Lua: %s", err);
            lua_pop(L, 1);
        } else {
            NSLog(@"[AutoDanceHex] Đã nạp script Lua thành công!");
        }
    } else {
        NSLog(@"[AutoDanceHex] Không tìm thấy file script Lua tại đường dẫn: %@", scriptPath);
    }
}

// Hook hàm vẽ ImGui của game/menu để gọi hàm OnDraw() từ Lua
static void (*orig_OnDraw)(void *self);
static void replacement_OnDraw(void *self) {
    orig_OnDraw(self);

    if (L != NULL) {
        lua_getglobal(L, "OnDraw");
        if (lua_isfunction(L, -1)) {
            if (lua_pcall(L, 0, 0, 0) != LUA_OK) {
                const char *err = lua_tostring(L, -1);
                // Tránh spam log liên tục nếu lỗi frame
                static NSTimeInterval lastLog = 0;
                NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
                if (now - lastLog > 5.0) {
                    NSLog(@"[AutoDanceHex] Lỗi khi gọi OnDraw Lua: %s", err);
                    lastLog = now;
                }
                lua_pop(L, 1);
            }
        } else {
            lua_pop(L, 1);
        }
    }
}

// Constructor chạy ngầm ngay khi tweak được tiêm vào ứng dụng
__attribute__((constructor)) static void init() {
    NSLog(@"[AutoDanceHex] Tweak đã được inject thành công!");
    
    // Khởi tạo Lua ở luồng chính sau khi game load xong
    dispatch_async(dispatch_get_main_queue(), ^{
        initLuaScript();
        
        // Ví dụ: Nếu menu game dùng một hàm render ImGui chuẩn nào đó, 
        // bạn có thể dùng MSHookFunction để bắt sự kiện vẽ và truyền về Lua.
        // (Thay thế địa chỉ hoặc tên hàm render thực tế của game nếu cần)
    });
}
