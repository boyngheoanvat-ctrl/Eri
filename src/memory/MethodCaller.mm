#import "MethodCaller.h"
#import "IL2CPPResolver.h"

@implementation MethodCaller

+ (instancetype)shared {
    static MethodCaller *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[MethodCaller alloc] init]; });
    return instance;
}

- (id)callMethod:(MethodInfo *)method onObject:(void *)obj args:(NSArray *)args {
    if (!method) return nil;

    IL2CPPResolver *r = [IL2CPPResolver shared];
    void *ptr = [r method_get_pointer:method];
    if (!ptr) return nil;

    NSUInteger argc = args.count;

    switch (argc) {
        case 0: {
            typedef void *(*Fn0)(void *, void *);
            Fn0 fn = (Fn0)ptr;
            return (__bridge id)fn(obj, NULL);
        }
        case 1: {
            typedef void *(*Fn1)(void *, void *, void *);
            Fn1 fn = (Fn1)ptr;
            return (__bridge id)fn(obj, (__bridge void *)args[0], NULL);
        }
        case 2: {
            typedef void *(*Fn2)(void *, void *, void *, void *);
            Fn2 fn = (Fn2)ptr;
            return (__bridge id)fn(obj,
                                    (__bridge void *)args[0],
                                    (__bridge void *)args[1], NULL);
        }
        case 3: {
            typedef void *(*Fn3)(void *, void *, void *, void *, void *);
            Fn3 fn = (Fn3)ptr;
            return (__bridge id)fn(obj,
                                    (__bridge void *)args[0],
                                    (__bridge void *)args[1],
                                    (__bridge void *)args[2], NULL);
        }
        case 4: {
            typedef void *(*Fn4)(void *, void *, void *, void *, void *, void *);
            Fn4 fn = (Fn4)ptr;
            return (__bridge id)fn(obj,
                                    (__bridge void *)args[0],
                                    (__bridge void *)args[1],
                                    (__bridge void *)args[2],
                                    (__bridge void *)args[3], NULL);
        }
        default:
            return nil;
    }
}

@end
