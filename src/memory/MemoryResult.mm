#import "MemoryResult.h"

@implementation MemoryResult

+ (instancetype)resultWithAddress:(vm_address_t)addr
                             type:(MemValueType)type
                            value:(NSString *)value {
    MemoryResult *r = [[MemoryResult alloc] init];
    r.address = addr;
    r.type = type;
    r.stringValue = value;
    r.moduleName = @"";
    r.moduleOffset = 0;
    return r;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"0x%llX = %@",
            (uint64_t)self.address, self.stringValue];
}

@end
