#import "ESPClassFinder.h"
#import "IL2CPPResolver.h"

@implementation ESPClassFinder

+ (instancetype)shared {
    static ESPClassFinder *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[ESPClassFinder alloc] init]; });
    return instance;
}

#pragma mark - Find Entity Manager Classes

- (NSArray<NSDictionary *> *)findEntityManagerClasses {
    NSMutableArray *results = [NSMutableArray array];

    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (![r resolve]) return results;

    Il2CppDomain *domain = [r domain_get];
    if (!domain) return results;

    // Tên có keyword gợi ý manager
    NSArray *keywords = @[@"manager", @"entity", @"showplayer", @"battle",
                           @"controller", @"system"];

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
            NSString *name = [NSString stringWithUTF8String:cname];
            NSString *lower = name.lowercaseString;

            for (NSString *kw in keywords) {
                if ([lower containsString:kw]) {
                    // Đếm static field
                    NSInteger staticFieldCount = 0;
                    NSInteger listFieldCount = 0;
                    uint16_t fCount = 0;
                    const FieldInfo **fList = [r class_get_fields:klass count:&fCount];
                    for (uint16_t j = 0; j < fCount; j++) {
                        const char *fn = [r field_get_name:(FieldInfo *)fList[j]];
                        if (fn) {
                            NSString *fname = [NSString stringWithUTF8String:fn];
                            if ([fname.lowercaseString containsString:@"list"] ||
                                [fname.lowercaseString containsString:@"entit"]) {
                                listFieldCount++;
                            }
                        }
                    }
                    if (fList) free(fList);

                    [results addObject:@{
                        @"name": name,
                        @"namespace": [r class_get_namespace:klass]
                            ? [NSString stringWithUTF8String:[r class_get_namespace:klass]] : @"",
                        @"method_count": @(klass->method_count),
                        @"field_count": @(klass->field_count),
                        @"list_field_count": @(listFieldCount),
                        @"score": @(listFieldCount * 10 + (klass->method_count > 5 ? 5 : 0))
                    }];
                    break;
                }
            }
        }
    }

    // Sort theo score
    [results sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [b[@"score"] compare:a[@"score"]];
    }];

    return results;
}

#pragma mark - Find Camera Classes

- (NSArray<NSDictionary *> *)findCameraClasses {
    NSMutableArray *results = [NSMutableArray array];

    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (![r resolve]) return results;

    Il2CppDomain *domain = [r domain_get];
    if (!domain) return results;

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
            NSString *name = [NSString stringWithUTF8String:cname];
            if (![name.lowercaseString containsString:@"camera"]) continue;

            // Tìm method WorldToScreen
            BOOL hasWorldToScreen = NO;
            uint16_t mCount = 0;
            const MethodInfo **mList = [r class_get_methods:klass count:&mCount];
            for (uint16_t j = 0; j < mCount; j++) {
                const char *mn = [r method_get_name:(MethodInfo *)mList[j]];
                if (mn && strstr(mn, "WorldToScreen")) {
                    hasWorldToScreen = YES;
                    break;
                }
            }
            if (mList) free(mList);

            [results addObject:@{
                @"name": name,
                @"namespace": [r class_get_namespace:klass]
                    ? [NSString stringWithUTF8String:[r class_get_namespace:klass]] : @"",
                @"has_world_to_screen": @(hasWorldToScreen),
                @"score": @(hasWorldToScreen ? 100 : 10)
            }];
        }
    }

    [results sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [b[@"score"] compare:a[@"score"]];
    }];

    return results;
}

#pragma mark - Find Classes With Static Entity List

- (NSArray<NSDictionary *> *)findClassesWithStaticEntityList {
    NSMutableArray *results = [NSMutableArray array];

    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (![r resolve]) return results;

    Il2CppDomain *domain = [r domain_get];
    if (!domain) return results;

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

            // Chỉ class có static_fields
            if (!klass->static_fields) continue;

            NSMutableArray *staticFields = [NSMutableArray array];
            uint16_t fCount = 0;
            const FieldInfo **fList = [r class_get_fields:klass count:&fCount];
            for (uint16_t j = 0; j < fCount; j++) {
                const char *fn = [r field_get_name:(FieldInfo *)fList[j]];
                if (!fn) continue;
                NSString *fname = [NSString stringWithUTF8String:fn];

                // Field static thường có "m_" hoặc "s_" prefix
                if ([fname hasPrefix:@"m_"] || [fname hasPrefix:@"s_"] ||
                    [fname hasPrefix:@"g_"] || [fname.lowercaseString containsString:@"all"] ||
                    [fname.lowercaseString containsString:@"list"]) {
                    [staticFields addObject:fname];
                }
            }
            if (fList) free(fList);

            if (staticFields.count > 0) {
                const char *cname = [r class_get_name:klass];
                if (!cname) continue;
                [results addObject:@{
                    @"name": [NSString stringWithUTF8String:cname],
                    @"namespace": [r class_get_namespace:klass]
                        ? [NSString stringWithUTF8String:[r class_get_namespace:klass]] : @"",
                    @"static_fields": staticFields,
                    @"score": @(staticFields.count * 5)
                }];
            }
        }
    }

    [results sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [b[@"score"] compare:a[@"score"]];
    }];

    return results;
}

#pragma mark - Find Methods Returning Entity List

- (NSArray<NSDictionary *> *)findMethodsReturningEntityList {
    NSMutableArray *results = [NSMutableArray array];

    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (![r resolve]) return results;

    Il2CppDomain *domain = [r domain_get];
    if (!domain) return results;

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
            NSString *className = [NSString stringWithUTF8String:cname];

            uint16_t mCount = 0;
            const MethodInfo **mList = [r class_get_methods:klass count:&mCount];
            for (uint16_t j = 0; j < mCount; j++) {
                const char *mn = [r method_get_name:(MethodInfo *)mList[j]];
                if (!mn) continue;
                NSString *mname = [NSString stringWithUTF8String:mn];

                // Method trả về list entity
                if (([mname hasPrefix:@"get_"] || [mname containsString:@"Get"]) &&
                    ([mname.lowercaseString containsString:@"entit"] ||
                     [mname.lowercaseString containsString:@"player"] ||
                     [mname.lowercaseString containsString:@"list"] ||
                     [mname.lowercaseString containsString:@"all"])) {

                    [results addObject:@{
                        @"class": className,
                        @"method": mname,
                        @"score": @10
                    }];
                }
            }
            if (mList) free(mList);
        }
    }

    return results;
}

#pragma mark - Full Scan

- (NSDictionary *)fullScanReport {
    NSMutableDictionary *report = [NSMutableDictionary dictionary];

    report[@"entity_managers"] = [self findEntityManagerClasses];
    report[@"camera_classes"] = [self findCameraClasses];
    report[@"static_list_classes"] = [self findClassesWithStaticEntityList];
    report[@"entity_list_methods"] = [self findMethodsReturningEntityList];

    return report;
}

@end
