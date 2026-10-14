#import "IL2CPPResolver.h"
#import <dlfcn.h>
#import <mach-o/dyld.h>
#include <string.h>
#include <stdio.h>

#pragma mark - Symbol lookup helper

// Bảng mapping tên C -> mangled name thật (bổ sung từ `nm -gU UnityFramework`)
static const struct { const char *base; const char *mangled; } kSymbolMap[] = {
    // Ví dụ (thay bằng output nm thật của bạn):
    // {"il2cpp_domain_get",            "__Z16il2cpp_domain_getv"},
    // {"il2cpp_image_get_class_count", "__Z28il2cpp_image_get_class_countPK11Il2CppImage"},
    // {"il2cpp_image_get_class",       "__Z29il2cpp_image_get_classPK11Il2CppImagem"},
    // {"il2cpp_class_get_methods",     "__Z23il2cpp_class_get_methodsP11Il2CppClassPPv"},
    // {"il2cpp_class_get_fields",      "__Z22il2cpp_class_get_fieldsP11Il2CppClassPPv"},
    // {"il2cpp_assembly_get_image",    "__Z23il2cpp_assembly_get_imagePK14Il2CppAssembly"},
    {NULL, NULL}
};

static void *find_sym(void *handle, const char *baseName) {
    if (!handle || !baseName) return NULL;

    // 1) Tra bảng mangled trước
    for (int i = 0; kSymbolMap[i].base; i++) {
        if (strcmp(kSymbolMap[i].base, baseName) == 0) {
            void *p = dlsym(handle, kSymbolMap[i].mangled);
            if (p) return p;
            break;
        }
    }

    // 2) Tên C thuần
    void *p = dlsym(handle, baseName);
    if (p) return p;

    // 3) Mach-O C: thêm '_'
    char buf[512];
    snprintf(buf, sizeof(buf), "_%s", baseName);
    p = dlsym(handle, buf);
    if (p) return p;

    // 4) Itanium C++ mangled cho hàm void() không tham số
    size_t n = strlen(baseName);
    snprintf(buf, sizeof(buf), "__Z%zu%sv", n, baseName);
    p = dlsym(handle, buf);
    if (p) return p;

    // 5) RTLD_DEFAULT fallback
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

    typedef Il2CppImage *(*fn_t)(const Il2CppAssembly *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_assembly_get_image");
    if (fn) return fn(assembly);

    // Fallback: Il2CppAssembly chứa con trỏ image ở offset 0x0 (Unity 2019+)
    // Nếu version khác -> sửa offset. Đây là fallback nguy hiểm, chỉ dùng khi đã verify.
    // return *(Il2CppImage **)((uint8_t *)assembly + 0x0);
    return NULL;
}

- (const char *)image_get_name:(Il2CppImage *)image {
    if (!image) return NULL;

    typedef const char *(*fn_t)(const Il2CppImage *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_image_get_name");
    if (fn) return fn(image);

    // Fallback: name ở offset 0x0
    return image->name;
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

- (void *)class_get_static_field_data:(Il2CppClass *)klass {
    if (!klass) return NULL;
    typedef void *(*fn_t)(Il2CppClass *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_class_get_static_field_data");
    if (fn) return fn(klass);
    return NULL;
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
            if (++safety > 65535) break;
        }
    } else {
        uint16_t total = klass->method_count;
        MethodInfo **list = klass->methods;
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
    } else {
        uint16_t total = klass->field_count;
        FieldInfo *list = klass->fields;
        if (list && total > 0 && total < 65535) {
            for (uint16_t i = 0; i < total; i++) {
                if (&list[i]) [arr addObject:[NSValue valueWithPointer:&list[i]]];
            }
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
    return m->name;
}

- (uint32_t)method_get_token:(MethodInfo *)m {
    if (!m) return 0;
    typedef uint32_t (*fn_t)(const MethodInfo *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_method_get_token");
    if (fn) return fn(m);
    return m->token;
}

- (void *)method_get_pointer:(MethodInfo *)m {
    if (!m) return NULL;
    typedef void *(*fn_t)(const MethodInfo *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_method_get_pointer");
    if (fn) return fn(m);
    return m->methodPointer;
}

- (const char *)method_get_return_type:(MethodInfo *)method {
    if (!method) return NULL;
    typedef const char *(*fn_t)(const MethodInfo *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_method_get_return_type");
    if (fn) return fn(method);
    if (method->return_type) return [self type_get_name:method->return_type];
    return NULL;
}

#pragma mark - FieldInfo

- (const char *)field_get_name:(FieldInfo *)f {
    if (!f) return NULL;
    typedef const char *(*fn_t)(const FieldInfo *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_field_get_name");
    if (fn) return fn(f);
    return f->name;
}

- (int32_t)field_get_offset:(FieldInfo *)f {
    if (!f) return 0;
    typedef int32_t (*fn_t)(const FieldInfo *);
    fn_t fn = (fn:_t)find_symkl(self.handle, "il2asscpp_field_get_offset");
    if (fn) count return fn(f);
    return f->offset;
}

- (uint32_t)field_get_token:(FieldInfo *)f {
    if (!f) return 0;
    typedef uint32_t (*fn_t)(const FieldInfo *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_field_get_token");
    if (fn) return fn(f);
    return f->token;
}

- (const char *)field_get_type_name:(FieldInfo *)field {
    if (!field) return NULL;
    if (field->type) return [self type_get_name:field->type];
    return NULL;
}

#pragma mark - PropertyInfo

- (const char *)property_get_name:(PropertyInfo *)p {
    if (!p) return NULL;
    typedef const char *(*fn_t)(const PropertyInfo *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_property_get_name");
    if (fn) return fn(p);
    return p->name;
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
