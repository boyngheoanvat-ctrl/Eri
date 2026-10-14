#import "ESPClassFinder.h"
#import "IL2CPPResolver.h"

@implementation ESPClassFinder

+ (instancetype)shared {
    static ESPClassFinder *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[ESPClassFinder alloc] init]; });
    return instance;
}

#pragma mark - Public API

- (NSArray<NSDictionary *> *)findClassesByName:(NSString *)name {
    NSMutableArray<NSDictionary *> *result = [NSMutableArray array];

    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (![r resolve]) return result;

    Il2CppDomain *domain = [r domain_get];
    if (!domain || !domain->assemblies) return result;

    int maxAssemblies = MIN((int)domain->assembly_count, 8);
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

#pragma mark - Entity manager detection

- (NSArray<NSDictionary *> *)findEntityManagerClasses {
    NSMutableArray<NSDictionary *> *result = [NSMutableArray array];

    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (![r resolve]) return result;

    Il2CppDomain *domain = [r domain_get];
    if (!domain || !domain->assemblies) return result;

    NSArray<NSString *> *managerKeywords = @[
        @"manager", @"controller", @"battle", @"world", @"game",
    ];

    NSArray<NSString *> *entityKeywords = @[
        @"entity", @"fighter", @"player", @"unit", @"actor",
        @"hero", @"monster", @"character",
    ];
    (void)entityKeywords;

    int maxAssemblies = MIN((int)domain->assembly_count, 8);

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
            for (size_t i = 0; i < classCount && result.count < 30; i++) {
                @autoreleasepool {
                    Il2CppClass *klass = [r image_get_class:image index:i];
                    if (!klass) continue;
                    const char *cname = [r class_get_name:klass];
                    if (!cname) continue;
                    NSString *clsName = [NSString stringWithUTF8String:cname];
                    if (!clsName) continue;

                    NSString *cl = clsName.lowercaseString;
                    BOOL hasMgrKeyword = NO;
                    for (NSString *kw in managerKeywords) {
                        if ([cl containsString:kw]) { hasMgrKeyword = YES; break; }
                    }
                    if (!hasMgrKeyword) continue;

                    uint16_t fCount = 0;
                    NSArray<NSValue *> *fList = [r class_get_fields:klass count:&fCount];

                    BOOL hasEntityList = NO;
                    NSString *listFieldName = nil;

                    for (uint16_t j = 0; j < fCount; j++) {
                        FieldInfo *f = (FieldInfo *)fList[j].pointerValue;
                        if (!f) continue;
                        const char *fn = [r field_get_name:f];
                        if (!fn) continue;
                        NSString *fname = [NSString stringWithUTF8String:fn];
                        if (!fname) continue;
                        NSString *fl = fname.lowercaseString;

                        BOOL nameMatch = [fl containsString:@"list"] ||
                                         [fl containsString:@"all"] ||
                                         [fl containsString:@"entit"] ||
                                         [fl containsString:@"player"];
                        if (!nameMatch) continue;

                        hasEntityList = YES;
                        listFieldName = fname;
                        break;
                    }

                    if (!hasEntityList) continue;

                    NSUInteger score = 0;
                    if ([cl containsString:@"battle"]) score += 30;
                    if ([cl containsString:@"game"])   score += 20;
                    if ([cl containsString:@"world"])  score += 15;

                    [result addObject:@{
                        @"name": clsName,
                        @"namespace": [self nsOf:klass resolver:r] ?: @"",
                        @"image": imgName ?: @"",
                        @"list_field": listFieldName ?: @"",
                        @"score": @(score),
                        @"ptr": [NSValue valueWithPointer:klass],
                    }];
                }
            }
        }
    }

    [result sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [b[@"score"] compare:a[@"score"]];
    }];

    return result;
}

#pragma mark - Camera detection

- (NSArray<NSDictionary *> *)findCameraClasses {
    NSMutableArray<NSDictionary *> *result = [NSMutableArray array];

    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (![r resolve]) return result;

    Il2CppDomain *domain = [r domain_get];
    if (!domain || !domain->assemblies) return result;

    int maxAssemblies = MIN((int)domain->assembly_count, 8);

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

                    if (![clsName.lowercaseString containsString:@"camera"]) continue;

                    uint16_t mCount = 0;
                    NSArray<NSValue *> *mList = [r class_get_methods:klass count:&mCount];
                    BOOL hasW2S = NO;
                    BOOL hasGetMain = NO;
                    for (uint16_t j = 0; j < mCount; j++) {
                        MethodInfo *m = (MethodInfo *)mList[j].pointerValue;
                        if (!m) continue;
                        const char *mn = [r method_get_name:m];
                        if (!mn) continue;
                        NSString *mname = [NSString stringWithUTF8String:mn];
                        if ([mname isEqualToString:@"WorldToScreenPoint"]) hasW2S = YES;
                        if ([mname isEqualToString:@"get_main"]) hasGetMain = YES;
                    }

                    if (!hasW2S) continue;

                    [result addObject:@{
                        @"name": clsName,
                        @"namespace": [self nsOf:klass resolver:r] ?: @"",
                        @"image": imgName ?: @"",
                        @"has_get_main": @(hasGetMain),
                        @"ptr": [NSValue valueWithPointer:klass],
                    }];
                }
            }
        }
    }

    return result;
}

#pragma mark - Static entity list detection

- (NSArray<NSDictionary *> *)findClassesWithStaticEntityList {
    NSMutableArray<NSDictionary *> *result = [NSMutableArray array];

    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (![r resolve]) return result;

    Il2CppDomain *domain = [r domain_get];
    if (!domain || !domain->assemblies) return result;

    int maxAssemblies = MIN((int)domain->assembly_count, 8);

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
            for (size_t i = 0; i < classCount && result.count < 30; i++) {
                @autoreleasepool {
                    Il2CppClass *klass = [r image_get_class:image index:i];
                    if (!klass) continue;

                    void *staticData = [r class_get_static_field_data:klass];
                    if (!staticData) continue;

                    uint16_t fCount = 0;
                    NSArray<NSValue *> *fList = [r class_get_fields:klass count:&fCount];

                    NSMutableArray *staticLists = [NSMutableArray array];
                    for (uint16_t j = 0; j < fCount; j++) {
                        FieldInfo *f = (FieldInfo *)fList[j].pointerValue;
                        if (!f) continue;
                        const char *fn = [r field_get_name:f];
                        if (!fn) continue;
                        NSString *fname = [NSString stringWithUTF8String:fn];
                        if (!fname) continue;
                        NSString *fl = fname.lowercaseString;

                        BOOL isList = [fl containsString:@"list"] ||
                                      [fl containsString:@"all"] ||
                                      [fl containsString:@"entit"] ||
                                      [fl containsString:@"player"];
                        if (!isList) continue;

                        int32_t off = [r field_get_offset:f];
                        if (off >= 0) continue;

                        [staticLists addObject:@{
                            @"name": fname,
                            @"offset": @(off),
                        }];
                    }

                    if (staticLists.count == 0) continue;

                    const char *cn = [r class_get_name:klass];
                    NSString *clsName = cn ? [NSString stringWithUTF8String:cn] : @"?";

                    [result addObject:@{
                        @"name": clsName ?: @"",
                        @"namespace": [self nsOf:klass resolver:r] ?: @"",
                        @"image": imgName ?: @"",
                        @"static_lists": staticLists,
                        @"ptr": [NSValue valueWithPointer:klass],
                    }];
                }
            }
        }
    }

    return result;
}

#pragma mark - Methods returning entity list

- (NSArray<NSDictionary *> *)findMethodsReturningEntityList {
    NSMutableArray<NSDictionary *> *result = [NSMutableArray array];

    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (![r resolve]) return result;

    Il2CppDomain *domain = [r domain_get];
    if (!domain || !domain->assemblies) return result;

    int maxAssemblies = MIN((int)domain->assembly_count, 8);

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
            for (size_t i = 0; i < classCount && result.count < 50; i++) {
                @autoreleasepool {
                    Il2CppClass *klass = [r image_get_class:image index:i];
                    if (!klass) continue;
                    const char *cn = [r class_get_name:klass];
                    if (!cn) continue;
                    NSString *clsName = [NSString stringWithUTF8String:cn];
                    if (!clsName) continue;

                    uint16_t mCount = 0;
                    NSArray<NSValue *> *mList = [r class_get_methods:klass count:&mCount];

                    for (uint16_t j = 0; j < mCount; j++) {
                        MethodInfo *m = (MethodInfo *)mList[j].pointerValue;
                        if (!m) continue;
                        const char *mn = [r method_get_name:m];
                        if (!mn) continue;
                        NSString *mname = [NSString stringWithUTF8String:mn];
                        if (!mname) continue;
                        NSString *ml = mname.lowercaseString;

                        BOOL nameMatch = [ml containsString:@"get_"] &&
                                         ([ml containsString:@"list"] ||
                                          [ml containsString:@"all"] ||
                                          [ml containsString:@"entit"] ||
                                          [ml containsString:@"player"]);
                        if (!nameMatch) continue;

                        void *ptr = [r method_get_pointer:m];
                        uint64_t rva = (uint64_t)(uintptr_t)ptr;

                        [result addObject:@{
                            @"class": clsName,
                            @"method": mname,
                            @"image": imgName ?: @"",
                            @"rva": [NSString stringWithFormat:@"0x%llX", rva],
                            @"ptr": [NSValue valueWithPointer:m],
                        }];
                    }
                }
            }
        }
    }

    return result;
}

#pragma mark - Full scan report

- (NSDictionary *)fullScanReport {
    NSMutableDictionary *report = [NSMutableDictionary dictionary];

    NSArray *entityMgr = [self findEntityManagerClasses];
    NSArray *camera = [self findCameraClasses];
    NSArray *staticLists = [self findClassesWithStaticEntityList];
    NSArray *entityMethods = [self findMethodsReturningEntityList];

    report[@"entity_manager_count"] = @(entityMgr.count);
    report[@"camera_count"] = @(camera.count);
    report[@"static_list_count"] = @(staticLists.count);
    report[@"entity_method_count"] = @(entityMethods.count);

    if (entityMgr.count > 0) report[@"entity_managers"] = [entityMgr subarrayWithRange:
        NSMakeRange(0, MIN((NSUInteger)10, entityMgr.count))];
    if (camera.count > 0) report[@"cameras"] = camera;
    if (staticLists.count > 0) report[@"static_lists"] = [staticLists subarrayWithRange:
        NSMakeRange(0, MIN((NSUInteger)10, staticLists.count))];
    if (entityMethods.count > 0) report[@"entity_methods"] = [entityMethods subarrayWithRange:
        NSMakeRange(0, MIN((NSUInteger)20, entityMethods.count))];

    return report;
}

#pragma mark - List fields/methods

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

#pragma mark - Helper

- (NSString *)nsOf:(Il2CppClass *)klass resolver:(IL2CPPResolver *)r {
    if (!klass) return @"";
    const char *ns = [r class_get_namespace:klass];
    if (!ns) return @"";
    return [NSString stringWithUTF8String:ns] ?: @"";
}

@end
