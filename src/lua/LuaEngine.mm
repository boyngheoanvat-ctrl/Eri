#import "LuaEngine.h"
#import <dlfcn.h>
#import <unistd.h>

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

#pragma mark - GameGuardian (gg.*) Mock Implementations

static int lua_gg_setRanges(lua_State *L) {
    return 0;
}

static int lua_gg_searchNumber(lua_State *L) {
    lua_newtable(L); // Trả về bảng kết quả giả lập rỗng
    return 1;
}

static int lua_gg_refineNumber(lua_State *L) {
    return 0;
}

static int lua_gg_getResults(lua_State *L) {
    lua_newtable(L);
    return 1;
}

static int lua_gg_editAll(lua_State *L) {
    return 0;
}

static int lua_gg_clearResults(lua_State *L) {
    return 0;
}

static int lua_gg_removeResults(lua_State *L) {
    return 0;
}

static int lua_gg_getResultsCount(lua_State *L) {
    lua_pushinteger(L, 0);
    return 1;
}

static int lua_gg_toast(lua_State *L) {
    const char *msg = lua_tostring(L, 1);
    if (msg) {
        NSLog(@"[Lua gg toast]: %s", msg);
    }
    return 0;
}

static int lua_gg_alert(lua_State *L) {
    // gg.alert(text, positive, negative, neutral) -> trả về nút được chọn (1, 2, 3)
    lua_pushinteger(L, 1);
    return 1;
}

static int lua_gg_prompt(lua_State *L) {
    // gg.prompt trả về bảng giá trị nhập vào, giả lập trả về bảng rỗng hoặc giữ nguyên mặc định
    if (lua_istable(L, 1)) {
        lua_pushvalue(L, 1); // Trả về lại bảng cấu hình prompt ban đầu làm giá trị nhập
        return 1;
    }
    lua_newtable(L);
    return 1;
}

static int lua_gg_multiChoice(lua_State *L) {
    // gg.multiChoice trả về một bảng các lựa chọn được chọn (true/false)
    if (lua_istable(L, 1)) {
        lua_len(L, 1);
        int count = (int)lua_tointeger(L, -1);
        lua_pop(L, 1);
        
        lua_newtable(L);
        for (int i = 1; i <= count; i++) {
            lua_pushboolean(L, i == 1 ? 1 : 0); // Mặc định chọn mục đầu tiên (vd: Menu Radar)
            lua_rawseti(L, -2, i);
        }
        return 1;
    }
    lua_newtable(L);
    return 1;
}

static int lua_gg_sleep(lua_State *L) {
    int ms = (int)lua_tonumber(L, 1);
    usleep(ms > 0 ? ms * 1000 : 1000);
    return 0;
}

static int lua_gg_isVisible(lua_State *L) {
    lua_pushboolean(L, 1); // Luôn trả về true để script menu tiếp tục chạy
    return 1;
}

static int lua_gg_copyText(lua_State *L) {
    return 0;
}

static int lua_gg_getTargetPackage(lua_State *L) {
    lua_pushstring(L, "com.tencent.ig");
    return 1;
}

static int lua_gg_getTargetInfo(lua_State *L) {
    lua_newtable(L);
    lua_pushstring(L, "1.0.0"); lua_setfield(L, -2, "versionName");
    lua_pushinteger(L, 100); lua_setfield(L, -2, "versionCode");
    lua_pushstring(L, "com.tencent.ig"); lua_setfield(L, -2, "packageName");
    return 1;
}

static int lua_gg_setSpeed(lua_State *L) {
    return 0;
}

static int lua_gg_getSpeed(lua_State *L) {
    lua_pushnumber(L, 1.0);
    return 1;
}

static int lua_il2cpp_get_method_pointer(lua_State *L) {
    const char *clsName = lua_tostring(L, 1);
    const char *mName = lua_tostring(L, 2);
    uint64_t ptr = 0; 
    lua_pushinteger(L, (lua_Integer)ptr);
    return 1;
}

#pragma mark - Script Execution

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

    // ==========================================
    // ĐĂNG KÝ TRỌN BỘ BẢNG GIẢ LẬP `gg` VÀ HẰNG SỐ
    // ==========================================
    lua_newtable(L);
    
    // Hằng số vùng nhớ (Memory Regions)
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

    // Kiểu dữ liệu (Data Types)
    lua_pushinteger(L, 1);   lua_setfield(L, -2, "TYPE_DWORD");
    lua_pushinteger(L, 2);   lua_setfield(L, -2, "TYPE_WORD");
    lua_pushinteger(L, 4);   lua_setfield(L, -2, "TYPE_FLOAT");
    lua_pushinteger(L, 8);   lua_setfield(L, -2, "TYPE_DOUBLE");
    lua_pushinteger(L, 16);  lua_setfield(L, -2, "TYPE_QWORD");
    lua_pushinteger(L, 32);  lua_setfield(L, -2, "TYPE_BYTE");
    lua_pushinteger(L, 64);  lua_setfield(L, -2, "TYPE_XOR");
    lua_pushinteger(L, 128); lua_setfield(L, -2, "TYPE_AUTO");

    // Kiểu hộp thoại (Dialog Choices)
    lua_pushinteger(L, 1);   lua_setfield(L, -2, "CHOICE_RADIO");
    lua_pushinteger(L, 2);   lua_setfield(L, -2, "CHOICE_CHECKBOX");

    // Đăng ký toàn bộ hàm gg cơ bản và nâng cao
    lua_pushcfunction(L, lua_gg_setRanges);       lua_setfield(L, -2, "setRanges");
    lua_pushcfunction(L, lua_gg_searchNumber);    lua_setfield(L, -2, "searchNumber");
    lua_pushcfunction(L, lua_gg_refineNumber);    lua_setfield(L, -2, "refineNumber");
    lua_pushcfunction(L, lua_gg_getResults);      lua_setfield(L, -2, "getResults");
    lua_pushcfunction(L, lua_gg_editAll);         lua_setfield(L, -2, "editAll");
    lua_pushcfunction(L, lua_gg_clearResults);    lua_setfield(L, -2, "clearResults");
    lua_pushcfunction(L, lua_gg_removeResults);   lua_setfield(L, -2, "removeResults");
    lua_pushcfunction(L, lua_gg_getResultsCount); lua_setfield(L, -2, "getResultsCount");
    lua_pushcfunction(L, lua_gg_toast);           lua_setfield(L, -2, "toast");
    lua_pushcfunction(L, lua_gg_alert);           lua_setfield(L, -2, "alert");
    lua_pushcfunction(L, lua_gg_prompt);          lua_setfield(L, -2, "prompt");
    lua_pushcfunction(L, lua_gg_multiChoice);     lua_setfield(L, -2, "multiChoice");
    lua_pushcfunction(L, lua_gg_sleep);           lua_setfield(L, -2, "sleep");
    lua_pushcfunction(L, lua_gg_isVisible);       lua_setfield(L, -2, "isVisible");
    lua_pushcfunction(L, lua_gg_copyText);        lua_setfield(L, -2, "copyText");
    lua_pushcfunction(L, lua_gg_getTargetPackage);lua_setfield(L, -2, "getTargetPackage");
    lua_pushcfunction(L, lua_gg_getTargetInfo);   lua_setfield(L, -2, "getTargetInfo");
    lua_pushcfunction(L, lua_gg_setSpeed);        lua_setfield(L, -2, "setSpeed");
    lua_pushcfunction(L, lua_gg_getSpeed);        lua_setfield(L, -2, "getSpeed");

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
