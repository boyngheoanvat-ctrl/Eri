#import <Foundation/Foundation.h>
#import "IL2CPPResolver.h"

@interface GameFingerprint : NSObject
+ (instancetype)shared;
- (NSArray<NSDictionary *> *)findMethodsForConcept:(NSString *)concept maxResults:(NSInteger)maxResults;
@end

@implementation GameFingerprint
+ (instancetype)shared {
    static GameFingerprint *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[GameFingerprint alloc] init]; });
    return instance;
}
- (NSArray<NSDictionary *> *)findMethodsForConcept:(NSString *)concept maxResults:(NSInteger)maxResults {
    @autoreleasepool {
        return @[];
    }
}
@end
