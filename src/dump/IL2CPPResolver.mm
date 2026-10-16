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

- (uint64_t)il2cppBase {
    uintptr_t slide = _dyld_get_image_vmaddr_slide(0);
    const struct mach_header_64 *header = (const struct mach_header_64 *)_dyld_get_image_header(0);
    return (uint64_t)((uintptr_t)header + slide);
}

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
    }
}

#pragma mark - Core

- (Il2CppDomain *)domain_get {
    if (!self.handle) return NULL;
    typedef Il2CppDomain *(*fn_t)(void);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_domain_get");
    return fn ? fn() : NULL;
}

- (const Il2CppAssembly **)domain_get_assemblies:(const Il2CppDomain *)domain count:(size_t *)count {
    typedef const Il2CppAssembly **(*Fn)(const Il2CppDomain *, size_t *);
    static Fn fn = NULL;
    if (!fn) fn = (Fn)find_sym(self.handle, "il2cpp_domain_get_assemblies");
    if (fn) return fn(domain, count);

    if (!domain) return NULL;
    if (count) *count = domain->assembly_count; // Đã sửa thành assembly_count chuẩn ABI
    return (const Il2CppAssembly **)domain->assemblies;
}

- (Il2CppImage *)assembly_get_image:(const Il2CppAssembly *)assembly {
    if (!assembly) return NULL;
    typedef Il2CppImage *(*fn_t)(const Il2CppAssembly *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_assembly_get_image");
    if (fn) return fn(assembly);
    return assembly->image;
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

- (uint32_t)class_get_flags:(Il2CppClass *)klass {
    typedef uint32_t (*Fn)(const Il2CppClass *);
    static Fn fn = NULL;
    if (!fn) fn = (Fn)find_sym(self.handle, "il2cpp_class_get_flags");
    return fn ? fn(klass) : (klass ? klass->flags : 0);
}

- (BOOL)class_is_enum:(Il2CppClass *)klass {
    typedef bool (*Fn)(const Il2CppClass *);
    static Fn fn = NULL;
    if (!fn) fn = (Fn)find_sym(self.handle, "il2cpp_class_is_enum");
    return fn ? fn(klass) : NO;
}

- (BOOL)class_is_valuetype:(Il2CppClass *)klass {
    typedef bool (*Fn)(const Il2CppClass *);
    static Fn fn = NULL;
    if (!fn) fn = (Fn)find_sym(self.handle, "il2cpp_class_is_valuetype");
    return fn ? fn(klass) : NO;
}

- (BOOL)class_is_interface:(Il2CppClass *)klass {
    typedef bool (*Fn)(const Il2CppClass *);
    static Fn fn = NULL;
    if (!fn) fn = (Fn)find_sym(self.handle, "il2cpp_class_is_interface");
    return fn ? fn(klass) : NO;
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
    typedef uint32_t (*Fn)(const MethodInfo *);
    static Fn fn = NULL;
    if (!fn) fn = (Fn)find_sym(self.handle, "il2cpp_method_get_flags");
    return fn ? fn(m) : (m ? m->flags : 0);
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

- (uint32_t)method_get_param_count:(MethodInfo *)method {
    typedef uint32_t (*Fn)(const MethodInfo *);
    static Fn fn = NULL;
    if (!fn) fn = (Fn)find_sym(self.handle, "il2cpp_method_get_param_count");
    return fn ? fn(method) : (method ? method->parameter_count : 0);
}

- (const char *)method_get_param_type_name:(MethodInfo *)method index:(uint32_t)index {
    typedef const Il2CppType *(*Fn_param)(const MethodInfo *, uint32_t);
    static Fn_param fn_param = NULL;
    if (!fn_param) fn_param = (Fn_param)find_sym(self.handle, "il2cpp_method_get_param");
    
    typedef Il2CppClass *(*Fn_class)(const Il2CppType *);
    static Fn_class fn_class = NULL;
    if (!fn_class) fn_class = (Fn_class)find_sym(self.handle, "il2cpp_class_from_type");
    
    if (fn_param && fn_class) {
        const Il2CppType *t = fn_param(method, index);
        if (t) {
            Il2CppClass *k = fn_class(t);
            if (k) return [self class_get_name:k];
        }
    }
    return NULL;
}

- (const char *)method_get_param_name:(MethodInfo *)method index:(uint32_t)index {
    typedef const char *(*Fn)(const MethodInfo *, uint32_t);
    static Fn fn = NULL;
    if (!fn) fn = (Fn)find_sym(self.handle, "il2cpp_method_get_param_name");
    return fn ? fn(method, index) : NULL;
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

- (uint32_t)field_get_flags:(FieldInfo *)f {
    typedef uint32_t (*Fn)(const FieldInfo *);
    static Fn fn = NULL;
    if (!fn) fn = (Fn)find_sym(self.handle, "il2cpp_field_get_flags");
    return fn ? fn(f) : (f ? f->flags : 0);
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

- (MethodInfo *)property_get_get_method:(PropertyInfo *)p {
    typedef const MethodInfo *(*Fn)(const PropertyInfo *);
    static Fn fn = NULL;
    if (!fn) fn = (Fn)find_sym(self.handle, "il2cpp_property_get_get_method");
    return fn ? (MethodInfo *)fn(p) : (p ? p->get : NULL);
}

- (MethodInfo *)property_get_set_method:(PropertyInfo *)p {
    typedef const MethodInfo *(*Fn)(const PropertyInfo *);
    static Fn fn = NULL;
    if (!fn) fn = (Fn)find_sym(self.handle, "il2cpp_property_get_set_method");
    return fn ? (MethodInfo *)fn(p) : (p ? p->set : NULL);
}

#pragma mark - Type

- (const char *)type_get_name:(Il2CppType *)type {
    if (!type) return NULL;
    typedef const char *(*fn_t)(const Il2CppType *);
    fn_t fn = (fn_t)find_sym(self.handle, "il2cpp_type_get_name");
    if (fn) return fn(type);
    return NULL;
}

#pragma mark - Memory Writing & Offsets

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
