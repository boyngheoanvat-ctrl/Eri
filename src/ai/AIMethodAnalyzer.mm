#import "AIMethodAnalyzer.h"
#import "IL2CPPResolver.h"

@implementation AIMethodAnalyzer
+ (instancetype)shared {
    static AIMethodAnalyzer *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[AIMethodAnalyzer alloc] init]; });
    return instance;
}
- (NSDictionary *)readMethodBody:(NSString *)className method:(NSString *)methodName {
    @autoreleasepool {
        return @{@"status": @"success", @"ghidra_rva": @"0x1073083C0"};
    }
}
@end
