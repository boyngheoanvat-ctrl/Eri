#import "MethodCaller.h"
#import <objc/runtime.h>
#import <objc/message.h>

@implementation MethodCaller

+ (instancetype)shared {
    static MethodCaller *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[MethodCaller alloc] init]; });
    return instance;
}

- (id)callMethod:(MethodInfo *)method onObject:(void *)obj {
    return [self callMethod:method onObject:obj args:@[]];
}

- (id)callMethod:(MethodInfo *)method onObject:(void *)obj args:(NSArray *)args {
    if (!method || !method->methodPointer) return nil;

    // Build method signature từ Il2CppMethod
    typedef void (*Fn0)(void *);
    typedef void (*Fn1)(void *, void *);
    typedef void (*Fn2)(void *, void *, void *);
    typedef void (*Fn3)(void *, void *, void *, void *);
    typedef void (*Fn4)(void *, void *, void *, void *, void *);

    NSUInteger argCount = args.count;

    @try {
        switch (argCount) {
            case 0: {
                Fn0 fn = (Fn0)method->methodPointer;
                fn(obj);
                break;
            }
            case 1: {
                Fn1 fn = (Fn1)method->methodPointer;
                id a0 = args[0];
                fn(obj, (__bridge void *)a0);
                break;
            }
            case 2: {
                Fn2 fn = (Fn2)method->methodPointer;
                id a0 = args[0], a1 = args[1];
                fn(obj, (__bridge void *)a0, (__bridge void *)a1);
                break;
            }
            case 3: {
                Fn3 fn = (Fn3)method->methodPointer;
                id a0 = args[0], a1 = args[1], a2 = args[2];
                fn(obj, (__bridge void *)a0, (__bridge void *)a1, (__bridge void *)a2);
                break;
            }
            case 4: {
                Fn4 fn = (Fn4)method->methodPointer;
                id a0 = args[0], a1 = args[1], a2 = args[2], a3 = args[3];
                fn(obj, (__bridge void *)a0, (__bridge void *)a1, (__bridge void *)a2, (__bridge void *)a3);
                break;
            }
            default:
                return @"Qua nhieu tham so";
        }
    } @catch (NSException *e) {
        return [NSString stringWithFormat:@"Exception: %@", e.reason];
    }

    return @"OK";
}

@end
