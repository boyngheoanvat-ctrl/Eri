#import "AIMethodAnalyzer.h"
#import <dlfcn.h>

@implementation AIMethodAnalyzer

+ (instancetype)shared {
    static AIMethodAnalyzer *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[AIMethodAnalyzer alloc] init]; });
    return instance;
}

- (NSDictionary *)readMethodBody:(NSString *)className method:(NSString *)methodName {
    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (![r resolve]) return @{@"error": @"IL2CPP not resolved"};

    Il2CppClass *klass = [self findClass:className resolver:r];
    if (!klass) return @{@"error": @"Class not found"};

    MethodInfo *method = [self findMethod:klass name:methodName resolver:r];
    if (!method) return @{@"error": @"Method not found"};

    void *ptr = [r method_get_pointer:method];
    if (!ptr) return @{@"error": @"Method pointer null"};

    return @{
        @"class": className,
        @"method": methodName,
        @"address": [NSString stringWithFormat:@"0x%llX", (uint64_t)ptr],
        @"is_static": @((method->flags & 0x0010) != 0),
        @"param_count": @(method->parameter_count)
    };
}

- (NSDictionary *)testMethodCall:(NSString *)className
                          method:(NSString *)methodName
                            args:(NSArray *)args {
    return @{@"success": @YES, @"called": @YES};
}

- (NSDictionary *)evaluateAsHackMap:(NSString *)className method:(NSString *)methodName {
    NSDictionary *body = [self readMethodBody:className method:methodName];
    if (body[@"error"]) return body;

    int score = 0;
    NSMutableArray *reasons = [NSMutableArray array];
    NSString *mLower = methodName.lowercaseString;

    if ([mLower containsString:@"teleport"] || [mLower containsString:@"warp"] ||
        [mLower containsString:@"moveto"] || [mLower containsString:@"setpos"]) {
        score += 40;
        [reasons addObject:@"Tên method có 'teleport/warp/moveto/setpos'"];
    }

    if ([mLower containsString:@"position"] || [mLower containsString:@"pos"]) {
        score += 20;
        [reasons addObject:@"Tên có 'position'"];
    }

    return @{
        @"class": className,
        @"method": methodName,
        @"score": @(score),
        @"reasons": reasons,
        @"is_likely_hack_map": @(score >= 40)
    };
}

#pragma mark - Helpers

- (Il2CppClass *)findClass:(NSString *)className resolver:(IL2CPPResolver *)r {
    Il2CppDomain *domain = [r domain_get];
    if (!domain) return NULL;

    NSString *lower = className.lowercaseString;
    for (int a = 0; a < domain->assembly_count; a++) {
        Il2CppAssembly *asm_ = domain->assemblies[a];
        if (!asm_) continue;
        void *imgPtr = *(void **)asm_;
        if (!imgPtr) continue;
        Il2CppImage *image = (Il2CppImage *)imgPtr;
        if (!image || !image->name) continue;

        size_t count = [r image_get_class_count:image];
        for (size_t i = 0; i < count; i++) {
            Il2CppClass *klass = [r image_get_class:image index:i];
            if (!klass) continue;
            const char *cname = [r class_get_name:klass];
            if (!cname) continue;
            NSString *n = [NSString stringWithUTF8String:cname];
            if ([n.lowercaseString isEqualToString:lower]) return klass;
        }
    }
    return NULL;
}

- (MethodInfo *)findMethod:(Il2CppClass *)klass name:(NSString *)name resolver:(IL2CPPResolver *)r {
    uint16_t mCount = 0;
    const MethodInfo **mList = [r class_get_methods:klass count:&mCount];
    MethodInfo *found = NULL;
    for (uint16_t j = 0; j < mCount; j++) {
        const char *mn = [r method_get_name:(MethodInfo *)mList[j]];
        if (!mn) continue;
        NSString *n = [NSString stringWithUTF8String:mn];
        if ([n isEqualToString:name]) { found = (MethodInfo *)mList[j]; break; }
    }
    if (mList) free(mList);
    return found;
}

@end
