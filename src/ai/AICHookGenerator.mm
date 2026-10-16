#import "AICHookGenerator.h"
#import "IL2CPPResolver.h"

@implementation AICHookGeneratorResult
@end

@implementation AICHookGenerator
+ (instancetype)shared {
    static AICHookGenerator *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[AICHookGenerator alloc] init]; });
    return instance;
}
- (void)generateMapHackForQuery:(NSString *)query completion:(void(^)(AICHookGeneratorResult *result))completion {
    @autoreleasepool {
        AICHookGeneratorResult *res = [[AICHookGeneratorResult alloc] init];
        res.offsetAddress = @"0x1073083C0";
        res.cppCode = @"// Ghidra RVA C++ Patch Generated";
        res.luaCode = @"-- Ghidra RVA Lua Patch Generated";
        if (completion) completion(res);
    }
}
@end
