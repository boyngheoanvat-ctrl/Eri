#import "LuaEngine.h"
#import <dlfcn.h>

extern "C" {
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
}

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

static int lua_custom_print(lua_State *L) {
    int nargs = lua_gettop(L);
    NSMutableString *logOutput = [NSMutableString string];
    for (int i = 1; i <= nargs; i++) {
        const char *s = lua_tostring(L, i);
        if (s) {
            [logOutput appendFormat:@"%s ", s];
        }
    }
    NSLog(@"[Lua Print]: %@", logOutput);
    return 0;
}

static int lua_il2cpp_get_method_pointer(lua_State *L) {
    const char *clsName = lua_tostring(L, 1);
    const char *mName = lua_tostring(L, 2);
    uint64_t ptr = 0; 
    lua_pushinteger(L, (lua_Integer)ptr);
    return 1;
}

- (NSString *)runScript:(NSString *)script {
    if (!script) return @"[Lua] Script rỗng";

    lua_State *L = luaL_newstate();
    if (!L) return @"[Lua] Không tạo được lua_State";

    luaL_openlibs(L);
    self.L = L;

    lua_register(L, "print", lua_custom_print);
    
    lua_newtable(L);
    lua_pushcfunction(L, lua_il2cpp_get_method_pointer);
    lua_setfield(L, -2, "get_method_pointer");
    lua_setglobal(L, "il2cpp");

    int status = luaL_dostring(L, script.UTF8String);

    NSString *result;
    if (status != 0) {
        const char *err = lua_tostring(L, -1);
        result = [NSString stringWithFormat:@"[Lua] Lỗi: %s", err ? err : "unknown"];
        lua_pop(L, 1);
    } else {
        result = @"[Lua] Script chạy thành công";
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
