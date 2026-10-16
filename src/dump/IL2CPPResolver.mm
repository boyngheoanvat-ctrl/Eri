#import "IL2CPPResolver.h"
#import <dlfcn.h>
#import <mach-o/dyld.h>
#include <string.h>
#include <stdio.h>
#import <mach/mach.h>

static void *find_sym(void *handle, const char *baseName) {
    if (!handle || !baseName) return NULL;
    void *p = dlsym(handle, baseName);
    if (p) return p;
    char buf[512];
    snprintf(buf, sizeof(buf), "_%s", baseName);
    p = dlsym(handle, buf);
    if (p) return p;
    return NULL;
}

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
    @autoreleasepool {
        if (self.handle) return YES;
        const char *paths[] = {
            "@executable_path/Frameworks/UnityFramework.framework/UnityFramework",
            "@executable_path/Frameworks/il2cpp.framework/il2cpp",
            "UnityFramework", NULL
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
        if (!self.handle) return NO;

        g_domain_get = find_sym(self.handle, "il2cpp_domain_get");
        g_domain_get_assemblies = find_sym(self.handle, "il2cpp_domain_get_assemblies");
        g_assembly_get_image = find_sym(self.handle, "il2cpp_assembly_get_image");
        g_image_get_class_count = find_sym(self.handle, "il2cpp_image_get_class_count");
        g_image_get_class = find_sym(self.handle, "il2cpp_image_get_class");
        g_class_get_name = find_sym(self.handle, "il2cpp_class_get_name");
        g_class_get_methods = find_sym(self.handle, "il2cpp_class_get_methods");
        g_class_get_fields = find_sym(self.handle, "il2cpp_class_get_fields");
        g_method_get_name = find_sym(self.handle, "il2cpp_method_get_name");
        g_field_get_offset = find_sym(self.handle, "il2cpp_field_get_offset");

        if (g_domain_get) {
            Dl_info info;
            if (dladdr(g_domain_get, &info)) g_il2cpp_base = (uint64_t)info.dli_fbase;
        }
        return YES;
    }
}

- (BOOL)isResolved { @autoreleasepool { return self.handle != NULL; } }
- (uint64_t)il2cppBase { @autoreleasepool { return g_il2cpp_base; } }

- (Il2CppDomain *)domain_get {
    @autoreleasepool {
        if (!g_domain_get) return NULL;
        return ((Il2CppDomain *(*)(void))g_domain_get)();
    }
}

- (const Il2CppAssembly **)domain_get_assemblies:(Il2CppDomain *)domain count:(size_t *)count {
    @autoreleasepool {
        if (!domain || !g_domain_get_assemblies) { if (count) *count = 0; return NULL; }
        size_t sz = 0;
        const Il2CppAssembly **asm_ = ((const Il2CppAssembly **(*)(const Il2CppDomain *, size_t *))g_domain_get_assemblies)(domain, &sz);
        if (count) *count = sz;
        return asm_;
    }
}

- (Il2CppImage *)assembly_get_image:(Il2CppAssembly *)assembly {
    @autoreleasepool {
        if (!assembly || !g_assembly_get_image) return NULL;
        return ((Il2CppImage *(*)(const Il2CppAssembly *))g_assembly_get_image)(assembly);
    }
}

- (size_t)image_get_class_count:(Il2CppImage *)image {
    @autoreleasepool {
        if (!image || !g_image_get_class_count) return 0;
        return ((size_t (*)(const Il2CppImage *))g_image_get_class_count)(image);
    }
}

- (Il2CppClass *)image_get_class:(Il2CppImage *)image index:(size_t)index {
    @autoreleasepool {
        if (!image || !g_image_get_class) return NULL;
        return ((Il2CppClass *(*)(const Il2CppImage *, size_t))g_image_get_class)(image, index);
    }
}

- (const char *)class_get_name:(Il2CppClass *)k {
    @autoreleasepool {
        if (!k || !g_class_get_name) return NULL;
        return ((const char *(*)(const Il2CppClass *))g_class_get_name)(k);
    }
}

- (NSArray<NSValue *> *)class_get_methods:(Il2CppClass *)klass count:(uint16_t *)count {
    @autoreleasepool {
        NSMutableArray<NSValue *> *arr = [NSMutableArray array];
        if (!klass || !g_class_get_methods) { if (count) *count = 0; return arr; }
        void *iter = NULL;
        const MethodInfo *m;
        int safety = 0;
        while ((m = ((const MethodInfo *(*)(Il2CppClass *, void **))g_class_get_methods)(klass, &iter)) != NULL) {
            [arr addObject:[NSValue valueWithPointer:m]];
            if (++safety > 20000) break;
        }
        if (count) *count = (uint16_t)MIN(arr.count, (NSUInteger)65535);
        return arr;
    }
}

+ (uintptr_t)getRealOffset:(uintptr_t)offset {
    @autoreleasepool {
        uintptr_t slide = _dyld_get_image_vmaddr_slide(0);
        const struct mach_header_64 *header = (const struct mach_header_64 *)_dyld_get_image_header(0);
        return (uintptr_t)header + slide + offset;
    }
}

+ (BOOL)writeFloat:(uintptr_t)address value:(float)value {
    @autoreleasepool {
        mach_port_t task = mach_task_self();
        vm_prot_t oldProt;
        kern_return_t kr = vm_protect(task, (vm_address_t)address & ~(vm_page_size - 1), vm_page_size, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
        if (kr != KERN_SUCCESS) return NO;
        *(float *)address = value;
        vm_protect(task, (vm_address_t)address & ~(vm_page_size - 1), vm_page_size, FALSE, oldProt);
        return YES;
    }
}

+ (float)readFloat:(uintptr_t)address { @autoreleasepool { return *(float *)address; } }

@end
