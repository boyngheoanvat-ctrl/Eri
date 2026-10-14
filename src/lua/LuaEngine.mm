#import "LuaEngine.h"
#import <dlfcn.h>

// Include Lua headers (đã có sẵn trong dylib)
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

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
    return YES;  // Lua đã được nhúng sẵn
}

- (NSString *)runScript:(NSString *)script {
    if (!script) return @"[Lua] Script rỗng";

    // Tạo state mới cho mỗi lần chạy
    lua_State *L = luaL_newstate();
    if (!L) return @"[Lua] Khong tao duoc lua_State";

    // Load thư viện chuẩn
    luaL_openlibs(L);

    self.L = L;

    // Chạy script
    int status = luaL_dostring(L, script.UTF8String);

    NSString *result;
    if (status != 0) {
        const char *err = lua_tostring(L, -1);
        result = [NSString stringWithFormat:@"[Lua] Loi: %s", err ? err : "unknown"];
        lua_pop(L, 1);
    } else {
        result = @"[Lua] Script chay thanh cong";
    }

    lua_close(L);
    self.L = NULL;

    return result;
}

- (void)stop {
    if (self.L) {
        lua_close(self.L);
        self.L = NULL;
    }
}

@end
