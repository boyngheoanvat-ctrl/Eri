#import <Foundation/Foundation.h>
#import "IL2CPPResolver.h"

@interface AIMethodAnalyzer : NSObject

+ (instancetype)shared;

- (NSDictionary *)readMethodBody:(NSString *)className
                          method:(NSString *)methodName;

- (NSDictionary *)testMethodCall:(NSString *)className
                          method:(NSString *)methodName
                            args:(NSArray *)args;

- (NSDictionary *)evaluateAsHackMap:(NSString *)className
                              method:(NSString *)methodName;

@end
