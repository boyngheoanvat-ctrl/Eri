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

#pragma mark - Mock Implementations cho Script của bạn

static int lua_gg_setRanges(lua_State *L) {
    return 0;
}

static int lua_gg_searchNumber(lua_State *L) {
    lua_newtable(L);
    return 1;
}

static int lua_gg_refineNumber(lua_State *L) {
    return 0;
}

static int lua_gg_processResume(lua_State *L) {
    return 0;
}

static int lua_gg_getResults(lua_State *L) {
    // Trả về danh sách kết quả mẫu để vòng lặp ipairs(_UPVALUE2_) không bị lỗi
    lua_newtable(L);
    
    // Tạo 1 phần tử mẫu
    lua_newtable(L);
    lua_pushstring(L, "1089806008"); lua_setfield(L, -2, "value");
    lua_pushinteger(L, 1); // TYPE_DWORD
    lua_setfield(L, -2, "flags");
    
    lua_rawseti(L, -2, 1);
    return 1;
}

static int lua_gg_setValues(lua_State *L) {
    return 0;
}

static int lua_gg_addListItems(lua_State *L) {
    return 0;
}

static int lua_gg_editAll(lua_State *L) {
    return 0;
}

static int lua_gg_clearResults(lua_State *L) {
    return 0;
}

static int lua_gg_clearList(lua_State *L) {
    return 0;
}

static int lua_gg_toast(lua_State *L) {
    const char *msg = lua_tostring(L, 1);
    if (msg) NSLog(@"[Lua Toast]: %s", msg);
    return 0;
}

static int lua_gg_alert(lua_State *L) {
    // Mặc định bấm nút 1 (OK / Yes / Option 1)
    lua_pushinteger(L, 1);
    return 1;
}

static int lua_gg_choice(lua_State *L) {
    // Tự động chọn lựa chọn thứ 1 trong menu gg.choice
    lua_pushinteger(L, 1);
    return 1;
}

static int lua_gg_multiChoice(lua_State *L) {
    // Trả về bảng các lựa chọn cho menu multiChoice
    lua_newtable(L);
    lua_pushboolean(L, 1); lua_rawseti(L, -2, 1); // Bật option 1
    lua_pushboolean(L, 0); lua_rawseti(L, -2, 2);
    lua_pushboolean(L, 0); lua_rawseti(L, -2, 3);
    lua_pushboolean(L, 0); lua_rawseti(L, -2, 4);
    return 1;
}

static int lua_gg_sleep(lua_State *L) {
    int ms = (int)lua_tonumber(L, 1);
    usleep(ms > 0 ? ms * 1000 : 1000);
    return 0;
}

static int lua_gg_setVisible(lua_State *L) {
    return 0;
}

static int lua_gg_isVisible(lua_State *L) {
    // Trả về true để kích hoạt Menu Main(), sau đó trả về false để tránh lặp vô hạn đơ UI
    static int callCount = 0;
    callCount++;
    if (callCount == 1) {
        lua_pushboolean(L, 1);
    } else {
        lua_pushboolean(L, 0);
    }
    return 1;
}

static int lua_il2cpp_get_method_pointer(lua_State *L) {
    const char *clsName = lua_tostring(L, 1);
    const char *mName = lua_tostring(L, 2);
    uint64_t ptr = 0; 
    lua_pushinteger(L, (lua_Integer)ptr);
    return 1;
}

#pragma mark - Runner Engine

- (NSString *)runScript:(NSString *)script {
    if (!script) return @"[Lua] Script rỗng";

    lua_State *L = luaL_newstate();
    if (!L) return @"[Lua] Không tạo được lua_State";

    luaL_openlibs(L);
    self.L = L;

    lua_register(L, "print", lua_custom_print);
    
    // il2cpp global
    lua_newtable(L);
    lua_pushcfunction(L, lua_il2cpp_get_method_pointer);
    lua_setfield(L, -2, "get_method_pointer");
    lua_setglobal(L, "il2cpp");

    // ==========================================
    // BẢNG GIẢ LẬP GG ĐẦY ĐỦ CHO SCRIPT CỦA BẠN
    // ==========================================
    lua_newtable(L);
    
    // Hằng số vùng nhớ
    lua_pushinteger(L, 1);     lua_setfield(L, -2, "REGION_ANONYMOUS");
    lua_pushinteger(L, 2);     lua_setfield(L, -2, "REGION_CODE_APP");
    lua_pushinteger(L, 4);     lua_setfield(L, -2, "REGION_CODE_SYS");
    lua_pushinteger(L, 128);   lua_setfield(L, -2, "REGION_C_ALLOC");
    lua_pushinteger(L, 32768); lua_setfield(L, -2, "REGION_BAD");
    lua_pushinteger(L, -1);    lua_setfield(L, -2, "REGION_ALL");

    // Kiểu dữ liệu & cờ
    lua_pushinteger(L, 1);     lua_setfield(L, -2, "TYPE_DWORD");
    lua_pushinteger(L, 4);     lua_setfield(L, -2, "TYPE_FLOAT");
    lua_pushinteger(L, 0);     lua_setfield(L, -2, "SIGN_EQUAL");

    // Đăng ký toàn bộ hàm API mà script của bạn dùng
    lua_pushcfunction(L, lua_gg_setRanges);     lua_setfield(L, -2, "setRanges");
    lua_pushcfunction(L, lua_gg_searchNumber);  lua_setfield(L, -2, "searchNumber");
    lua_pushcfunction(L, lua_gg_refineNumber);  lua_setfield(L, -2, "refineNumber");
    lua_pushcfunction(L, lua_gg_processResume); lua_setfield(L, -2, "processResume");
    lua_pushcfunction(L, lua_gg_getResults);    lua_setfield(L, -2, "getResults");
    lua_pushcfunction(L, lua_gg_setValues);     lua_setfield(L, -2, "setValues");
    lua_pushcfunction(L, lua_gg_addListItems);  lua_setfield(L, -2, "addListItems");
    lua_pushcfunction(L, lua_gg_editAll);       lua_setfield(L, -2, "editAll");
    lua_pushcfunction(L, lua_gg_clearResults);  lua_setfield(L, -2, "clearResults");
    lua_pushcfunction(L, lua_gg_clearList);     lua_setfield(L, -2, "clearList");
    lua_pushcfunction(L, lua_gg_toast);         lua_setfield(L, -2, "toast");
    lua_pushcfunction(L, lua_gg_alert);         lua_setfield(L, -2, "alert");
    lua_pushcfunction(L, lua_gg_choice);        lua_setfield(L, -2, "choice");
    lua_pushcfunction(L, lua_gg_multiChoice);   lua_setfield(L, -2, "multiChoice");
    lua_pushcfunction(L, lua_gg_sleep);         lua_setfield(L, -2, "sleep");
    lua_pushcfunction(L, lua_gg_setVisible);    lua_setfield(L, -2, "setVisible");
    lua_pushcfunction(L, lua_gg_isVisible);    lua_setfield(L, -2, "isVisible");

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
