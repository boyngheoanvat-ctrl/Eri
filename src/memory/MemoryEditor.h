#import <Foundation/Foundation.h>
#import <mach/mach.h>
#import "MemoryResult.h"

@interface MemoryEditor : NSObject

+ (instancetype)shared;

- (NSArray<MemoryResult *> *)searchValue:(NSString *)value
                                    type:(MemValueType)type
                                   limit:(NSInteger)limit;

- (NSArray<MemoryResult *> *)searchNearAddress:(vm_address_t)addr
                                       value:(NSString *)value
                                        type:(MemValueType)type
                                       limit:(NSInteger)limit;

- (NSString *)readValueAt:(vm_address_t)addr type:(MemValueType)type;

- (BOOL)writeValue:(NSString *)value at:(vm_address_t)addr type:(MemValueType)type;

- (NSInteger)editAll:(NSArray<MemoryResult *> *)results
               value:(NSString *)value
                type:(MemValueType)type;

- (NSString *)regionInfoAt:(vm_address_t)addr;

// Khai báo phương thức đóng băng giá trị (Freeze Engine)
- (void)freezeAddress:(vm_address_t)addr value:(NSString *)value type:(MemValueType)type shouldFreeze:(BOOL)freeze;

@end
