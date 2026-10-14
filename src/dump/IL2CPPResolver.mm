#import "IL2CPPResolver.h"
#import <dlfcn.h>
#import <mach-o/dyld.h>
#include <string.h>
#include <stdio.h>

#pragma mark - Symbol lookup helper

// Thử nhiều biến thể tên symbol: C, _C, C++ mangled (một số dạng phổ biến)
static void *find_sym(void *handle, const char *baseName) {
    if (!handle || !baseName) return NULL;

    // 1) Tên C thuần
    void *p = dlsym(handle, baseName);
    if (p) return p;

    // 2) Mach-O C: thêm '_'
    char buf[512];
    snprintf(buf, sizeof(buf), "_%s", baseName);
    p = dlsym(handle, buf);
    if (p) return p;

    // 3) Itanium C++ mangled cho hàm không tham số: __Z<len><name>v
    size_t n = strlen(baseName);
    snprintf(buf, sizeof(buf), "__Z%zu%sv", n, baseName);
    p = dlsym(handle, buf);
    if (p) return p;

    // 4) Thử RTLD_DEFAULT (trường hợp symbol ở image khác)
    p = dlsym(RTLD_DEFAULT, baseName);
    if (p) return p;
    snprintf(buf, sizeof(buf), "_%s", baseName);
    p = dlsym(RTLD_DEFAULT, buf);
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
        if (self.handle) break;
    }

    if (!self.handle) {
        uint32_t count = _dyld_image_count();
        for (uint32_t i = 0; i < count; i++) {
            const char *name = _dyld_get_image_name(i);
            if (name && (strstr(name, "UnityFramework") ||
                         strstr(name, "il2cpp") ||
                         strstr(name, "GameAssembly"))) {
                self.handle = dlopen(name, RTLD_NOW);
                if (self.handle) break;
            }
        }
    }

    return self.handle != NULL;
}

- (BOOL)isResolved { return self.handle != NULL; }

#pragma mark - Core

- (Il2CppDomain *)domain_get {
    if (!self.handle) return NULL;
    typedef Il2CppDomain *(*fn_t)(void);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_domain_get");
    return fn ? fn() : NULL;
}

- (Il2CppImage *)assembly_get_image:(Il2CppAssembly *)assembly {
    if (!assembly) return NULL;

    // Ưu tiên 1: dlsym il2cpp_assembly_get_image
    typedef Il2CppImage *(*fn_t)(const Il2CppAssembly *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_assembly_get_image");
    if (fn) return fn(assembly);

    // Ưu tiên 2: fallback đọc offset.
    // Theo Unity 2019-2022: Il2CppAssembly { Il2CppImage *image; ... }
    //   offset 0x0 chứa con trỏ image.
    // Nếu version khác -> sửa offset cho khớp il2cpp.h.
    // Chỉ dùng khi bạn CHẮC CHẮN về layout.
    // return *(Il2CppImage **)((uint8_t *)assembly + 0x0);

    // An toàn: trả NULL thay vì đoán mò (DumperVC sẽ skip assembly này)
    return NULL;
}

- (const char *)image_get_name:(Il2CppImage *)image {
    if (!image) return NULL;

    typedef const char *(*fn_t)(const Il2CppImage *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_image_get_name");
    if (fn) return fn(image);

    // Fallback: đọc field name ở offset 0x8 (Unity 2019+)
    // Il2CppImage { const char *name; ... }
    // return *(const char **)((uint8_t *)image + 0x8);

    return NULL;
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
    if (fn) return fn(k);

    // Fallback đọc struct
    return k->name;
}

- (const char *)class_get_namespace:(Il2CppClass *)k {
    if (!k) return NULL;

    typedef const char *(*fn_t)(const Il2CppClass *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_class_get_namespace");
    if (fn) return fn(k);

    return k->namespaze;
}

- (Il2CppClass *)class_get_parent:(Il2CppClass *)klass {
    if (!klass) return NULL;

    typedef Il2CppClass *(*fn_t)(const Il2CppClass *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_class_get_parent");
    if (fn) return fn(klass);

    return klass->parent;
}

#pragma mark - Methods / Fields / Properties (trả NSArray, không cần free)

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
            if (++safety > 65535) break;  // chống vòng lặp vô hạn
        }
    } else {
        // Fallback: đọc trực tiếp từ struct (ít tin cậy)
        uint16_t total = klass->method_count;
        const MethodInfo **list = (const MethodInfo **)klass->methods;
        if (list && total > 0 && total < 65535) {
            for (uint16_t i = 0; i < total; i++) {
                if (list[i]) [arr addObject:[NSValue valueWithPointer:list[i]]];
            }
        }
    }

    if (count) *count = (uint16_t)MIN(arr.count, 65535);
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
            if (++safety > 65535) break;
        }
    }

    if (count) *count = (uint16_t)MIN(arr.count, 65535);
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
            if (++safety > 65535) break;
        }
    }

    if (count) *count = (uint16_t)MIN(arr.count, 65535);
    return arr;
}

#pragma mark - MethodInfo

- (const char *)method_get_name:(MethodInfo *)m {
    if (!m) return NULL;
    typedef const char *(*fn_t)(const MethodInfo *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_method_get_name");
    if (fn) return fn(m);

    // MethodInfo { const char *name; ... } offset 0x0 (Unity 2019+)
    return *(const char **)((uint8_t *)m + 0x0);
}

- (uint32_t)method_get_token:(MethodInfo *)m {
    if (!m) return 0;
    typedef uint32_t (*fn_t)(const MethodInfo *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_method_get_token");
    if (fn) return fn(m);

    // MethodInfo { ... uint32_t token; } offset 0x34 (Unity 2019+) — đoán, dùng fn nếu có
    return 0;
}

- (void *)method_get_pointer:(MethodInfo *)m {
    if (!m) return NULL;
    typedef void *(*fn_t)(const MethodInfo *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_method_get_pointer");
    if (fn) return fn(m);

    // Fallback: methodPointer thường ở offset 0x0 hoặc 0x8
    return NULL;  // không đoán — trả NULL, DumperVC sẽ in RVA=0
}

- (const char *)method_get_return_type:(MethodInfo *)method {
    if (!method) return NULL;
    typedef const char *(*fn_t)(const MethodInfo *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_method_get_return_type");
    if (fn) return fn(method);
    return NULL;
}

#pragma mark - FieldInfo

- (const char *)field_get_name:(FieldInfo *)f {
    if (!f) return NULL;
    typedef const char *(*fn_t)(const FieldInfo *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_field_get_name");
    if (fn) return fn(f);
    return NULL;
}

- (int32_t)field_get_offset:(FieldInfo *)f {
    if (!f) return 0;
    typedef int32_t (*fn_t)(const FieldInfo *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_field_get_offset");
    if (fn) return fn(f);
    return 0;
}

- (uint32_t)field_get_token:(FieldInfo *)f {
    if (!f) return 0;
    typedef uint32_t (*fn_t)(const FieldInfo *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_field_get_token");
    if (fn) return fn(f);
    return 0;
}

- (const char *)field_get_type_name:(FieldInfo *)field {
    if (!field) return NULL;
    typedef const char *(*fn_t)(const FieldInfo *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_field_get_type");
    if (!fn) return NULL;
    void *type = (void *)fn(field);
    if (!type) return NULL;
    return [self type_get_name:(Il2CppType *)type];
}

#pragma mark - PropertyInfo

- (const char *)property_get_name:(PropertyInfo *)p {
    if (!p) return NULL;
    typedef const char *(*fn_t)(const PropertyInfo *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_property_get_name");
    if (fn) return fn(p);
    return NULL;
}

#pragma mark - Type

- (const char *)type_get_name:(Il2CppType *)type {
    if (!type) return NULL;
    typedef const char *(*fn_t)(const Il2CppType *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_type_get_name");
    if (fn) return fn(type);
    return NULL;
}

@end
