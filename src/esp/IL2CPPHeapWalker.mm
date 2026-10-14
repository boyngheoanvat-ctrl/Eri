#import "IL2CPPHeapWalker.h"
#import "IL2CPPResolver.h"

// Cache toàn bộ class theo tên để tăng tốc lần 2 trở đi
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

#pragma mark - Class lookup

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

            const char *imgNameC = [r image_get_name:image];
            if (!imgNameC) continue;
            NSString *imgName = [NSString stringWithUTF8String:imgNameC];

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

#pragma mark - Auto-detect entity class

- (BOOL)classLooksLikeEntity:(Il2CppClass *)klass resolver:(IL2CPPResolver *)r {
    if (!klass) return NO;
    const char *cname = [r class_get_name:klass];
    if (!cname) return NO;
    NSString *name = [NSString stringWithUTF8String:cname];
    if (!name || name.length < 2) return NO;

    // Heuristic tên class
    NSString *lower = name.lowercaseString;
    NSArray<NSString *> *positiveKeywords = @[
        @"entity", @"fighter", @"player", @"unit", @"actor",
        @"character", @"monster", @"mob", @"npc", @"hero",
        @"avatar", @"role", @"creature"
    ];
    BOOL nameMatch = NO;
    for (NSString *kw in positiveKeywords) {
        if ([lower containsString:kw]) { nameMatch = YES; break; }
    }
    if (!nameMatch) return NO;

    // Loại trừ class hệ thống
    NSArray<NSString *> *negativeKeywords = @[
        @"manager", @"system", @"config", @"data", @"info",
        @"controller", @"panel", @"ui", @"view", @"factory",
        @"builder", @"pool", @"base", @"interface", @"abstract"
    ];
    for (NSString *kw in negativeKeywords) {
        if ([lower containsString:kw]) return NO;
    }

    // Phải có get_Position
    uint16_t mCount = 0;
    NSArray<NSValue *> *mList = [r class_get_methods:klass count:&mCount];
    BOOL hasPos = NO;
    for (uint16_t i = 0; i < mCount; i++) {
        MethodInfo *m = (MethodInfo *)mList[i].pointerValue;
        if (!m) continue;
        const char *mn = [r method_get_name:m];
        if (!mn) continue;
        NSString *mname = [NSString stringWithUTF8String:mn];
        if ([mname isEqualToString:@"get_Position"] ||
            [mname isEqualToString:@"get_position"] ||
            [mname isEqualToString:@"get_transform"]) {
            hasPos = YES;
            break;
        }
    }
    return hasPos;
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
                    if (![self classLooksLikeEntity:k resolver:r]) continue;

                    // Chấm điểm: càng nhiều method liên quan càng cao
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
                        if ([n isEqualToString:@"get_Hp"] || [n isEqualToString:@"get_HP"] ||
                            [n isEqualToString:@"get_m_Hp"]) score += 8;
                        if ([n isEqualToString:@"get_Name"] || [n isEqualToString:@"get_m_Name"] ||
                            [n isEqualToString:@"get_RoleName"]) score += 5;
                        if ([n isEqualToString:@"get_IsDead"] || [n isEqualToString:@"get_m_bDeath"]) score += 3;
                        if ([n isEqualToString:@"get_IsSelf"] || [n isEqualToString:@"get_m_bSelf"]) score += 3;
                    }

                    if (score > bestScore) {
                        bestScore = score;
                        best = k;
                    }
                }
            }
        }
    }

    if (best) {
        const char *cname = [r class_get_name:best];
        NSLog(@"[ESP] auto-detect entity class = %s (score=%lu)",
              cname ?: "?", (unsigned long)bestScore);
    }
    return best;
}

#pragma mark - List<T>

- (NSArray<NSValue *> *)readIl2CppList:(void *)listPtr limit:(NSUInteger)limit {
    NSMutableArray<NSValue *> *result = [NSMutableArray array];
    if (!listPtr || limit == 0) return result;

    // Thử nhiều offset cho List<T>
    // Standard IL2CPP: 0x10 = _items, 0x18 = _size
    // Một số version: 0x18 = _items, 0x20 = _size
    const int kListItemsOffsets[] = { 0x10, 0x18 };
    const int kListSizeOffsets[]  = { 0x18, 0x20 };

    void *items = NULL;
    int32_t size = 0;
    int itemsOff = 0;

    for (int i = 0; i < 2; i++) {
        void *it = *(void **)((char *)listPtr + kListItemsOffsets[i]);
        int32_t sz = *(int32_t *)((char *)listPtr + kListSizeOffsets[i]);
        if (it && sz > 0 && sz < 100000) {
            items = it;
            size = sz;
            itemsOff = kListItemsOffsets[i];
            break;
        }
    }
    if (!items || size <= 0) return result;

    // Array<T>: items bắt đầu ở 0x20 (chuẩn) hoặc 0x18
    // Thử cả 2, chọn cái đầu tiên có con trỏ hợp lệ
    char *dataStart = (char *)items + 0x20;

    // Heuristic: kiểm tra phần tử đầu có phải con trỏ hợp lệ không
    void *first = *(void **)dataStart;
    if (!first || ((uintptr_t)first < 0x1000)) {
        // Thử offset 0x18
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
    (void)itemsOff;
    return result;
}

#pragma mark - Strategy 1: Singleton field + List

- (NSArray<NSValue *> *)trySingletonListStrategy:(Il2CppClass *)entityClass
                                          resolver:(IL2CPPResolver *)r
                                             limit:(NSUInteger)limit {
    Il2CppDomain *domain = [r domain_get];
    if (!domain) return @[];

    NSArray<NSString *> *singletonFieldNames = @[
        @"Instance", @"_instance", @"s_instance", @"m_Instance",
        @"<Instance>k__BackingField", @"Singleton", @"m_instance",
    ];

    NSArray<NSString *> *listFieldKeywords = @[
        @"list", @"all", @"entit", @"player", @"unit", @"actor", @"show"
    ];

    for (int a = 0; a < MIN((int)domain->assembly_count, 8); a++) {
        @autoreleasepool {
            Il2CppAssembly *asm_ = domain->assemblies[a];
            if (!asm_) continue;
            Il2CppImage *image = [r assembly_get_image:asm_];
            if (!image) continue;

            size_t classCount = [r image_get_class_count:image];
            for (size_t i = 0; i < classCount; i++) {
                @autoreleasepool {
                    Il2CppClass *klass = [r image_get_class:image index:i];
                    if (!klass) continue;

                    const char *cname = [r class_get_name:klass];
                    if (!cname) continue;
                    NSString *cn = [NSString stringWithUTF8String:cname];
                    if (!cn) continue;

                    // Chỉ class tên chứa "Manager" / "Game" / "Battle"
                    NSString *cl = cn.lowercaseString;
                    if (!([cl containsString:@"manager"] ||
                          [cl containsString:@"battle"] ||
                          [cl containsString:@"game"] ||
                          [cl containsString:@"world"])) {
                        continue;
                    }

                    // Tìm field singleton
                    uint16_t fCount = 0;
                    NSArray<NSValue *> *fList = [r class_get_fields:klass count:&fCount];

                    FieldInfo *instField = NULL;
                    for (uint16_t j = 0; j < fCount; j++) {
                        FieldInfo *f = (FieldInfo *)fList[j].pointerValue;
                        if (!f) continue;
                        const char *fn = [r field_get_name:f];
                        if (!fn) continue;
                        NSString *fname = [NSString stringWithUTF8String:fn];
                        for (NSString *cand in singletonFieldNames) {
                            if ([fname isEqualToString:cand]) { instField = f; break; }
                        }
                        if (instField) break;
                    }
                    if (!instField) continue;

                    // Đọc instance
                    void *staticData = [r class_get_static_field_data:klass];
                    if (!staticData) continue;
                    int32_t iOff = [r field_get_offset:instField];
                    void *instance = *(void **)((char *)staticData + iOff);
                    if (!instance) continue;

                    // Tìm field List
                    for (uint16_t j = 0; j < fCount; j++) {
                        FieldInfo *f = (FieldInfo *)fList[j].pointerValue;
                        if (!f) continue;
                        const char *fn = [r field_get_name:f];
                        if (!fn) continue;
                        NSString *fname = [NSString stringWithUTF8String:fn];
                        if (!fname) continue;
                        NSString *fl = fname.lowercaseString;

                        BOOL matches = NO;
                        for (NSString *kw in listFieldKeywords) {
                            if ([fl containsString:kw]) { matches = YES; break; }
                        }
                        if (!matches) continue;

                        int32_t off = [r field_get_offset:f];
                        void *listPtr = *(void **)((char *)instance + off);
                        if (!listPtr) continue;

                        NSArray<NSValue *> *items = [self readIl2CppList:listPtr limit:limit];
                        if (items.count == 0) continue;

                        // Kiểm tra phần tử đầu có phải entityClass (hoặc con của nó)
                        void *first = items[0].pointerValue;
                        if (!first) continue;
                        void *firstKlass = *(void **)first;
                        if (firstKlass == entityClass) {
                            gLastStrategy = ESPCollectStrategySingletonList;
                            NSLog(@"[ESP] strategy=SingletonList via %@.%@",
                                  cn, fname);
                            return items;
                        }
                    }
                }
            }
        }
    }
    return @[];
}

#pragma mark - Strategy 2: Static List field

- (NSArray<NSValue *> *)tryStaticListStrategy:(Il2CppClass *)entityClass
                                       resolver:(IL2CPPResolver *)r
                                          limit:(NSUInteger)limit {
    Il2CppDomain *domain = [r domain_get];
    if (!domain) return @[];

    for (int a = 0; a < MIN((int)domain->assembly_count, 8); a++) {
        @autoreleasepool {
            Il2CppAssembly *asm_ = domain->assemblies[a];
            if (!asm_) continue;
            Il2CppImage *image = [r assembly_get_image:asm_];
            if (!image) continue;

            size_t classCount = [r image_get_class_count:image];
            for (size_t i = 0; i < classCount; i++) {
                @autoreleasepool {
                    Il2CppClass *klass = [r image_get_class:image index:i];
                    if (!klass) continue;
                    void *staticData = [r class_get_static_field_data:klass];
                    if (!staticData) continue;

                    uint16_t fCount = 0;
                    NSArray<NSValue *> *fList = [r class_get_fields:klass count:&fCount];
                    for (uint16_t j = 0; j < fCount; j++) {
                        FieldInfo *f = (FieldInfo *)fList[j].pointerValue;
                        if (!f) continue;
                        int32_t off = [r field_get_offset:f];
                        if (off >= 0) continue; // chỉ static (offset âm)

                        const char *fn = [r field_get_name:f];
                        if (!fn) continue;
                        NSString *fname = [NSString stringWithUTF8String:fn];
                        NSString *fl = fname.lowercaseString;
                        if (!([fl containsString:@"list"] || [fl containsString:@"all"] ||
                              [fl containsString:@"entit"] || [fl containsString:@"player"])) {
                            continue;
                        }

                        void *listPtr = *(void **)((char *)staticData + off);
                        if (!listPtr) continue;

                        NSArray<NSValue *> *items = [self readIl2CppList:listPtr limit:limit];
                        if (items.count == 0) continue;

                        void *first = items[0].pointerValue;
                        if (!first) continue;
                        void *firstKlass = *(void **)first;
                        if (firstKlass == entityClass) {
                            gLastStrategy = ESPCollectStrategyStaticList;
                            NSLog(@"[ESP] strategy=StaticList via field %@", fname);
                            return items;
                        }
                    }
                }
            }
        }
    }
    return @[];
}

#pragma mark - Public auto-collect

- (NSArray<NSValue *> *)autoCollectInstancesWithLimit:(NSUInteger)limit {
    gLastStrategy = ESPCollectStrategyNone;

    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (![r resolve]) return @[];

    Il2CppClass *entityClass = [self autoDetectEntityClass];
    if (!entityClass) return @[];

    NSArray<NSValue *> *result = [self trySingletonListStrategy:entityClass
                                                        resolver:r
                                                           limit:limit];
    if (result.count > 0) return result;

    result = [self tryStaticListStrategy:entityClass resolver:r limit:limit];
    if (result.count > 0) return result;

    return @[];
}

@end
