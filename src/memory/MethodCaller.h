#import <Foundation/Foundation.h>
#import "IL2CPPResolver.h"

@interface MethodCaller : NSObject

+ (instancetype)shared;

// Gọi method không tham số
- (id)callMethod:(MethodInfo *)method
        onObject:(void *)obj;

// Gọi method với tham số NSNumber/NSString
- (id)callMethod:(MethodInfo *)method
        onObject:(void *)obj
           args:(NSArray *)args;

@end
