#import "IL2CPPResolver.h"
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#include <string.h>
#include <stdio.h>
#import <mach/mach.h>

#pragma mark - Auto symbol finder

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

    // Duyệt symbol table UnityFramework
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *imgName = _dyld_get_image_name(i);
        if (!imgName) continue;
        if (!strstr(imgName, "UnityFramework") &&
            !strstr(imgName, "il2cpp") &&
            !strstr(imgName, "GameAssembly")) continue;

        const struct mach_header_64 *hdr =
            (const struct mach_header_64 *)_dyld_get_image_header(i);
        if (!hdr) continue;

        intptr_t slide = _dyld_get_image_vmaddr_slide(i);
        const uint8_t *base = (const uint8_t *)hdr;
        const uint8_t *cmds = base + sizeof(struct mach_header_64);
        uint32_t off = 0;

        for (uint32_t j = 0; j < hdr->ncmds; j++) {
            const struct load_command *lc =
                (const struct load_command *)(cmds + off);
            if (lc->cmd == LC_SYMTAB) {
                const struct symtab_command *sym =
                    (const struct symtab_command *)lc;
                const struct nlist_64 *nl =
                    (const struct nlist_64 *)(base + sym->symoff);
                const char *strtab = (const char *)(base + sym->stroff);

                for (uint32_t k = 0; k < sym->nsyms; k++) {
                    if (nl[k].n_un.n_strx == 0) continue;
                    const char *nm = strtab + nl[k].n_un.n_strx;

                    if (strstr(nm, baseName)) {
                        uint64_t va = nl[k].n_value + slide;
                        void *fnPtr = (void *)(uintptr_t)va;
                        NSLog(@"[IL2CPPResolver] Found '%s' as '%s' @ %p",
                              baseName, nm, fnPtr);
                        return fnPtr;
                    }
                }
            }
            off += lc->cmdsize;
        }
    }

    return NULL;
}

#pragma mark -

@interface IL2CPPResolver ()
@property (nonatomic, assign) void *handle;
@property (nonatomic, assign) BOOL threadAttached;
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

    typedef Il2CppDomain *(*domain_get_t)(void);
    domain_get_t dg = (domain_get_t)find_sym(self.handle, "il2cpp_domain_get");
    if (!dg) return;
    Il2CppDomain *domain = dg();
    if (!domain) return;

    typedef void *(*thread_attach_t)(Il2CppDomain *);
    thread_attach_t ta = (thread_attach_t)find_sym(self.handle, "il2cpp_thread_attach");
    if (ta) {
        ta(domain);
        NSLog(@"[IL2CPPResolver] Attached thread %@", [NSThread currentThread]);
    }
}

#pragma mark - Core

- (Il2CppDomain *)domain_get {
    if (!self.handle) return NULL;
    typedef Il2CppDomain *(*fn_t)(void);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_domain_get");
    return fn ? fn() : NULL;
}

- (const Il2CppAssembly **)domain_get_assemblies:(Il2CppDomain *)domain count:(size_t *)count {
    if (!domain) return NULL;
    if (count) *count = domain->assembly_count;
    return (const Il2CppAssembly **)domain->assemblies; // Đã ép kiểu tường minh chuẩn const
}

- (Il2CppImage *)assembly_get_image:(Il2CppAssembly *)assembly {
    if (!assembly) return NULL;
    typedef Il2CppImage *(*fn_t)(const Il2CppAssembly *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_assembly_get_image");
    if (fn) return fn(assembly);
    return NULL;
}

- (const char *)image_get_name:(Il2CppImage *)image {
    if (!image) return NULL;
    typedef const char *(*fn_t)(const Il2CppImage *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_image_get_name");
    if (fn) return fn(image);
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
            if (++safety > 65535) break;
        }
    } else {
        uint16_t total = klass->field_count;
        FieldInfo *list = klass->fields;
        if (list && total > 0 && total < 65535) {
            for (uint16_t i = 0; i < total; i++) {
                [arr addObject:[NSValue valueWithPointer:&list[i]]];
            }
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
            if (++safety > 65535) break;
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

- (uint32_t)method_get_flags:(MethodInfo *)m {
    if (!m) return 0;
    typedef uint32_t (*fn_t)(const MethodInfo *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_method_get_flags");
    if (fn) return fn(m);
    return m->flags;
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
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_field_get_offset");
    if (fn) return fn(f);
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

#pragma mark - Memory Operations

+ (uintptr_t)getRealOffset:(uintptr_t)offset {
    uintptr_t slide = _dyld_get_image_vmaddr_slide(0);
    const struct mach_header_64 *header = (const struct mach_header_64 *)_dyld_get_image_header(0);
    return (uintptr_t)header + slide + offset;
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

@end
