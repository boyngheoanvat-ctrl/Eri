#import "IL2CPPHeapWalker.h"
#import <objc/runtime.h>
#import <dlfcn.h>

@implementation IL2CPPHeapWalker

+ (instancetype)shared {
    static IL2CPPHeapWalker *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[IL2CPPHeapWalker alloc] init]; });
    return instance;
}

- (void)enumerateObjectsOfClass:(NSString *)className
                          block:(HeapObjectBlock)block
                          limit:(NSInteger)limit {
    if (className.length == 0 || !block) return;

    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (![r resolve]) return;

    Il2CppClass *targetClass = [self findClass:className resolver:r];
    if (!targetClass) return;

    [self enumerateViaStaticFields:targetClass resolver:r block:block limit:limit];
}

#pragma mark - Enumerate via static fields

- (void)enumerateViaStaticFields:(Il2CppClass *)targetClass
                        resolver:(IL2CPPResolver *)r
                           block:(HeapObjectBlock)block
                           limit:(NSInteger)limit {

    NSArray *candidateClasses = @[
        @"ShowPlayerManager", @"EntityManager", @"GameManager",
        @"ShowEntityManager", @"BattleManager", @"PlayerManager",
        @"EntityList", @"ShowEntityList", @"ShowPlayer",
        @"SceneManager", @"ShowSceneManager", @"GameEntityManager"
    ];

    for (NSString *candidate in candidateClasses) {
        Il2CppClass *managerClass = [self findClass:candidate resolver:r];
        if (!managerClass) continue;

        uint16_t fCount = 0;
        const FieldInfo **fList = [r class_get_fields:managerClass count:&fCount];
        for (uint16_t i = 0; i < fCount; i++) {
            const char *fn = [r field_get_name:(FieldInfo *)fList[i]];
            if (!fn) continue;
            NSString *fieldName = [NSString stringWithUTF8String:fn];
            NSString *lower = fieldName.lowercaseString;

            if ([lower containsString:@"entit"] ||
                [lower containsString:@"player"] ||
                [lower containsString:@"list"] ||
                [lower containsString:@"all"]) {

                void *fieldValue = [self getStaticFieldValue:managerClass
                                                       field:(FieldInfo *)fList[i]
                                                    resolver:r];
                if (!fieldValue) continue;

                [self enumerateList:fieldValue
                        targetClass:targetClass
                              block:block
                              limit:limit];
            }
        }
        if (fList) free(fList);
    }
}

- (void *)getStaticFieldValue:(Il2CppClass *)klass
                        field:(FieldInfo *)field
                     resolver:(IL2CPPResolver *)r {
    if (!klass || !field) return NULL;
    if (!klass->static_fields) return NULL;

    void *addr = (char *)klass->static_fields + field->offset;
    return *(void **)addr;
}

- (void)enumerateList:(void *)listPtr
          targetClass:(Il2CppClass *)targetClass
                block:(HeapObjectBlock)block
                limit:(NSInteger)limit {
    if (!listPtr) return;

    void *items = *(void **)((char *)listPtr + 0x10);
    uint32_t size = *(uint32_t *)((char *)listPtr + 0x18);

    if (!items || size == 0 || size > 500) return;

    NSInteger count = 0;
    for (uint32_t i = 0; i < size && count < limit; i++) {
        void *item = *(void **)((char *)items + i * 8);
        if (!item) continue;

        Il2CppClass *itemClass = [self classOfObject:item];
        if (!itemClass) continue;

        const char *cname = itemClass->name;
        if (cname && strcmp(cname, targetClass->name) == 0) {
            block(item, itemClass);
            count++;
        }
    }
}

- (Il2CppClass *)classOfObject:(void *)objPtr {
    if (!objPtr) return NULL;
    void *klassPtr = *(void **)objPtr;
    if (!klassPtr) return NULL;
    return (Il2CppClass *)klassPtr;
}

- (Il2CppClass *)findClass:(NSString *)name resolver:(IL2CPPResolver *)r {
    Il2CppDomain *domain = [r domain_get];
    if (!domain) return NULL;

    NSString *lower = name.lowercaseString;
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

@end
