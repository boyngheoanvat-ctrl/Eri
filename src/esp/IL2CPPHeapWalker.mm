#import "IL2CPPHeapWalker.h"
#import "IL2CPPResolver.h"

@implementation IL2CPPHeapWalker

+ (instancetype)shared {
    static IL2CPPHeapWalker *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[IL2CPPHeapWalker alloc] init]; });
    return instance;
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
            if (classCount == 0) continue;

            for (size_t i = 0; i < classCount; i++) {
                @autoreleasepool {
                    Il2CppClass *klass = [r image_get_class:image index:i];
                    if (!klass) continue;

                    const char *cname = [r class_get_name:klass];
                    if (!cname) continue;
                    NSString *clsName = [NSString stringWithUTF8String:cname];
                    if (!clsName) continue;

                    // Lọc theo keyword nếu có
                    if (keyword.length > 0 &&
                        [clsName rangeOfString:keyword options:NSCaseInsensitiveSearch].location == NSNotFound) {
                        continue;
                    }

                    // Kiểm tra có static_fields không
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

                        // Chỉ lấy field có offset >= 0 (field instance)
                        // Static field có offset âm hoặc offset đặc biệt
                        if (off < 0) {
                            NSString *fname = [NSString stringWithUTF8String:fn];
                            [staticFields addObject:@{
                                @"name": fname ?: @"",
                                @"offset": @(off),
                            }];
                        }
                    }

                    if (staticFields.count > 0) {
                        [result addObject:@{
                            @"class": clsName,
                            @"namespace": [NSString stringWithUTF8String:([r class_get_namespace:klass] ?: "")] ?: @"",
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

    // Field static thường có offset âm hoặc là offset trong vùng static data
    // Đối chiếu il2cpp.h để chắc chắn
    if (off < 0) {
        // Offset âm: tính từ staticData - offset (thường vậy, tuỳ version)
        return (char *)staticData + off;
    }
    return (char *)staticData + off;
}

@end
