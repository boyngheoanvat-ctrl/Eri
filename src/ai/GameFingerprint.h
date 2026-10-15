#import <Foundation/Foundation.h>

@interface GameFingerprint : NSObject

+ (instancetype)shared;
- (NSArray<NSDictionary *> *)filterAndRefineMethods:(NSArray<NSDictionary *> *)rawMethods;

@end
