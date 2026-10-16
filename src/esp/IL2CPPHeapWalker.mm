#import "IL2CPPHeapWalker.h"
#import "IL2CPPResolver.h"

static NSMutableDictionary<NSString *, NSValue *> *gClassCache = nil;
static ESPCollectStrategy gLastStrategy = ESPCollectStrategyNone;

@implementation IL2CPPHeapWalker

+ (instancetype)shared {
    static IL2CPPHeapWalker *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[IL2CPPHeapWalker alloc] init];
        gClassCache = [NSMutableDictionary dictionary];
    });
    return instance;
}

- (ESPCollectStrategy)lastStrategy { return gLastStrategy; }

- (Il2CppClass *)findClassByName:(NSString *)name resolver:(IL2CPPResolver *)r {
    if (!name) return NULL;
    NSValue *cached = gClassCache[name];
    if (cached) return (Il2CppClass *)cached.pointerValue;

    Il2CppDomain *domain = [r domain_get];
    if (!domain || !domain->assemblies) return NULL;

    for (int a = 0; a < domain->assembly_count; a++) {
        @autoreleasepool {
            Il2CppAssembly *asm_ = domain->assemblies[a];
            if (!asm_) continue;
            Il2CppImage *image = [r assembly_get_image:asm_];
            if (!image) continue;
            size_t count = [r image_get_class_count:image];
            for (size_t i = 0; i < count; i++) {
                Il2CppClass *k = [r image_get_class:image index:i];
                if (!k) continue;
                const char *cname = [r class_get_name:k];
                if (!cname) continue;
                NSString *n = [NSString stringWithUTF8String:cname];
                if (!n) continue;
                if ([n isEqualToString:name]) {
                    gClassCache[name] = [NSValue valueWithPointer:k];
                    return k;
                }
            }
        }
    }
    return NULL;
}

- (NSArray<NSDictionary *> *)findClassesWithStaticFields:(NSString *)keyword {
    NSMutableArray<NSDictionary *> *result = [NSMutableArray array];
    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (![r resolve]) return result;

    Il2CppDomain *domain = [r domain_get];
    if (!domain || !domain->assemblies) return result;

    int maxAssemblies = MIN((int)domain->assembly_count, 5);

    for (int a = 0; a < maxAssemblies; a++) {
        @autoreleasepool {
            Il2CppAssembly *assembly = domain->assemblies[a];
            if (!assembly) continue;
            Il2CppImage *image = [r assembly_get_image:assembly];
            if (!image) continue;

            size_t classCount = [r image_get_class_count:image];
            for (size_t i = 0; i < classCount; i++) {
                @autoreleasepool {
                    Il2CppClass *klass = [r image_get_class:image index:i];
                    if (!klass) continue;
                    const char *cname = [r class_get_name:klass];
                    if (!cname) continue;
                    NSString *clsName = [NSString stringWithUTF8String:cname];
                    if (!clsName) continue;

                    if (keyword.length > 0 &&
                        [clsName rangeOfString:keyword options:NSCaseInsensitiveSearch].location == NSNotFound) {
                        continue;
                    }

                    void *staticData = [r class_get_static_field_data:klass];
                    if (!staticData) continue;

                    uint16_t fCount = 0;
                    NSArray<NSValue *> *fList = [r class_get_fields:klass count:&fCount];

                    NSMutableArray *staticFields = [NSMutableArray array];
                    for (uint16_t j = 0; j < fCount; j++) {
                        FieldInfo *f = (FieldInfo *)fList[j].pointerValue;
                        if (!f) continue;
                        const char *fn = [r field_get_name:f];
                        if (!fn) continue;
                        int32_t off = [r field_get_offset:f];
                        if (off < 0) {
                            NSString *fname = [NSString stringWithUTF8String:fn];
                            [staticFields addObject:@{@"name": fname ?: @"", @"offset": @(off)}];
                        }
                    }

                    if (staticFields.count > 0) {
                        [result addObject:@{
                            @"class": clsName,
                            @"staticFields": staticFields,
                            @"staticData": [NSValue valueWithPointer:staticData],
                        }];
                    }
                }
            }
        }
    }
    return result;
}

- (void *)getStaticFieldAddress:(Il2CppClass *)klass field:(FieldInfo *)field {
    if (!klass || !field) return NULL;
    IL2CPPResolver *r = [IL2CPPResolver shared];
    void *staticData = [r class_get_static_field_data:klass];
    if (!staticData) return NULL;
    int32_t off = [r field_get_offset:field];
    return (char *)staticData + off;
}

- (Il2CppClass *)autoDetectEntityClass {
    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (![r resolve]) return NULL;

    Il2CppDomain *domain = [r domain_get];
    if (!domain || !domain->assemblies) return NULL;

    Il2CppClass *best = NULL;
    NSUInteger bestScore = 0;

    for (int a = 0; a < MIN((int)domain->assembly_count, 8); a++) {
        @autoreleasepool {
            Il2CppAssembly *asm_ = domain->assemblies[a];
            if (!asm_) continue;
            Il2CppImage *image = [r assembly_get_image:asm_];
            if (!image) continue;

            size_t count = [r image_get_class_count:image];
            for (size_t i = 0; i < count; i++) {
                @autoreleasepool {
                    Il2CppClass *k = [r image_get_class:image index:i];
                    if (!k) continue;

                    const char *cname = [r class_get_name:k];
                    if (!cname) continue;
                    NSString *name = [NSString stringWithUTF8String:cname];
                    NSString *lower = name.lowercaseString;

                    if (!([lower containsString:@"player"] || [lower containsString:@"entity"] || [lower containsString:@"actor"] || [lower containsString:@"unit"] || [lower containsString:@"hero"])) {
                        continue;
                    }

                    uint16_t mCount = 0;
                    NSArray<NSValue *> *mList = [r class_get_methods:k count:&mCount];
                    NSUInteger score = 0;
                    for (uint16_t j = 0; j < mCount; j++) {
                        MethodInfo *m = (MethodInfo *)mList[j].pointerValue;
                        if (!m) continue;
                        const char *mn = [r method_get_name:m];
                        if (!mn) continue;
                        NSString *n = [NSString stringWithUTF8String:mn];
                        if ([n isEqualToString:@"get_Position"]) score += 10;
                        if ([n isEqualToString:@"get_Hp"] || [n isEqualToString:@"get_HP"]) score += 8;
                    }

                    if (score > bestScore) {
                        bestScore = score;
                        best = k;
                    }
                }
            }
        }
    }
    return best;
}

- (NSArray<NSValue *> *)readIl2CppList:(void *)listPtr limit:(NSUInteger)limit {
    NSMutableArray<NSValue *> *result = [NSMutableArray array];
    if (!listPtr || limit == 0) return result;

    const int kListItemsOffsets[] = { 0x10, 0x18 };
    const int kListSizeOffsets[]  = { 0x18, 0x20 };

    void *items = NULL;
    int32_t size = 0;

    for (int i = 0; i < 2; i++) {
        void *it = *(void **)((char *)listPtr + kListItemsOffsets[i]);
        int32_t sz = *(int32_t *)((char *)listPtr + kListSizeOffsets[i]);
        if (it && sz > 0 && sz < 100000) {
            items = it;
            size = sz;
            break;
        }
    }
    if (!items || size <= 0) return result;

    char *dataStart = (char *)items + 0x20;
    void *first = *(void **)dataStart;
    if (!first || ((uintptr_t)first < 0x1000)) {
        char *alt = (char *)items + 0x18;
        void *altFirst = *(void **)alt;
        if (altFirst && ((uintptr_t)altFirst >= 0x1000)) {
            dataStart = alt;
        }
    }

    NSUInteger maxN = MIN((NSUInteger)size, limit);
    for (NSUInteger i = 0; i < maxN; i++) {
        void *elem = *(void **)(dataStart + i * sizeof(void *));
        if (elem && ((uintptr_t)elem >= 0x1000)) {
            [result addObject:[NSValue valueWithPointer:elem]];
        }
    }
    return result;
}

- (NSArray<NSValue *> *)autoCollectInstancesWithLimit:(NSUInteger)limit {
    gLastStrategy = ESPCollectStrategyNone;
    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (![r resolve]) return @[];

    Il2CppClass *entityClass = [self autoDetectEntityClass];
    if (!entityClass) return @[];

    return @[];
}

@end
