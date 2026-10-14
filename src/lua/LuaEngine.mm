#import "LuaEngine.h"
#import <dlfcn.h>

typedef struct lua_State lua_State;

@interface LuaEngine ()
@property (nonatomic, assign) void *luaHandle;
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
    void *h = dlopen("liblua.dylib", RTLD_NOW);
    if (!h) h = dlopen("liblua.5.3.dylib", RTLD_NOW);
    if (!h) h = dlopen("liblua.5.4.dylib", RTLD_NOW);
    if (!h) h = dlopen("liblua.5.1.dylib", RTLD_NOW);
    if (!h) return NO;
    self.luaHandle = h;
    return dlsym(h, "luaL_newstate") != NULL;
}

- (NSString *)runScript:(NSString *)script {
    if (!self.luaHandle) {
        if (![self isAvailable]) {
            return @"[Lua] Khong tim thay liblua trong runtime.\nCan them liblua.a vao project.";
        }
    }

    typedef lua_State *(*newstate_t)(void);
    typedef int (*dostring_t)(lua_State *, const char *);
    typedef const char *(*tolstring_t)(lua_State *, int);

    newstate_t luaL_newstate = (newstate_t)dlsym(self.luaHandle, "luaL_newstate");
    dostring_t luaL_dostring = (dostring_t)dlsym(self.luaHandle, "luaL_dostring");
    tolstring_t lua_tolstring = (tolstring_t)dlsym(self.luaHandle, "lua_tolstring");

    if (!luaL_newstate || !luaL_dostring) {
        return @"[Lua] Khong tim thay luaL_newstate/luaL_dostring";
    }

    lua_State *L = luaL_newstate();
    if (!L) return @"[Lua] Khong tao duoc lua_State";

    self.L = L;

    int status = luaL_dostring(L, script.UTF8String);
    if (status != 0) {
        const char *err = lua_tolstring ? lua_tolstring(L, -1, NULL) : "unknown error";
        return [NSString stringWithFormat:@"[Lua] Loi: %s", err ?: "unknown"];
    }

    return @"[Lua] Script chay thanh cong";
}

- (void)stop {
    self.L = NULL;
}

@end
