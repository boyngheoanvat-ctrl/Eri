#import <Foundation/Foundation.h>

@interface LuaEngine : NSObject

+ (instancetype)shared;

- (BOOL)isAvailable;
- (NSString *)runScript:(NSString *)script;
- (void)stop;

@end
