#import <Foundation/Foundation.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>

@interface IL2CPPResolver : NSObject
+ (uintptr_t)getRealOffset:(uintptr_t)offset;
+ (BOOL)writeFloat:(uintptr_t)address value:(float)value;
+ (BOOL)writeInt32:(uintptr_t)address value:(int32_t)value;
+ (float)readFloat:(uintptr_t)address;
+ (int32_t)readInt32:(uintptr_t)address;
@end

@implementation IL2CPPResolver

+ (uintptr_t)getRealOffset:(uintptr_t)offset {
    uintptr_t slide = _dyld_get_image_slide(0);
    if (slide == 0) {
        const struct mach_header_h *header = (const struct mach_header_h *)_dyld_get_image_header(0);
        return (uintptr_t)header + offset;
    }
    return _dyld_get_image_vmaddr_slide(0) + offset;
}

+ (BOOL)writeFloat:(uintptr_t)address value:(float)value {
    mach_port_t task = mach_task_self();
    vm_prot_t oldProt;
    // Cấp quyền đọc/ghi bộ nhớ qua vm_protect để tránh crash
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
