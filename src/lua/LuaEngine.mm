#import "LuaEngine.h"
#import <dlfcn.h>
#import <unistd.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>

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
        if (s) [logOutput appendFormat:@"%s ", s];
    }
    NSLog(@"[Lua Print]: %@", logOutput);
    return 0;
}

#pragma mark - Mock GameGuardian (gg.*) APIs
static int lua_gg_setRanges(lua_State *L) { return 0; }
static int lua_gg_searchNumber(lua_State *L) { lua_newtable(L); return 1; }
static int lua_gg_refineNumber(lua_State *L) { return 0; }
static int lua_gg_getResults(lua_State *L) {
    lua_newtable(L);
    lua_newtable(L);
    lua_pushstring(L, "1089806008"); lua_setfield(L, -2, "value");
    lua_pushinteger(L, 1); lua_setfield(L, -2, "flags");
    lua_rawseti(L, -2, 1);
    return 1;
}
static int lua_gg_editAll(lua_State *L) { return 0; }
static int lua_gg_clearResults(lua_State *L) { return 0; }
static int lua_gg_toast(lua_State *L) {
    const char *msg = lua_tostring(L, 1);
    if (msg) NSLog(@"[Lua Toast]: %s", msg);
    return 0;
}
static int lua_gg_alert(lua_State *L) { lua_pushinteger(L, 1); return 1; }
static int lua_gg_multiChoice(lua_State *L) {
    lua_newtable(L);
    lua_pushboolean(L, 1); lua_rawseti(L, -2, 1);
    return 1;
}
static int lua_gg_sleep(lua_State *L) {
    int ms = (int)lua_tonumber(L, 1);
    usleep(ms > 0 ? ms * 1000 : 1000);
    return 0;
}
static int lua_gg_setVisible(lua_State *L) { return 0; }
static int lua_gg_isVisible(lua_State *L) {
    static int callCount = 0;
    callCount++;
    lua_pushboolean(L, callCount == 1 ? 1 : 0);
    return 1;
}

#pragma mark - Memory & IL2CPP Patching (ASLR Bypass)
static int lua_il2cpp_patch_memory(lua_State *L) {
    const char *rvaStr = lua_tostring(L, 1);
    if (!rvaStr) { lua_pushboolean(L, 0); return 1; }
    
    unsigned long long rva = 0;
    [[NSScanner scannerWithString:[NSString stringWithUTF8String:rvaStr]] scanHexLongLong:&rva];
    
    // Tính toán ASLR Slide trên iOS
    uint64_t slide = _dyld_get_image_vmaddr_slide(0);
    uint64_t targetAddress = slide + rva;
    
    NSLog(@"[LuaEngine Patch] ASLR Slide: 0x%llx | Target VA: 0x%llx", slide, targetAddress);
    
    if (targetAddress > 0) {
        mach_port_t task = mach_task_self();
        vm_size_t size = 8;
        if (vm_protect(task, targetAddress, size, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE) == KERN_SUCCESS) {
            uint32_t patchData[2] = {0x52800020, 0xD65F03C0}; // MOV W0, #1 ; RET
            vm_write(task, (vm_address_t)targetAddress, (vm_offset_t)patchData, sizeof(patchData));
            NSLog(@"[LuaEngine Patch] Ghi đè ARM64 thành công tại địa chỉ thực: 0x%llx", targetAddress);
        }
    }
    
    lua_pushboolean(L, 1);
    return 1;
}

#pragma mark - Runner Engine
- (NSString *)runScript:(NSString *)script {
    if (!script) return @"[Lua] Script rỗng";

    lua_State *L = luaL_newstate();
    if (!L) return @"[Lua] Không khởi tạo được Lua State";

    luaL_openlibs(L);
    self.L = L;

    lua_register(L, "print", lua_custom_print);
    
    // Đăng ký namespace il2cpp
    lua_newtable(L);
    lua_pushcfunction(L, lua_il2cpp_patch_memory);
    lua_setfield(L, -2, "patch_memory");
    lua_setglobal(L, "il2cpp");

    // Đăng ký namespace gg trọn bộ
    lua_newtable(L);
    lua_pushinteger(L, 1);     lua_setfield(L, -2, "REGION_ANONYMOUS");
    lua_pushinteger(L, 2);     lua_setfield(L, -2, "REGION_CODE_APP");
    lua_pushinteger(L, 4);     lua_setfield(L, -2, "REGION_CODE_SYS");
    lua_pushinteger(L, 128);   lua_setfield(L, -2, "REGION_C_ALLOC");
    lua_pushinteger(L, 32768); lua_setfield(L, -2, "REGION_BAD");
    lua_pushinteger(L, -1);    lua_setfield(L, -2, "REGION_ALL");
    lua_pushinteger(L, 1);     lua_setfield(L, -2, "TYPE_DWORD");
    lua_pushinteger(L, 4);     lua_setfield(L, -2, "TYPE_FLOAT");

    lua_pushcfunction(L, lua_gg_setRanges);     lua_setfield(L, -2, "setRanges");
    lua_pushcfunction(L, lua_gg_searchNumber);  lua_setfield(L, -2, "searchNumber");
    lua_pushcfunction(L, lua_gg_refineNumber);  lua_setfield(L, -2, "refineNumber");
    lua_pushcfunction(L, lua_gg_getResults);    lua_setfield(L, -2, "getResults");
    lua_pushcfunction(L, lua_gg_editAll);       lua_setfield(L, -2, "editAll");
    lua_pushcfunction(L, lua_gg_clearResults);  lua_setfield(L, -2, "clearResults");
    lua_pushcfunction(L, lua_gg_toast);         lua_setfield(L, -2, "toast");
    lua_pushcfunction(L, lua_gg_alert);         lua_setfield(L, -2, "alert");
    lua_pushcfunction(L, lua_gg_multiChoice);   lua_setfield(L, -2, "multiChoice");
    lua_pushcfunction(L, lua_gg_sleep);         lua_setfield(L, -2, "sleep");
    lua_pushcfunction(L, lua_gg_setVisible);    lua_setfield(L, -2, "setVisible");
    lua_pushcfunction(L, lua_gg_isVisible);     lua_setfield(L, -2, "isVisible");

    lua_setglobal(L, "gg");

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
