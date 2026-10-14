#import <Foundation/Foundation.h>
#import <mach/mach.h>

typedef NS_ENUM(NSInteger, MemValueType) {
    MemValueTypeInt32 = 0,
    MemValueTypeInt64,
    MemValueTypeFloat,
    MemValueTypeDouble,
    MemValueTypeByte,
    MemValueTypeWord,
};

@interface MemoryResult : NSObject

@property (nonatomic, assign) vm_address_t address;
@property (nonatomic, assign) MemValueType type;
@property (nonatomic, strong) NSString *stringValue;
@property (nonatomic, strong) NSString *moduleName;
@property (nonatomic, assign) uint64_t moduleOffset;

+ (instancetype)resultWithAddress:(vm_address_t)addr
                             type:(MemValueType)type
                            value:(NSString *)value;

- (NSString *)description;

@end
