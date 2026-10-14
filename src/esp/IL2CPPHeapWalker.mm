#import "IL2CPPHeapWalker.h"
#import "IL2CPPResolver.h"

@implementation IL2CPPHeapWalker

+ (instancetype)shared {
    static IL2CPPHeapWalker *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[IL2CPPHeapWalker alloc] init]; });
    return instance;
}

#pragma mark - Static fields

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
                            [staticFields addObject:@{
                                @"name": fname ?: @"",
                                @"offset": @(off),
                            }];
                        }
                    }

                    if (staticFields.count > 0) {
                        const char *cns = [r class_get_namespace:klass];
                        NSString *nsName = (cns && [NSString stringWithUTF8String:cns])
                                          ? [NSString stringWithUTF8String:cns] : @"";
                        [result addObject:@{
                            @"class": clsName,
                            @"namespace": nsName ?: @"",
                            @"image": imgName ?: @"",
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

#pragma mark - Singleton pattern

- (void *)getSingletonInstance:(Il2CppClass *)klass {
    if (!klass) return NULL;

    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (![r resolve]) return NULL;

    NSArray<NSString *> *candidates = @[
        @"Instance", @"_instance", @"s_instance", @"m_Instance",
        @"<Instance>k__BackingField",
        @"Singleton", @"_singleton", @"m_instance",
    ];

    // Tìm static field
    uint16_t fCount = 0;
    NSArray<NSValue *> *fList = [r class_get_fields:klass count:&fCount];

    FieldInfo *targetField = NULL;
    for (uint16_t i = 0; i < fCount; i++) {
        FieldInfo *f = (FieldInfo *)fList[i].pointerValue;
        if (!f) continue;
        const char *fn = [r field_get_name:f];
        if (!fn) continue;
        NSString *fname = [NSString stringWithUTF8String:fn];
        if (!fname) continue;
        for (NSString *cand in candidates) {
            if ([fname isEqualToString:cand]) {
                targetField = f;
                break;
            }
        }
        if (targetField) break;
    }

    // Fallback: getter `get_Instance`
    if (!targetField) {
        uint16_t mCount = 0;
        NSArray<NSValue *> *mList = [r class_get_methods:klass count:&mCount];
        for (uint16_t i = 0; i < mCount; i++) {
            MethodInfo *m = (MethodInfo *)mList[i].pointerValue;
            if (!m) continue;
            const char *mn = [r method_get_name:m];
            if (!mn) continue;
            NSString *mname = [NSString stringWithUTF8String:mn];
            if (!mname) continue;

            if ([mname isEqualToString:@"get_Instance"] ||
                [mname isEqualToString:@"get_instance"]) {
                void *ptr = [r method_get_pointer:m];
                if (!ptr) continue;

                // Static getter: fn(MethodInfo*)
                typedef void *(*fn_static)(void *);
                fn_static fn = (fn_static)ptr;
                return fn(m);
            }
        }
        return NULL;
    }

    // Đọc static field
    int32_t off = [r field_get_offset:targetField];
    void *staticData = [r class_get_static_field_data:klass];
    if (!staticData) return NULL;

    void *addr = (char *)staticData + off;
    return *(void **)addr;
}

#pragma mark - List<T>

- (NSArray<NSValue *> *)readIl2CppList:(void *)listPtr limit:(NSUInteger)limit {
    NSMutableArray<NSValue *> *result = [NSMutableArray array];
    if (!listPtr || limit == 0) return result;

    // List<T> layout (IL2CPP):
    //   0x00: Il2CppClass *klass
    //   0x08: void *monitor
    //   0x10: T[] _items
    //   0x18: int32_t _size
    //   0x1C: int32_t _version
    void *items = *(void **)((char *)listPtr + 0x10);
    int32_t size  = *(int32_t *)((char *)listPtr + 0x18);

    if (!items) return result;
    if (size <= 0 || size > 10000) return result;

    // Array<T> layout:
    //   0x00: Il2CppClass *klass
    //   0x08: void *monitor
    //   0x10: void *bounds
    //   0x18: int32_t max_length
    //   0x1C: padding
    //   0x20: T items[0]
    char *dataStart = (char *)items + 0x20;

    NSUInteger maxN = MIN((NSUInteger)size, limit);
    for (NSUInteger i = 0; i < maxN; i++) {
        void *elem = *(void **)(dataStart + i * sizeof(void *));
        if (elem) [result addObject:[NSValue valueWithPointer:elem]];
    }
    return result;
}

#pragma mark - Collect instances

- (NSArray<NSValue *> *)collectInstancesOfClass:(NSString *)className limit:(NSUInteger)limit {
    NSMutableArray<NSValue *> *result = [NSMutableArray array];
    if (!className || limit == 0) return result;

    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (![r resolve]) return result;

    Il2CppDomain *domain = [r domain_get];
    if (!domain || !domain->assemblies) return result;

    // 1) Tìm Il2CppClass của className
    Il2CppClass *targetClass = NULL;
    for (int a = 0; a < domain->assembly_count && !targetClass; a++) {
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
                if (n && [n isEqualToString:className]) { targetClass = k; break; }
            }
        }
    }
    if (!targetClass) return result;

    // 2) Thử static manager pattern
    NSArray<NSString *> *likelyManagers = @[
        @"EntityManager", @"ShowEntityManager", @"GameManager",
        @"PlayerManager", @"ObjectManager", @"UnitManager",
        @"CharacterManager", @"ActorManager", @"MonsterManager",
    ];

    for (NSString *mgrName in likelyManagers) {
        Il2CppClass *mgrClass = NULL;
        for (int a = 0; a < domain->assembly_count && !mgrClass; a++) {
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
                    if (n && [n isEqualToString:mgrName]) { mgrClass = k; break; }
                }
            }
        }
        if (!mgrClass) continue;

        void *instance = [self getSingletonInstance:mgrClass];
        if (!instance) continue;

        // Tìm field List<targetClass> trong mgrClass
        uint16_t fCount = 0;
        NSArray<NSValue *> *fList = [r class_get_fields:mgrClass count:&fCount];
        for (uint16_t i = 0; i < fCount; i++) {
            FieldInfo *f = (FieldInfo *)fList[i].pointerValue;
            if (!f) continue;
            const char *fn = [r field_get_name:f];
            if (!fn) continue;
            NSString *fname = [NSString stringWithUTF8String:fn];
            if (!fname) continue;

            NSString *fl = fname.lowercaseString;
            if (!([fl containsString:@"list"] || [fl containsString:@"all"] ||
                  [fl containsString:@"entit"] || [fl containsString:@"item"])) continue;

            int32_t off = [r field_get_offset:f];
            void *listPtr = *(void **)((char *)instance + off);
            if (!listPtr) continue;

            NSArray<NSValue *> *items = [self readIl2CppList:listPtr limit:limit];
            if (items.count == 0) continue;

            // Kiểm tra phần tử đầu có đúng klass targetClass
            void *firstElem = items[0].pointerValue;
            if (!firstElem) continue;
            void *firstKlass = *(void **)firstElem;
            if (firstKlass == targetClass) {
                [result addObjectsFromArray:items];
                return result;
            }
        }
    }

    return result;
}

@end
