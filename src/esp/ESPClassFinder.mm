#import "ESPClassFinder.h"
#import "IL2CPPResolver.h"

@implementation ESPTargetClass
@end

@implementation ESPClassFinder
+ (instancetype)shared {
    static ESPClassFinder *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[ESPClassFinder alloc] init]; });
    return instance;
}
- (NSArray<NSString *> *)findEntityManagerClasses {
    @autoreleasepool { return @[@"ShowPlayerManager", @"EntityManager"]; }
}
- (NSArray<NSString *> *)findCameraClasses {
    @autoreleasepool { return @[@"CameraGame"]; }
}
+ (NSArray<ESPTargetClass *> *)scanActiveTargets {
    @autoreleasepool { return @[]; }
}
@end
