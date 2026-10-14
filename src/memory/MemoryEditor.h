#import <Foundation/Foundation.h>
#import <mach/mach.h>
#import "MemoryResult.h"

@interface MemoryEditor : NSObject

+ (instancetype)shared;

// Search
- (NSArray<MemoryResult *> *)searchValue:(NSString *)value
                                    type:(MemValueType)type
                                   limit:(NSInteger)limit;

- (NSArray<MemoryResult *> *)searchNearAddress:(vm_address_t)addr
                                       value:(NSString *)value
                                        type:(MemValueType)type
                                       limit:(NSInteger)limit;

// Read
- (NSString *)readValueAt:(vm_address_t)addr type:(MemValueType)type;

// Write
- (BOOL)writeValue:(NSString *)value at:(vm_address_t)addr type:(MemValueType)type;

// Region info
- (NSString *)regionInfoAt:(vm_address_t)addr;

@end
