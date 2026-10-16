#import "AICHookGenerator.h"

@implementation AICHookGeneratorResult
@end

@implementation AICHookGenerator

+ (instancetype)shared {
    static AICHookGenerator *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AICHookGenerator alloc] init];
    });
    return instance;
}

- (void)generateMapHackForQuery:(NSString *)query completion:(void(^)(AICHookGeneratorResult *result))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *foundOffset = @"0x1F4A80";

        if ([query.lowercaseString containsString:@"tầm nhìn"] || [query.lowercaseString containsString:@"zoom"]) {
            foundOffset = @"0x2B5C90";
        }

        AICHookGeneratorResult *res = [[AICHookGeneratorResult alloc] init];
        res.offsetAddress = foundOffset;

        res.cppCode = [NSString stringWithFormat:
            @"#include <substrate.h>\n\n"
            @"// ==========================================\n"
            @"// [AI Auto-Generated] Map Hack / Fog of War\n"
            @"// Target Offset: %@\n"
            @"// ==========================================\n\n"
            @"bool (*old_IsFogOfWarEnabled)(void *instance);\n"
            @"bool hk_IsFogOfWarEnabled(void *instance) {\n"
            @"    if (!instance) return true;\n"
            @"    return false;\n"
            @"}\n\n"
            @"void initMapHack() {\n"
            @"    void *addr = (void *)((uintptr_t)_dyld_get_image_header(0) + %@);\n"
            @"    MSHookFunction(addr, (void *)hk_IsFogOfWarEnabled, (void **)&old_IsFogOfWarEnabled);\n"
            @"}", foundOffset, foundOffset];

        res.luaCode = [NSString stringWithFormat:
            @"-- ==========================================\n"
            @"-- [AI Auto-Generated] Lua Map Hack Script\n"
            @"-- Target Offset: %@\n"
            @"-- ==========================================\n\n"
            @"local baseAddr = getRealOffset(%@)\n"
            @"print('[Lua AI] Applying Map Hack at address: ' .. baseAddr)\n\n"
            @"local success = memory.writeBool(baseAddr, false)\n"
            @"if success then\n"
            @"    print('>>> [SUCCESS] Hack Map đã được kích hoạt qua Lua!')\n"
            @"else\n"
            @"    print('>>> [ERROR] Không thể ghi bộ nhớ tại offset này!')\n"
            @"end", foundOffset, foundOffset];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(res);
            }
        });
    });
}

@end
