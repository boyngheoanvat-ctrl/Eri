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

// Giả lập các hàm của GameGuardian (gg.*)
static int lua_gg_setRanges(lua_State *L) {
    NSLog(@"[Lua gg mock] setRanges called");
    return 0;
}

static int lua_gg_searchNumber(lua_State *L) {
    NSLog(@"[Lua gg mock] searchNumber called");
    lua_newtable(L);
    return 1;
}

static int lua_gg_getResults(lua_State *L) {
    NSLog(@"[Lua gg mock] getResults called");
    lua_newtable(L);
    return 1;
}

static int lua_gg_editAll(lua_State *L) {
    NSLog(@"[Lua gg mock] editAll called");
    return 0;
}

static int lua_gg_toast(lua_State *L) {
    const char *msg = lua_tostring(L, 1);
    if (msg) {
        NSLog(@"[Lua gg toast]: %s", msg);
    }
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

    // Đăng ký print chuẩn
    lua_register(L, "print", lua_custom_print);
    
    // Đăng ký namespace il2cpp
    lua_newtable(L);
    lua_pushcfunction(L, lua_il2cpp_get_method_pointer);
    lua_setfield(L, -2, "get_method_pointer");
    lua_setglobal(L, "il2cpp");

    // ĐĂNG KÝ BẢNG GIẢ LẬP `gg` ĐẦY ĐỦ HẰNG SỐ CHỐNG LỖI BITWISE
    lua_newtable(L);
    
    // Hằng số vùng nhớ GameGuardian chuẩn
    lua_pushinteger(L, 1);   lua_setfield(L, -2, "REGION_ANONYMOUS");
    lua_pushinteger(L, 2);   lua_setfield(L, -2, "REGION_CODE_APP");
    lua_pushinteger(L, 4);   lua_setfield(L, -2, "REGION_CODE_SYS");
    lua_pushinteger(L, 8);   lua_setfield(L, -2, "REGION_STACK");
    lua_pushinteger(L, 16);  lua_setfield(L, -2, "REGION_ASHMEM");
    lua_pushinteger(L, 32);  lua_setfield(L, -2, "REGION_JAVA_HEAP");
    lua_pushinteger(L, 64);  lua_setfield(L, -2, "REGION_C_HEAP");
    lua_pushinteger(L, 128); lua_setfield(L, -2, "REGION_C_ALLOC");
    lua_pushinteger(L, 256); lua_setfield(L, -2, "REGION_C_DATA");
    lua_pushinteger(L, 512); lua_setfield(L, -2, "REGION_C_BSS");
    lua_pushinteger(L, 65536); lua_setfield(L, -2, "REGION_OTHER");
    lua_pushinteger(L, 32768); lua_setfield(L, -2, "REGION_BAD");
    lua_pushinteger(L, -1);  lua_setfield(L, -2, "REGION_ALL");

    // Kiểu dữ liệu
    lua_pushinteger(L, 1);   lua_setfield(L, -2, "TYPE_DWORD");
    lua_pushinteger(L, 4);   lua_setfield(L, -2, "TYPE_FLOAT");
    lua_pushinteger(L, 16);  lua_setfield(L, -2, "TYPE_DOUBLE");

    // Gắn các hàm giả lập gg
    lua_pushcfunction(L, lua_gg_setRanges); lua_setfield(L, -2, "setRanges");
    lua_pushcfunction(L, lua_gg_searchNumber); lua_setfield(L, -2, "searchNumber");
    lua_pushcfunction(L, lua_gg_getResults); lua_setfield(L, -2, "getResults");
    lua_pushcfunction(L, lua_gg_editAll); lua_setfield(L, -2, "editAll");
    lua_pushcfunction(L, lua_gg_toast); lua_setfield(L, -2, "toast");
    
    lua_setglobal(L, "gg");

    // Thực thi script
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
