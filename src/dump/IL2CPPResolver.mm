#import "IL2CPPResolver.h"
#import <dlfcn.h>
#import <mach-o/dyld.h>
#include <string.h>
#include <stdio.h>
#import <mach/mach.h>

#pragma mark - Symbol finder

static void *find_sym(void *handle, const char *baseName) {
    if (!handle || !baseName) return NULL;

    void *p = dlsym(handle, baseName);
    if (p) return p;

    char buf[512];
    snprintf(buf, sizeof(buf), "_%s", baseName);
    p = dlsym(handle, buf);
    if (p) return p;

    size_t n = strlen(baseName);
    snprintf(buf, sizeof(buf), "__Z%zu%sv", n, baseName);
    p = dlsym(handle, buf);
    if (p) return p;

    p = dlsym(RTLD_DEFAULT, baseName);
    if (p) return p;

    return NULL;
}

#pragma mark - Cache

static void *g_domain_get = NULL;
static void *g_domain_get_assemblies = NULL;
static void *g_assembly_get_image = NULL;
static void *g_image_get_name = NULL;
static void *g_image_get_class_count = NULL;
static void *g_image_get_class = NULL;
static void *g_class_get_name = NULL;
static void *g_class_get_namespace = NULL;
static void *g_class_get_parent = NULL;
static void *g_class_get_static_field_data = NULL;
static void *g_class_get_flags = NULL;
static void *g_class_is_enum = NULL;
static void *g_class_is_valuetype = NULL;
static void *g_class_is_interface = NULL;
static void *g_class_get_methods = NULL;
static void *g_class_get_fields = NULL;
static void *g_class_get_properties = NULL;
static void *g_method_get_name = NULL;
static void *g_method_get_token = NULL;
static void *g_method_get_return_type = NULL;
static void *g_method_get_flags = NULL;
static void *g_method_get_param_count = NULL;
static void *g_method_get_param_name = NULL;
static void *g_method_get_param = NULL;
static void *g_field_get_name = NULL;
static void *g_field_get_offset = NULL;
static void *g_field_get_token = NULL;
static void *g_field_get_type = NULL;
static void *g_field_get_flags = NULL;
static void *g_property_get_name = NULL;
static void *g_property_get_get_method = NULL;
static void *g_property_get_set_method = NULL;
static void *g_type_get_name = NULL;
static void *g_free = NULL;
static void *g_thread_attach = NULL;

static uint64_t g_il2cpp_base = 0;

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

    if (!self.handle) return NO;

    // ===== CACHE SYMBOLS =====
    g_domain_get                    = find_sym(self.handle, "il2cpp_domain_get");
    g_domain_get_assemblies         = find_sym(self.handle, "il2cpp_domain_get_assemblies");
    g_assembly_get_image            = find_sym(self.handle, "il2cpp_assembly_get_image");
    g_image_get_name                = find_sym(self.handle, "il2cpp_image_get_name");
    g_image_get_class_count         = find_sym(self.handle, "il2cpp_image_get_class_count");
    g_image_get_class               = find_sym(self.handle, "il2cpp_image_get_class");
    g_class_get_name                = find_sym(self.handle, "il2cpp_class_get_name");
    g_class_get_namespace           = find_sym(self.handle, "il2cpp_class_get_namespace");
    g_class_get_parent              = find_sym(self.handle, "il2cpp_class_get_parent");
    g_class_get_static_field_data   = find_sym(self.handle, "il2cpp_class_get_static_field_data");
    g_class_get_flags               = find_sym(self.handle, "il2cpp_class_get_flags");
    g_class_is_enum                 = find_sym(self.handle, "il2cpp_class_is_enum");
    g_class_is_valuetype            = find_sym(self.handle, "il2cpp_class_is_valuetype");
    g_class_is_interface            = find_sym(self.handle, "il2cpp_class_is_interface");
    g_class_get_methods             = find_sym(self.handle, "il2cpp_class_get_methods");
    g_class_get_fields              = find_sym(self.handle, "il2cpp_class_get_fields");
    g_class_get_properties          = find_sym(self.handle, "il2cpp_class_get_properties");
    g_method_get_name               = find_sym(self.handle, "il2cpp_method_get_name");
    g_method_get_token              = find_sym(self.handle, "il2cpp_method_get_token");
    g_method_get_return_type        = find_sym(self.handle, "il2cpp_method_get_return_type");
    g_method_get_flags              = find_sym(self.handle, "il2cpp_method_get_flags");
    g_method_get_param_count        = find_sym(self.handle, "il2cpp_method_get_param_count");
    g_method_get_param_name         = find_sym(self.handle, "il2cpp_method_get_param_name");
    g_method_get_param              = find_sym(self.handle, "il2cpp_method_get_param");
    g_field_get_name                = find_sym(self.handle, "il2cpp_field_get_name");
    g_field_get_offset              = find_sym(self.handle, "il2cpp_field_get_offset");
    g_field_get_token               = find_sym(self.handle, "il2cpp_field_get_token");
    g_field_get_type                = find_sym(self.handle, "il2cpp_field_get_type");
    g_field_get_flags               = find_sym(self.handle, "il2cpp_field_get_flags");
    g_property_get_name             = find_sym(self.handle, "il2cpp_property_get_name");
    g_property_get_get_method       = find_sym(self.handle, "il2cpp_property_get_get_method");
    g_property_get_set_method       = find_sym(self.handle, "il2cpp_property_get_set_method");
    g_type_get_name                 = find_sym(self.handle, "il2cpp_type_get_name");
    g_free                          = find_sym(self.handle, "il2cpp_free");
    g_thread_attach                 = find_sym(self.handle, "il2cpp_thread_attach");

    // ===== Base address của UnityFramework — dùng để tính RVA =====
    if (g_domain_get) {
        Dl_info info;
        if (dladdr(g_domain_get, &info)) {
            g_il2cpp_base = (uint64_t)info.dli_fbase;
        }
    }
    if (g_il2cpp_base == 0 && g_domain_get_assemblies) {
        Dl_info info;
        if (dladdr(g_domain_get_assemblies, &info)) {
            g_il2cpp_base = (uint64_t)info.dli_fbase;
        }
    }
    if (g_il2cpp_base == 0) {
        uint32_t count = _dyld_image_count();
        for (uint32_t i = 0; i < count; i++) {
            const char *name = _dyld_get_image_name(i);
            if (name && (strstr(name, "UnityFramework") ||
                         strstr(name, "GameAssembly"))) {
                const struct mach_header *hdr = _dyld_get_image_header(i);
                intptr_t slide = _dyld_get_image_vmaddr_slide(i);
                if (hdr) {
                    g_il2cpp_base = (uint64_t)((uintptr_t)hdr) + slide;
                    break;
                }
            }
        }
    }

    return YES;
}

- (BOOL)isResolved { return self.handle != NULL; }

- (uint64_t)il2cppBase { return g_il2cpp_base; }

#pragma mark - Thread

- (void)attachCurrentThread {
    if (!g_domain_get || !g_thread_attach) return;
    if ([NSThread isMainThread]) return;

    typedef Il2CppDomain *(*dg_t)(void);
    Il2CppDomain *domain = ((dg_t)g_domain_get)();
    if (!domain) return;

    typedef void *(*ta_t)(Il2CppDomain *);
    ((ta_t)g_thread_attach)(domain);
}

#pragma mark - Domain

- (Il2CppDomain *)domain_get {
    if (!g_domain_get) return NULL;
    typedef Il2CppDomain *(*fn_t)(void);
    return ((fn_t)g_domain_get)();
}

- (const Il2CppAssembly **)domain_get_assemblies:(Il2CppDomain *)domain count:(size_t *)count {
    if (!domain || !g_domain_get_assemblies) { if (count) *count = 0; return NULL; }

    typedef const Il2CppAssembly **(*fn_t)(const Il2CppDomain *, size_t *);
    size_t sz = 0;
    const Il2CppAssembly **asm_ = ((fn_t)g_domain_get_assemblies)(domain, &sz);
    if (count) *count = sz;
    return asm_;
}

- (const Il2CppAssembly **)domain_get_assemblies:(Il2CppDomain *)domain count:(int *)count {
    size_t sz = 0;
    const Il2CppAssembly **asm_ = [self domain_get_assemblies:domain count:&sz];
    if (count) *count = (int)sz;
    return asm_;
}

#pragma mark - Image

- (Il2CppImage *)assembly_get_image:(Il2CppAssembly *)assembly {
    if (!assembly || !g_assembly_get_image) return NULL;
    typedef Il2CppImage *(*fn_t)(const Il2CppAssembly *);
    return ((fn_t)g_assembly_get_image)(assembly);
}

- (const char *)image_get_name:(Il2CppImage *)image {
    if (!image || !g_image_get_name) return NULL;
    typedef const char *(*fn_t)(const Il2CppImage *);
    return ((fn_t)g_image_get_name)(image);
}

- (size_t)image_get_class_count:(Il2CppImage *)image {
    if (!image || !g_image_get_class_count) return 0;
    typedef size_t (*fn_t)(const Il2CppImage *);
    return ((fn_t)g_image_get_class_count)(image);
}

- (Il2CppClass *)image_get_class:(Il2CppImage *)image index:(size_t)index {
    if (!image || !g_image_get_class) return NULL;
    typedef Il2CppClass *(*fn_t)(const Il2CppImage *, size_t);
    return ((fn_t)g_image_get_class)(image, index);
}

#pragma mark - Class

- (const char *)class_get_name:(Il2CppClass *)k {
    if (!k || !g_class_get_name) return NULL;
    typedef const char *(*fn_t)(const Il2CppClass *);
    return ((fn_t)g_class_get_name)(k);
}

- (const char *)class_get_namespace:(Il2CppClass *)k {
    if (!k || !g_class_get_namespace) return NULL;
    typedef const char *(*fn_t)(const Il2CppClass *);
    return ((fn_t)g_class_get_namespace)(k);
}

- (Il2CppClass *)class_get_parent:(Il2CppClass *)klass {
    if (!klass || !g_class_get_parent) return NULL;
    typedef Il2CppClass *(*fn_t)(const Il2CppClass *);
    return ((fn_t)g_class_get_parent)(klass);
}

- (void *)class_get_static_field_data:(Il2CppClass *)klass {
    if (!klass || !g_class_get_static_field_data) return NULL;
    typedef void *(*fn_t)(Il2CppClass *);
    return ((fn_t)g_class_get_static_field_data)(klass);
}

- (uint32_t)class_get_flags:(Il2CppClass *)klass {
    if (!klass || !g_class_get_flags) return 0;
    typedef int (*fn_t)(const Il2CppClass *);
    return (uint32_t)((fn_t)g_class_get_flags)(klass);
}

- (BOOL)class_is_enum:(Il2CppClass *)klass {
    if (!klass || !g_class_is_enum) return NO;
    typedef bool (*fn_t)(const Il2CppClass *);
    return ((fn_t)g_class_is_enum)(klass) ? YES : NO;
}

- (BOOL)class_is_valuetype:(Il2CppClass *)klass {
    if (!klass || !g_class_is_valuetype) return NO;
    typedef bool (*fn_t)(const Il2CppClass *);
    return ((fn_t)g_class_is_valuetype)(klass) ? YES : NO;
}

- (BOOL)class_is_interface:(Il2CppClass *)klass {
    if (!klass || !g_class_is_interface) return NO;
    typedef bool (*fn_t)(const Il2CppClass *);
    return ((fn_t)g_class_is_interface)(klass) ? YES : NO;
}

#pragma mark - Methods / Fields / Properties

- (NSArray<NSValue *> *)class_get_methods:(Il2CppClass *)klass count:(uint16_t *)count {
    NSMutableArray<NSValue *> *arr = [NSMutableArray array];
    if (!klass || !g_class_get_methods) { if (count) *count = 0; return arr; }

    typedef const MethodInfo *(*fn_t)(Il2CppClass *, void **);
    fn_t fn = (fn_t)g_class_get_methods;

    void *iter = NULL;
    const MethodInfo *m;
    int safety = 0;
    while ((m = fn(klass, &iter)) != NULL) {
        if (!m) break;
        [arr addObject:[NSValue valueWithPointer:m]];
        if (++safety > 20000) break;
    }

    if (count) *count = (uint16_t)MIN(arr.count, (NSUInteger)65535);
    return arr;
}

- (NSArray<NSValue *> *)class_get_fields:(Il2CppClass *)klass count:(uint16_t *)count {
    NSMutableArray<NSValue *> *arr = [NSMutableArray array];
    if (!klass || !g_class_get_fields) { if (count) *count = 0; return arr; }

    typedef const FieldInfo *(*fn_t)(Il2CppClass *, void **);
    fn_t fn = (fn_t)g_class_get_fields;

    void *iter = NULL;
    const FieldInfo *f;
    int safety = 0;
    while ((f = fn(klass, &iter)) != NULL) {
        if (!f) break;
        [arr addObject:[NSValue valueWithPointer:f]];
        if (++safety > 20000) break;
    }

    if (count) *count = (uint16_t)MIN(arr.count, (NSUInteger)65535);
    return arr;
}

- (NSArray<NSValue *> *)class_get_properties:(Il2CppClass *)klass count:(uint16_t *)count {
    NSMutableArray<NSValue *> *arr = [NSMutableArray array];
    if (!klass || !g_class_get_properties) { if (count) *count = 0; return arr; }

    typedef const PropertyInfo *(*fn_t)(Il2CppClass *, void **);
    fn_t fn = (fn_t)g_class_get_properties;

    void *iter = NULL;
    const PropertyInfo *p;
    int safety = 0;
    while ((p = fn(klass, &iter)) != NULL) {
        if (!p) break;
        [arr addObject:[NSValue valueWithPointer:p]];
        if (++safety > 20000) break;
    }

    if (count) *count = (uint16_t)MIN(arr.count, (NSUInteger)65535);
    return arr;
}

#pragma mark - MethodInfo

- (const char *)method_get_name:(MethodInfo *)m {
    if (!m || !g_method_get_name) return NULL;
    typedef const char *(*fn_t)(const MethodInfo *);
    return ((fn_t)g_method_get_name)(m);
}

- (uint32_t)method_get_token:(MethodInfo *)m {
    if (!m || !g_method_get_token) return 0;
    typedef uint32_t (*fn_t)(const MethodInfo *);
    return ((fn_t)g_method_get_token)(m);
}

- (void *)method_get_pointer:(MethodInfo *)m {
    if (!m) return NULL;
    return m->methodPointer;
}

- (const char *)method_get_return_type:(MethodInfo *)method {
    if (!method || !g_method_get_return_type || !g_type_get_name) return NULL;

    typedef const Il2CppType *(*rt_t)(const MethodInfo *);
    const Il2CppType *type = ((rt_t)g_method_get_return_type)(method);
    if (!type) return NULL;

    typedef const char *(*tn_t)(const Il2CppType *);
    const char *name = ((tn_t)g_type_get_name)(type);
    if (!name) return NULL;

    static char buf[512];
    strncpy(buf, name, sizeof(buf) - 1);
    buf[sizeof(buf) - 1] = '\0';

    if (g_free) {
        typedef void (*fr_t)(void *);
        ((fr_t)g_free)((void *)name);
    }
    return buf;
}

- (uint32_t)method_get_flags:(MethodInfo *)method {
    if (!method || !g_method_get_flags) return 0;
    typedef uint32_t (*fn_t)(const MethodInfo *, uint32_t *);
    uint32_t iflags = 0;
    return ((fn_t)g_method_get_flags)(method, &iflags);
}

- (uint32_t)method_get_param_count:(MethodInfo *)method {
    if (!method || !g_method_get_param_count) return 0;
    typedef uint32_t (*fn_t)(const MethodInfo *);
    return ((fn_t)g_method_get_param_count)(method);
}

- (const char *)method_get_param_name:(MethodInfo *)method index:(uint32_t)index {
    if (!method || !g_method_get_param_name) return NULL;
    typedef const char *(*fn_t)(const MethodInfo *, uint32_t);
    return ((fn_t)g_method_get_param_name)(method, index);
}

- (const char *)method_get_param_type_name:(MethodInfo *)method index:(uint32_t)index {
    if (!method || !g_method_get_param || !g_type_get_name) return NULL;

    typedef const Il2CppType *(*fn_t)(const MethodInfo *, uint32_t);
    const Il2CppType *type = ((fn_t)g_method_get_param)(method, index);
    if (!type) return NULL;

    typedef const char *(*tn_t)(const Il2CppType *);
    const char *name = ((tn_t)g_type_get_name)(type);
    if (!name) return NULL;

    static char buf[512];
    strncpy(buf, name, sizeof(buf) - 1);
    buf[sizeof(buf) - 1] = '\0';

    if (g_free) {
        typedef void (*fr_t)(void *);
        ((fr_t)g_free)((void *)name);
    }
    return buf;
}

#pragma mark - FieldInfo

- (const char *)field_get_name:(FieldInfo *)f {
    if (!f || !g_field_get_name) return NULL;
    typedef const char *(*fn_t)(const FieldInfo *);
    return ((fn_t)g_field_get_name)(f);
}

- (int32_t)field_get_offset:(FieldInfo *)f {
    if (!f || !g_field_get_offset) return 0;
    typedef size_t (*fn_t)(const FieldInfo *);
    return (int32_t)((fn_t)g_field_get_offset)(f);
}

- (uint32_t)field_get_token:(FieldInfo *)f {
    if (!f || !g_field_get_token) return 0;
    typedef uint32_t (*fn_t)(const FieldInfo *);
    return ((fn_t)g_field_get_token)(f);
}

- (const char *)field_get_type_name:(FieldInfo *)field {
    if (!field || !g_field_get_type || !g_type_get_name) return NULL;

    typedef const Il2CppType *(*ft_t)(const FieldInfo *);
    const Il2CppType *type = ((ft_t)g_field_get_type)(field);
    if (!type) return NULL;

    typedef const char *(*tn_t)(const Il2CppType *);
    const char *name = ((tn_t)g_type_get_name)(type);
    if (!name) return NULL;

    static char buf[512];
    strncpy(buf, name, sizeof(buf) - 1);
    buf[sizeof(buf) - 1] = '\0';

    if (g_free) {
        typedef void (*fr_t)(void *);
        ((fr_t)g_free)((void *)name);
    }
    return buf;
}

- (uint32_t)field_get_flags:(FieldInfo *)field {
    if (!field || !g_field_get_flags) return 0;
    typedef int (*fn_t)(FieldInfo *);
    return (uint32_t)((fn_t)g_field_get_flags)(field);
}

#pragma mark - PropertyInfo

- (const char *)property_get_name:(PropertyInfo *)p {
    if (!p || !g_property_get_name) return NULL;
    typedef const char *(*fn_t)(const PropertyInfo *);
    return ((fn_t)g_property_get_name)(p);
}

- (MethodInfo *)property_get_get_method:(PropertyInfo *)p {
    if (!p || !g_property_get_get_method) return nil;
    typedef const MethodInfo *(*fn_t)(PropertyInfo *);
    return (MethodInfo *)((fn_t)g_property_get_get_method)(p);
}

- (MethodInfo *)property_get_set_method:(PropertyInfo *)p {
    if (!p || !g_property_get_set_method) return nil;
    typedef const MethodInfo *(*fn_t)(PropertyInfo *);
    return (MethodInfo *)((fn_t)g_property_get_set_method)(p);
}

#pragma mark - Type

- (const char *)type_get_name:(Il2CppType *)type {
    if (!type || !g_type_get_name) return NULL;

    typedef const char *(*fn_t)(const Il2CppType *);
    const char *name = ((fn_t)g_type_get_name)(type);
    if (!name) return NULL;

    static char buf[512];
    strncpy(buf, name, sizeof(buf) - 1);
    buf[sizeof(buf) - 1] = '\0';

    if (g_free) {
        typedef void (*fr_t)(void *);
        ((fr_t)g_free)((void *)name);
    }
    return buf;
}

#pragma mark - Memory Operations (Bổ sung cho CHookVC)

+ (uintptr_t)getRealOffset:(uintptr_t)offset {
    uintptr_t slide = _dyld_get_image_vmaddr_slide(0);
    const struct mach_header_64 *header = (const struct mach_header_64 *)_dyld_get_image_header(0);
    return (uintptr_t)header + slide + offset;
}

+ (BOOL)writeFloat:(uintptr_t)address value:(float)value {
    mach_port_t task = mach_task_self();
    vm_prot_t oldProt;
    kern_return_t kr = vm_protect(task, (vm_address_t)address & ~(vm_page_size - 1), vm_page_size, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    if (kr != KERN_SUCCESS) return NO;
    *(float *)address = value;
    vm_protect(task, (vm_address_t)address & ~(vm_page_size - 1), vm_page_size, FALSE, oldProt);
    return YES;
}

+ (BOOL)writeInt32:(uintptr_t)address value:(int32_t)value {
    mach_port_t task = mach_task_self();
    vm_prot_t oldProt;
    kern_return_t kr = vm_protect(task, (vm_address_t)address & ~(vm_page_size - 1), vm_page_size, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    if (kr != KERN_SUCCESS) return NO;
    *(int32_t *)address = value;
    vm_protect(task, (vm_address_t)address & ~(vm_page_size - 1), vm_page_size, FALSE, oldProt);
    return YES;
}

+ (float)readFloat:(uintptr_t)address {
    return *(float *)address;
}

+ (int32_t)readInt32:(uintptr_t)address {
    return *(int32_t *)address;
}

@end
