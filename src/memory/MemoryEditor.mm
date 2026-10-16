#import "MemoryEditor.h"
#import <mach-o/dyld.h>
#import <mach-o/getsect.h>
#import <mach-o/loader.h>
#import <dlfcn.h>
#import <mach/mach.h>
#import <unistd.h>

@implementation MemoryEditor

+ (instancetype)shared {
    static MemoryEditor *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[MemoryEditor alloc] init]; });
    return instance;
}

#pragma mark - Search

- (NSArray<MemoryResult *> *)searchValue:(NSString *)value
                                    type:(MemValueType)type
                                   limit:(NSInteger)limit {

    NSMutableArray *results = [NSMutableArray array];

    vm_address_t address = 0;
    vm_size_t size = 0;
    vm_region_basic_info_data_64_t info;
    mach_msg_type_number_t info_count = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t object_name = MACH_PORT_NULL;

    while (results.count < (NSUInteger)limit) {
        kern_return_t kr = vm_region_64(mach_task_self(), &address, &size,
                                         VM_REGION_BASIC_INFO_64,
                                         (vm_region_info_t)&info,
                                         &info_count, &object_name);
        if (kr != KERN_SUCCESS) break;

        if ((info.protection & (VM_PROT_READ | VM_PROT_WRITE)) == (VM_PROT_READ | VM_PROT_WRITE)) {
            [self scanRegion:address size:size value:value type:type results:results limit:limit];
        }

        address += size;
    }

    return results;
}

- (void)scanRegion:(vm_address_t)base
              size:(vm_size_t)size
             value:(NSString *)value
              type:(MemValueType)type
           results:(NSMutableArray *)results
             limit:(NSInteger)limit {

    if (size > 1024 * 1024 * 50) return;

    vm_offset_t data = 0;
    mach_msg_type_number_t dataCnt = 0;

    kern_return_t kr = vm_read(mach_task_self(), base, size, &data, &dataCnt);
    if (kr != KERN_SUCCESS) return;

    uint8_t *bytes = (uint8_t *)data;

    NSData *pattern = [self dataForValue:value type:type];
    if (!pattern) { vm_deallocate(mach_task_self(), data, dataCnt); return; }

    const uint8_t *patBytes = (const uint8_t *)pattern.bytes;
    NSUInteger patLen = pattern.length;

    for (NSUInteger i = 0; i <= size - patLen && results.count < (NSUInteger)limit; i++) {
        if (memcmp(bytes + i, patBytes, patLen) == 0) {
            vm_address_t foundAddr = base + i;
            MemoryResult *r = [MemoryResult resultWithAddress:foundAddr type:type value:value];
            [results addObject:r];
        }
    }

    vm_deallocate(mach_task_self(), data, dataCnt);
}

- (NSArray<MemoryResult *> *)searchNearAddress:(vm_address_t)addr
                                       value:(NSString *)value
                                        type:(MemValueType)type
                                       limit:(NSInteger)limit {
    NSMutableArray *results = [NSMutableArray array];
    vm_address_t base = addr > 0x100000 ? addr - 0x100000 : 0;
    vm_size_t size = 0x200000;
    [self scanRegion:base size:size value:value type:type results:results limit:limit];
    return results;
}

#pragma mark - Helpers

- (NSData *)dataForValue:(NSString *)value type:(MemValueType)type {
    if (type == MemValueTypeInt32) {
        int32_t v = value.intValue;
        return [NSData dataWithBytes:&v length:sizeof(v)];
    }
    if (type == MemValueTypeInt64) {
        int64_t v = value.longLongValue;
        return [NSData dataWithBytes:&v length:sizeof(v)];
    }
    if (type == MemValueTypeFloat) {
        float v = value.floatValue;
        return [NSData dataWithBytes:&v length:sizeof(v)];
    }
    if (type == MemValueTypeDouble) {
        double v = value.doubleValue;
        return [NSData dataWithBytes:&v length:sizeof(v)];
    }
    if (type == MemValueTypeByte) {
        uint8_t v = (uint8_t)value.intValue;
        return [NSData dataWithBytes:&v length:1];
    }
    if (type == MemValueTypeWord) {
        uint16_t v = (uint16_t)value.intValue;
        return [NSData dataWithBytes:&v length:2];
    }
    return nil;
}

#pragma mark - Read/Write

- (NSString *)readValueAt:(vm_address_t)addr type:(MemValueType)type {
    vm_offset_t data = 0;
    mach_msg_type_number_t dataCnt = 0;

    kern_return_t kr = vm_read(mach_task_self(), addr, 8, &data, &dataCnt);
    if (kr != KERN_SUCCESS) return @"Error";

    uint8_t *bytes = (uint8_t *)data;

    NSString *result = @"";
    if (type == MemValueTypeInt32) {
        int32_t v; memcpy(&v, bytes, 4);
        result = [NSString stringWithFormat:@"%d", v];
    } else if (type == MemValueTypeInt64) {
        int64_t v; memcpy(&v, bytes, 8);
        result = [NSString stringWithFormat:@"%lld", v];
    } else if (type == MemValueTypeFloat) {
        float v; memcpy(&v, bytes, 4);
        result = [NSString stringWithFormat:@"%f", v];
    } else if (type == MemValueTypeDouble) {
        double v; memcpy(&v, bytes, 8);
        result = [NSString stringWithFormat:@"%f", v];
    } else if (type == MemValueTypeByte) {
        uint8_t v; memcpy(&v, bytes, 1);
        result = [NSString stringWithFormat:@"%d", v];
    } else if (type == MemValueTypeWord) {
        uint16_t v; memcpy(&v, bytes, 2);
        result = [NSString stringWithFormat:@"%d", v];
    }

    vm_deallocate(mach_task_self(), data, dataCnt);
    return result;
}

- (BOOL)writeValue:(NSString *)value at:(vm_address_t)addr type:(MemValueType)type {
    NSData *data = [self dataForValue:value type:type];
    if (!data) return NO;

    mach_port_t task = mach_task_self();
    vm_address_t pageAddr = addr & ~(vm_page_size - 1);
    vm_size_t pageSize = vm_page_size;
    
    vm_prot_t oldProt = 0;
    boolean_t get_old = FALSE;
    
    // Cấp quyền Read/Write/Copy tạm thời để ghi đè an toàn
    kern_return_t kr = vm_protect(task, pageAddr, pageSize, get_old, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    if (kr != KERN_SUCCESS) {
        kr = vm_write(task, addr, (vm_offset_t)data.bytes, (mach_msg_type_number_t)data.length);
        return kr == KERN_SUCCESS;
    }

    kr = vm_write(task, addr, (vm_offset_t)data.bytes, (mach_msg_type_number_t)data.length);
    vm_protect(task, pageAddr, pageSize, get_old, oldProt);

    return kr == KERN_SUCCESS;
}

#pragma mark - Edit All

- (NSInteger)editAll:(NSArray<MemoryResult *> *)results
               value:(NSString *)value
                type:(MemValueType)type {
    NSInteger count = 0;
    for (MemoryResult *r in results) {
        if ([self writeValue:value at:r.address type:type]) {
            count++;
        }
    }
    return count;
}

#pragma mark - Region Info

- (NSString *)regionInfoAt:(vm_address_t)addr {
    vm_address_t region = addr;
    vm_size_t size = 0;
    vm_region_basic_info_data_64_t info;
    mach_msg_type_number_t info_count = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t object_name = MACH_PORT_NULL;

    kern_return_t kr = vm_region_64(mach_task_self(), &region, &size,
                                     VM_REGION_BASIC_INFO_64,
                                     (vm_region_info_t)&info,
                                     &info_count, &object_name);
    if (kr != KERN_SUCCESS) return @"Unknown";

    NSString *prot = @"";
    if (info.protection & VM_PROT_READ) prot = [prot stringByAppendingString:@"r"];
    if (info.protection & VM_PROT_WRITE) prot = [prot stringByAppendingString:@"w"];
    if (info.protection & VM_PROT_EXECUTE) prot = [prot stringByAppendingString:@"x"];

    return [NSString stringWithFormat:@"0x%llX - 0x%llX (%@)",
            (uint64_t)region, (uint64_t)(region + size), prot];
}

#pragma mark - Memory Freeze Engine (Đóng băng giá trị)

static NSMutableDictionary<NSNumber *, NSDictionary *> *g_frozenMemory = nil;
static dispatch_queue_t g_freezeQueue = nil;
static BOOL g_isFreezeThreadRunning = NO;

+ (void)startFreezeEngineIfNeeded {
    @synchronized([MemoryEditor class]) {
        if (g_isFreezeThreadRunning) return;
        g_isFreezeThreadRunning = YES;
        g_frozenMemory = [NSMutableDictionary dictionary];
        g_freezeQueue = dispatch_queue_create("com.eri.memoryfreeze", DISPATCH_QUEUE_SERIAL);
        
        dispatch_async(g_freezeQueue, ^{
            while (g_isFreezeThreadRunning) {
                @autoreleasepool {
                    @synchronized (g_frozenMemory) {
                        for (NSNumber *addrNum in g_frozenMemory.allKeys) {
                            uintptr_t address = addrNum.unsignedLongValue;
                            NSDictionary *dict = g_frozenMemory[addrNum];
                            MemValueType type = (MemValueType)[dict[@"type"] integerValue];
                            NSString *valueStr = dict[@"value"];
                            
                            [[MemoryEditor shared] writeValue:valueStr at:address type:type];
                        }
                    }
                    usleep(50000); // Lặp lại việc ghi đè mỗi 50ms
                }
            }
        });
    }
}

- (void)freezeAddress:(vm_address_t)addr value:(NSString *)value type:(MemValueType)type shouldFreeze:(BOOL)freeze {
    [MemoryEditor startFreezeEngineIfNeeded];
    @synchronized (g_frozenMemory) {
        NSNumber *key = @(addr);
        if (freeze) {
            g_frozenMemory[key] = @{
                @"value": value,
                @"type": @(type)
            };
        } else {
            [g_frozenMemory removeObjectForKey:key];
        }
    }
}

@end
