#import <Foundation/Foundation.h>
#import "IL2CPPResolver.h"

typedef void (^HeapObjectBlock)(void *objPtr, Il2CppClass *klass);

@interface IL2CPPHeapWalker : NSObject

+ (instancetype)shared;

- (void)enumerateObjectsOfClass:(NSString *)className
                          block:(HeapObjectBlock)block
                          limit:(NSInteger)limit;

@end
