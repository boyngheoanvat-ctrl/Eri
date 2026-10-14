#import "ESPClassFinder.h"
#import "IL2CPPResolver.h"

@implementation ESPClassFinder

+ (instancetype)shared {
    static ESPClassFinder *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[ESPClassFinder alloc] init]; });
    return instance;
}

- (NSArray<NSDictionary *> *)findClassesByName:(NSString *)name {
    NSMutableArray<NSDictionary *> *result = [NSMutableArray array];

    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (![r resolve]) return result;

    Il2CppDomain *domain = [r domain_get];
    if (!domain || !domain->assemblies) return result;

    int maxAssemblies = MIN((int)domain->assembly_count, 5);
    NSString *search = name.lowercaseString;

    for (int a = 0; a < maxAssemblies; a++) {
        @autoreleasepool {
            Il2CppAssembly *assembly = domain->assemblies[a];
            if (!assembly) continue;

            Il2CppImage *image = [r assembly_get_image:assembly];
            if (!image) continue;

            const char *imgNameC = [r image_get_name:image];
            if (!imgNameC) continue;
            NSString *imgName = [NSString stringWithUTF8String:imgNameC];

            size_t classCount = [r image_get_class_count:image];
            if (classCount == 0) continue;

            for (size_t i = 0; i < classCount; i++) {
                @autoreleasepool {
                    Il2CppClass *klass = [r image_get_class:image index:i];
                    if (!klass) continue;

                    const char *cname = [r class_get_name:klass];
                    if (!cname) continue;
                    NSString *clsName = [NSString stringWithUTF8String:cname];
                    if (!clsName) continue;

                    if (search.length > 0 &&
                        [clsName.lowercaseString rangeOfString:search].location == NSNotFound) {
                        continue;
                    }

                    const char *cns = [r class_get_namespace:klass];
                    NSString *nsName = (cns && [NSString stringWithUTF8String:cns])
                                      ? [NSString stringWithUTF8String:cns] : @"";

                    [result addObject:@{
                        @"name": clsName,
                        @"namespace": nsName ?: @"",
                        @"image": imgName ?: @"",
                        @"ptr": [NSValue valueWithPointer:klass],
                    }];
                }
            }
        }
    }

    return result;
}

- (NSArray<NSDictionary *> *)listFieldsOfClass:(Il2CppClass *)klass {
    NSMutableArray<NSDictionary *> *result = [NSMutableArray array];
    if (!klass) return result;

    IL2CPPResolver *r = [IL2CPPResolver shared];

    uint16_t fCount = 0;
    NSArray<NSValue *> *fList = [r class_get_fields:klass count:&fCount];

    for (uint16_t i = 0; i < fCount; i++) {
        FieldInfo *f = (FieldInfo *)fList[i].pointerValue;
        if (!f) continue;

        const char *fn = [r field_get_name:f];
        if (!fn) continue;

        NSString *fname = [NSString stringWithUTF8String:fn];
        int32_t off = [r field_get_offset:f];
        uint32_t token = [r field_get_token:f];

        [result addObject:@{
            @"name": fname ?: @"",
            @"offset": @(off),
            @"token": @(token),
            @"ptr": [NSValue valueWithPointer:f],
        }];
    }

    return result;
}

- (NSArray<NSDictionary *> *)listMethodsOfClass:(Il2CppClass *)klass {
    NSMutableArray<NSDictionary *> *result = [NSMutableArray array];
    if (!klass) return result;

    IL2CPPResolver *r = [IL2CPPResolver shared];

    uint16_t mCount = 0;
    NSArray<NSValue *> *mList = [r class_get_methods:klass count:&mCount];

    for (uint16_t i = 0; i < mCount; i++) {
        MethodInfo *m = (MethodInfo *)mList[i].pointerValue;
        if (!m) continue;

        const char *mn = [r method_get_name:m];
        if (!mn) continue;

        NSString *mname = [NSString stringWithUTF8String:mn];
        uint32_t token = [r method_get_token:m];
        void *ptr = [r method_get_pointer:m];

        [result addObject:@{
            @"name": mname ?: @"",
            @"token": @(token),
            @"rva": @((uint64_t)(uintptr_t)ptr),
            @"ptr": [NSValue valueWithPointer:m],
        }];
    }

    return result;
}

- (Il2CppClass *)findClass:(NSString *)name {
    NSArray<NSDictionary *> *found = [self findClassesByName:name];
    for (NSDictionary *d in found) {
        NSString *clsName = d[@"name"];
        if ([clsName isEqualToString:name]) {
            NSValue *v = d[@"ptr"];
            return (Il2CppClass *)v.pointerValue;
        }
    }
    return NULL;
}

@end
