#import "IL2CPPResolver.h"
#import <dlfcn.h>
#import <mach-o/dyld.h>

@interface IL2CPPResolver ()
@property (nonatomic, assign) void *handle;
@end

@implementation IL2CPPResolver

+ (instancetype)shared {
    static IL2CPPResolver *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[IL2CPPResolver alloc] init]; });
    return instance;
}

- (BOOL)resolve {
    if (self.handle) return YES;

    const char *paths[] = {
        "@executable_path/Frameworks/UnityFramework.framework/UnityFramework",
        "@executable_path/Frameworks/il2cpp.framework/il2cpp",
        "@executable_path/il2cpp",
        "UnityFramework",
        NULL
    };
    for (int i = 0; paths[i]; i++) {
        self.handle = dlopen(paths[i], RTLD_NOW);
        if (self.handle) break;
    }
    if (!self.handle) {
        uint32_t count = _dyld_image_count();
        for (uint32_t i = 0; i < count; i++) {
            const char *name = _dyld_get_image_name(i);
            if (name && (strstr(name, "UnityFramework") || strstr(name, "il2cpp") || strstr(name, "GameAssembly"))) {
                self.handle = dlopen(name, RTLD_NOW);
                if (self.handle) break;
            }
        }
    }
    return self.handle != NULL;
}

- (BOOL)isResolved { return self.handle != NULL; }

- (Il2CppDomain *)domain_get {
    typedef Il2CppDomain *(*fn_t)(void);
    fn_t fn = (fn_t)dlsym(self.handle, "il2cpp_domain_get");
    return fn ? fn() : NULL;
}

- (size_t)image_get_class_count:(Il2CppImage *)image {
    typedef size_t (*fn_t)(const Il2CppImage *);
    fn_t fn = (fn_t)dlsym(self.handle, "il2cpp_image_get_class_count");
    return fn ? fn(image) : 0;
}

- (Il2CppClass *)image_get_class:(Il2CppImage *)image index:(size_t)index {
    typedef Il2CppClass *(*fn_t)(const Il2CppImage *, size_t);
    fn_t fn = (fn_t)dlsym(self.handle, "il2cpp_image_get_class");
    return fn ? fn(image, index) : NULL;
}

- (const char *)class_get_name:(Il2CppClass *)k { return k ? k->name : NULL; }
- (const char *)class_get_namespace:(Il2CppClass *)k { return k ? k->namespaze : NULL; }

- (const MethodInfo **)class_get_methods:(Il2CppClass *)klass count:(uint16_t *)count {
    typedef const MethodInfo *(*fn_t)(Il2CppClass *, void **);
    fn_t fn = (fn_t)dlsym(self.handle, "il2cpp_class_get_methods");
    if (!fn) {
        if (count) *count = klass ? klass->method_count : 0;
        return klass ? (const MethodInfo **)klass->methods : NULL;
    }
    void *iter = NULL;
    uint16_t total = klass ? klass->method_count : 0;
    const MethodInfo **list = (const MethodInfo **)malloc(sizeof(void *) * (total > 0 ? total : 1));
    uint16_t i = 0;
    const MethodInfo *m;
    while ((m = fn(klass, &iter)) != NULL) {
        if (total > 0 && i >= total) break;
        list[i++] = m;
    }
    if (count) *count = i;
    return list;
}

- (const FieldInfo **)class_get_fields:(Il2CppClass *)klass count:(uint16_t *)count {
    typedef const FieldInfo *(*fn_t)(Il2CppClass *, void **);
    fn_t fn = (fn_t)dlsym(self.handle, "il2cpp_class_get_fields");
    if (!fn) {
        if (count) *count = klass ? klass->field_count : 0;
        return klass ? (const FieldInfo **)klass->fields : NULL;
    }
    void *iter = NULL;
    uint16_t total = klass ? klass->field_count : 0;
    const FieldInfo **list = (const FieldInfo **)malloc(sizeof(void *) * (total > 0 ? total : 1));
    uint16_t i = 0;
    const FieldInfo *f;
    while ((f = fn(klass, &iter)) != NULL) {
        if (total > 0 && i >= total) break;
        list[i++] = f;
    }
    if (count) *count = i;
    return list;
}

- (const char *)method_get_name:(MethodInfo *)m { return m ? m->name : NULL; }
- (const char *)field_get_name:(FieldInfo *)f { return f ? f->name : NULL; }
- (int32_t)field_get_offset:(FieldInfo *)f { return f ? f->offset : 0; }
- (uint32_t)method_get_token:(MethodInfo *)m { return m ? m->token : 0; }

- (void *)method_get_pointer:(MethodInfo *)m {
    typedef void *(*fn_t)(const MethodInfo *);
    fn_t fn = (fn_t)dlsym(self.handle, "il2cpp_method_get_pointer");
    if (fn) return fn(m);
    return m ? m->methodPointer : NULL;
}

@end
