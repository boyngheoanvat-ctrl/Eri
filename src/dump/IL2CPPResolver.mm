#import "IL2CPPResolver.h"
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#include <string.h>
#include <stdio.h>

#pragma mark - Symbol finder (chỉ dùng dlsym, không duyệt symbol table)

static void *find_sym(void *handle, const char *baseName) {
    if (!handle || !baseName) return NULL;

    // 1. dlsym trực tiếp
    void *p = dlsym(handle, baseName);
    if (p) return p;

    // 2. Mach-O C: thêm gạch dưới
    char buf[512];
    snprintf(buf, sizeof(buf), "_%s", baseName);
    p = dlsym(handle, buf);
    if (p) return p;

    // 3. Itanium C++ mangled void()
    size_t n = strlen(baseName);
    snprintf(buf, sizeof(buf), "__Z%zu%sv", n, baseName);
    p = dlsym(handle, buf);
    if (p) return p;

    // 4. RTLD_DEFAULT
    p = dlsym(RTLD_DEFAULT, baseName);
    if (p) return p;

    return NULL;
}

#pragma mark -

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
        if (self.handle) {
            NSLog(@"[IL2CPPResolver] Opened: %s", paths[i]);
            break;
        }
    }

    if (!self.handle) {
        uint32_t count = _dyld_image_count();
        for (uint32_t i = 0; i < count; i++) {
            const char *name = _dyld_get_image_name(i);
            if (name && (strstr(name, "UnityFramework") ||
                         strstr(name, "il2cpp") ||
                         strstr(name, "GameAssembly"))) {
                self.handle = dlopen(name, RTLD_NOW);
                if (self.handle) {
                    NSLog(@"[IL2CPPResolver] Opened via dyld: %s", name);
                    break;
                }
            }
        }
    }

    return self.handle != NULL;
}

- (BOOL)isResolved { return self.handle != NULL; }

#pragma mark - Thread attach

- (void)attachCurrentThread {
    if (!self.handle) return;
    if ([NSThread isMainThread]) return;

    typedef Il2CppDomain *(*fn_t)(void);
    fn_t dg = (fn_t)find_sym(self.handle, "il2cpp_domain_get");
    if (!dg) return;
    Il2CppDomain *domain = dg();
    if (!domain) return;

    typedef void *(*ta_t)(Il2CppDomain *);
    ta_t ta = (ta_t)find_sym(self.handle, "il2cpp_thread_attach");
    if (ta) ta(domain);
}

#pragma mark - Domain

- (Il2CppDomain *)domain_get {
    if (!self.handle) return NULL;
    typedef Il2CppDomain *(*fn_t)(void);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_domain_get");
    return fn ? fn() : NULL;
}

#pragma mark - Image

- (Il2CppImage *)assembly_get_image:(Il2CppAssembly *)assembly {
    if (!assembly) return NULL;
    typedef Il2CppImage *(*fn_t)(const Il2CppAssembly *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_assembly_get_image");
    return fn ? fn(assembly) : NULL;
}

- (const char *)image_get_name:(Il2CppImage *)image {
    if (!image) return NULL;
    typedef const char *(*fn_t)(const Il2CppImage *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_image_get_name");
    return fn ? fn(image) : NULL;
}

- (size_t)image_get_class_count:(Il2CppImage *)image {
    if (!image) return 0;
    typedef size_t (*fn_t)(const Il2CppImage *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_image_get_class_count");
    return fn ? fn(image) : 0;
}

- (Il2CppClass *)image_get_class:(Il2CppImage *)image index:(size_t)index {
    if (!image) return NULL;
    typedef Il2CppClass *(*fn_t)(const Il2CppImage *, size_t);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_image_get_class");
    return fn ? fn(image, index) : NULL;
}

#pragma mark - Class

- (const char *)class_get_name:(Il2CppClass *)k {
    if (!k) return NULL;
    typedef const char *(*fn_t)(const Il2CppClass *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_class_get_name");
    return fn ? fn(k) : NULL;
}

- (const char *)class_get_namespace:(Il2CppClass *)k {
    if (!k) return NULL;
    typedef const char *(*fn_t)(const Il2CppClass *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_class_get_namespace");
    return fn ? fn(k) : NULL;
}

- (Il2CppClass *)class_get_parent:(Il2CppClass *)klass {
    if (!klass) return NULL;
    typedef Il2CppClass *(*fn_t)(const Il2CppClass *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_class_get_parent");
    return fn ? fn(klass) : NULL;
}

- (void *)class_get_static_field_data:(Il2CppClass *)klass {
    if (!klass) return NULL;
    typedef void *(*fn_t)(Il2CppClass *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_class_get_static_field_data");
    return fn ? fn(klass) : NULL;
}

#pragma mark - Methods / Fields / Properties

- (NSArray<NSValue *> *)class_get_methods:(Il2CppClass *)klass count:(uint16_t *)count {
    NSMutableArray<NSValue *> *arr = [NSMutableArray array];
    if (!klass) { if (count) *count = 0; return arr; }

    typedef const MethodInfo *(*fn_t)(Il2CppClass *, void **);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_class_get_methods");
    if (fn) {
        void *iter = NULL;
        const MethodInfo *m;
        int safety = 0;
        while ((m = fn(klass, &iter)) != NULL) {
            if (!m) break;
            [arr addObject:[NSValue valueWithPointer:m]];
            if (++safety > 20000) break;
        }
    }

    if (count) *count = (uint16_t)MIN(arr.count, (NSUInteger)65535);
    return arr;
}

- (NSArray<NSValue *> *)class_get_fields:(Il2CppClass *)klass count:(uint16_t *)count {
    NSMutableArray<NSValue *> *arr = [NSMutableArray array];
    if (!klass) { if (count) *count = 0; return arr; }

    typedef const FieldInfo *(*fn_t)(Il2CppClass *, void **);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_class_get_fields");
    if (fn) {
        void *iter = NULL;
        const FieldInfo *f;
        int safety = 0;
        while ((f = fn(klass, &iter)) != NULL) {
            if (!f) break;
            [arr addObject:[NSValue valueWithPointer:f]];
            if (++safety > 20000) break;
        }
    }

    if (count) *count = (uint16_t)MIN(arr.count, (NSUInteger)65535);
    return arr;
}

- (NSArray<NSValue *> *)class_get_properties:(Il2CppClass *)klass count:(uint16_t *)count {
    NSMutableArray<NSValue *> *arr = [NSMutableArray array];
    if (!klass) { if (count) *count = 0; return arr; }

    typedef const PropertyInfo *(*fn_t)(Il2CppClass *, void **);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_class_get_properties");
    if (fn) {
        void *iter = NULL;
        const PropertyInfo *p;
        int safety = 0;
        while ((p = fn(klass, &iter)) != NULL) {
            if (!p) break;
            [arr addObject:[NSValue valueWithPointer:p]];
            if (++safety > 20000) break;
        }
    }

    if (count) *count = (uint16_t)MIN(arr.count, (NSUInteger)65535);
    return arr;
}

#pragma mark - MethodInfo

- (const char *)method_get_name:(MethodInfo *)m {
    if (!m) return NULL;
    typedef const char *(*fn_t)(const MethodInfo *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_method_get_name");
    return fn ? fn(m) : NULL;
}

- (uint32_t)method_get_token:(MethodInfo *)m {
    if (!m) return 0;
    typedef uint32_t (*fn_t)(const MethodInfo *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_method_get_token");
    return fn ? fn(m) : 0;
}

- (void *)method_get_pointer:(MethodInfo *)m {
    if (!m) return NULL;
    typedef void *(*fn_t)(const MethodInfo *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_method_get_pointer");
    if (fn) return fn(m);
    // MethodInfo có field đầu tiên là methodPointer — an toàn để đọc
    return *(void **)m;
}

- (const char *)method_get_return_type:(MethodInfo *)method {
    if (!method) return NULL;
    typedef const Il2CppType *(*rt_t)(const MethodInfo *);
    rt_t rtf = (rt_t)find_sym(self.handle, "il2cpp_method_get_return_type");
    if (!rtf) return NULL;

    const Il2CppType *type = rtf(method);
    if (!type) return NULL;

    return [self type_get_name:(Il2CppType *)type];
}

- (uint32_t)method_get_flags:(MethodInfo *)method {
    if (!method) return 0;
    typedef uint32_t (*fn_t)(const MethodInfo *, uint32_t *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_method_get_flags");
    if (fn) {
        uint32_t iflags = 0;
        return fn(method, &iflags);
    }
    return 0;
}

#pragma mark - FieldInfo

- (const char *)field_get_name:(FieldInfo *)f {
    if (!f) return NULL;
    typedef const char *(*fn_t)(const FieldInfo *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_field_get_name");
    return fn ? fn(f) : NULL;
}

- (int32_t)field_get_offset:(FieldInfo *)f {
    if (!f) return 0;
    typedef size_t (*fn_t)(const FieldInfo *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_field_get_offset");
    return fn ? (int32_t)fn(f) : 0;
}

- (uint32_t)field_get_token:(FieldInfo *)f {
    if (!f) return 0;
    typedef uint32_t (*fn_t)(const FieldInfo *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_field_get_token");
    return fn ? fn(f) : 0;
}

- (const char *)field_get_type_name:(FieldInfo *)field {
    if (!field) return NULL;
    typedef const Il2CppType *(*ft_t)(const FieldInfo *);
    ft_t ftf = (ft_t)find_sym(self.handle, "il2cpp_field_get_type");
    if (!ftf) return NULL;

    const Il2CppType *type = ftf(field);
    if (!type) return NULL;

    return [self type_get_name:(Il2CppType *)type];
}

#pragma mark - PropertyInfo

- (const char *)property_get_name:(PropertyInfo *)p {
    if (!p) return NULL;
    typedef const char *(*fn_t)(const PropertyInfo *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_property_get_name");
    return fn ? fn(p) : NULL;
}

#pragma mark - Type

- (const char *)type_get_name:(Il2CppType *)type {
    if (!type) return NULL;
    typedef const char *(*fn_t)(const Il2CppType *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_type_get_name");
    if (!fn) return NULL;

    const char *name = fn(type);
    if (!name) return NULL;

    // il2cpp_type_get_name trả về chuỗi được malloc — cần free
    // Nhưng nếu return trực tiếp, caller sẽ dùng — không thể free ngay
    // → Giải pháp: trả về static buffer copy
    static char buf[512];
    strncpy(buf, name, sizeof(buf) - 1);
    buf[sizeof(buf) - 1] = '\0';

    // Free chuỗi gốc
    typedef void (*free_t)(void *);
    free_t freeFn = (free_t)find_sym(self.handle, "il2cpp_free");
    if (freeFn) freeFn((void *)name);

    return buf;
}

@end
