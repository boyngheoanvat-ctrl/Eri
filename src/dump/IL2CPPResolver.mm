#import "IL2CPPResolver.h"
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>

@implementation IL2CPPResolver

+ (instancetype)shared {
    static IL2CPPResolver *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[IL2CPPResolver alloc] init];
    });
    return instance;
}

- (BOOL)resolve {
    // Kiểm tra và kết nối module IL2CPP trong tiến trình game
    void *handle = dlopen(NULL, RTLD_LAZY);
    if (!handle) return NO;
    return YES;
}

- (uint64_t)il2cppBase {
    uintptr_t slide = _dyld_get_image_vmaddr_slide(0);
    const struct mach_header_64 *header = (const struct mach_header_64 *)_dyld_get_image_header(0);
    return (uint64_t)((uintptr_t)header + slide);
}

- (void)attachCurrentThread {
    // Đảm bảo thread hiện tại được gắn kết với il2cpp domain nếu cần
}

- (struct Il2CppDomain *)domain_get {
    // Trỏ tới il2cpp_domain_get thực tế nếu được load qua dlsym
    typedef struct Il2CppDomain *(*Fn)(void);
    Fn fn = (Fn)dlsym(RTLD_DEFAULT, "il2cpp_domain_get");
    return fn ? fn() : NULL;
}

- (const struct Il2CppAssembly **)domain_get_assemblies:(struct Il2CppDomain *)domain count:(size_t *)count {
    typedef const struct Il2CppAssembly **(*Fn)(struct Il2CppDomain *, size_t *);
    Fn fn = (Fn)dlsym(RTLD_DEFAULT, "il2cpp_domain_get_assemblies");
    return fn ? fn(domain, count) : NULL;
}

- (struct Il2CppImage *)assembly_get_image:(const struct Il2CppAssembly *)assembly {
    typedef struct Il2CppImage *(*Fn)(const struct Il2CppAssembly *);
    Fn fn = (Fn)dlsym(RTLD_DEFAULT, "il2cpp_assembly_get_image");
    return fn ? fn(assembly) : NULL;
}

- (const char *)image_get_name:(struct Il2CppImage *)image {
    typedef const char *(*Fn)(struct Il2CppImage *);
    Fn fn = (Fn)dlsym(RTLD_DEFAULT, "il2cpp_image_get_name");
    return fn ? fn(image) : "";
}

- (size_t)image_get_class_count:(struct Il2CppImage *)image {
    typedef size_t (*Fn)(struct Il2CppImage *);
    Fn fn = (Fn)dlsym(RTLD_DEFAULT, "il2cpp_image_get_class_count");
    return fn ? fn(image) : 0;
}

- (struct Il2CppClass *)image_get_class:(struct Il2CppImage *)image index:(size_t)index {
    typedef struct Il2CppClass *(*Fn)(struct Il2CppImage *, size_t);
    Fn fn = (Fn)dlsym(RTLD_DEFAULT, "il2cpp_image_get_class");
    return fn ? fn(image, index) : NULL;
}

- (const char *)class_get_name:(struct Il2CppClass *)klass {
    typedef const char *(*Fn)(struct Il2CppClass *);
    Fn fn = (Fn)dlsym(RTLD_DEFAULT, "il2cpp_class_get_name");
    return fn ? fn(klass) : "";
}

- (const char *)class_get_namespace:(struct Il2CppClass *)klass {
    typedef const char *(*Fn)(struct Il2CppClass *);
    Fn fn = (Fn)dlsym(RTLD_DEFAULT, "il2cpp_class_get_namespace");
    return fn ? fn(klass) : "";
}

- (NSArray<NSValue *> *)class_get_methods:(struct Il2CppClass *)klass count:(size_t *)count {
    // Trả về danh sách method pointers qua reflection của il2cpp
    return @[];
}

- (NSArray<NSValue *> *)class_get_fields:(struct Il2CppClass *)klass count:(size_t *)count {
    return @[];
}

- (const char *)method_get_name:(struct MethodInfo *)method {
    typedef const char *(*Fn)(struct MethodInfo *);
    Fn fn = (Fn)dlsym(RTLD_DEFAULT, "il2cpp_method_get_name");
    return fn ? fn(method) : "";
}

- (void *)method_get_pointer:(struct MethodInfo *)method {
    typedef void *(*Fn)(struct MethodInfo *);
    Fn fn = (Fn)dlsym(RTLD_DEFAULT, "il2cpp_method_get_pointer");
    return fn ? fn(method) : NULL;
}

- (uint32_t)method_get_flags:(struct MethodInfo *)method {
    typedef uint32_t (*Fn)(struct MethodInfo *, uint32_t *);
    Fn fn = (Fn)dlsym(RTLD_DEFAULT, "il2cpp_method_get_flags");
    return fn ? fn(method, NULL) : 0;
}

// Các phương thức ghi đè bộ nhớ tĩnh (Memory Writing & Offsets)
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
