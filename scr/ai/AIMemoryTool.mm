#import "AIMemoryTool.h"
#import "MemoryEditor.h"

@implementation AIMemoryTool

+ (void)registerAll {
    [self registerSearchMemory];
    [self registerEditMemory];
    [self registerReadMemory];
    [self registerMemoryRegion];
}

#pragma mark - search_memory

+ (void)registerSearchMemory {
    NSDictionary *params = @{
        @"type": @"object",
        @"properties": @{
            @"value": @{@"type": @"string", @"description": @"Gia tri can tim, VD: 100"},
            @"type": @{@"type": @"string", @"description": @"int32/int64/float/double/byte/word"},
            @"limit": @{@"type": @"integer", @"description": @"So ket qua toi da (mac dinh 20)"}
        },
        @"required": @[@"value", @"type"]
    };

    AITool *tool = [AITool toolWithName:@"search_memory"
        description:@"Tim gia tri trong memory cua game. Dung khi user hoi 'tim gia tri 100', 'hack mau', 'tim tien'."
        parameters:params
        handler:^id(NSDictionary *args) {
            NSString *value = args[@"value"] ?: @"";
            NSString *typeStr = args[@"type"] ?: @"int32";
            NSInteger limit = args[@"limit"] ? [args[@"limit"] integerValue] : 20;

            MemValueType type = [AIMemoryTool typeFromString:typeStr];

            NSArray<MemoryResult *> *results = [[MemoryEditor shared]
                searchValue:value type:type limit:limit];

            NSMutableArray *out = [NSMutableArray array];
            for (MemoryResult *r in results) {
                [out addObject:@{
                    @"address": [NSString stringWithFormat:@"0x%llX", (uint64_t)r.address],
                    @"value": r.stringValue
                }];
            }

            return @{
                @"count": @(out.count),
                @"type": typeStr,
                @"results": out
            };
        }];

    [AITool registerTool:tool];
}

#pragma mark - edit_memory

+ (void)registerEditMemory {
    NSDictionary *params = @{
        @"type": @"object",
        @"properties": @{
            @"address": @{@"type": @"string", @"description": @"Dia chi, VD: 0x12345678"},
            @"value": @{@"type": @"string", @"description": @"Gia tri moi"},
            @"type": @{@"type": @"string", @"description": @"int32/int64/float/double/byte/word"}
        },
        @"required": @[@"address", @"value", @"type"]
    };

    AITool *tool = [AITool toolWithName:@"edit_memory"
        description:@"Sua gia tri tai dia chi memory. Dung khi user hoi 'sua mau thanh 9999'."
        parameters:params
        handler:^id(NSDictionary *args) {
            NSString *addrStr = args[@"address"] ?: @"";
            NSString *value = args[@"value"] ?: @"";
            NSString *typeStr = args[@"type"] ?: @"int32";

            vm_address_t addr = (vm_address_t)strtoull(addrStr.UTF8String, NULL, 16);
            if (addr == 0) return @{@"error": @"Invalid address"};

            MemValueType type = [AIMemoryTool typeFromString:typeStr];
            BOOL ok = [[MemoryEditor shared] writeValue:value at:addr type:type];

            return @{
                @"success": @(ok),
                @"address": addrStr,
                @"value": value,
                @"type": typeStr
            };
        }];

    [AITool registerTool:tool];
}

#pragma mark - read_memory

+ (void)registerReadMemory {
    NSDictionary *params = @{
        @"type": @"object",
        @"properties": @{
            @"address": @{@"type": @"string"},
            @"type": @{@"type": @"string"}
        },
        @"required": @[@"address", @"type"]
    };

    AITool *tool = [AITool toolWithName:@"read_memory"
        description:@"Doc gia tri tai dia chi memory."
        parameters:params
        handler:^id(NSDictionary *args) {
            NSString *addrStr = args[@"address"] ?: @"";
            NSString *typeStr = args[@"type"] ?: @"int32";

            vm_address_t addr = (vm_address_t)strtoull(addrStr.UTF8String, NULL, 16);
            if (addr == 0) return @{@"error": @"Invalid address"};

            MemValueType type = [AIMemoryTool typeFromString:typeStr];
            NSString *value = [[MemoryEditor shared] readValueAt:addr type:type];

            return @{
                @"address": addrStr,
                @"value": value ?: @"?",
                @"type": typeStr
            };
        }];

    [AITool registerTool:tool];
}

#pragma mark - memory_region

+ (void)registerMemoryRegion {
    NSDictionary *params = @{
        @"type": @"object",
        @"properties": @{
            @"address": @{@"type": @"string"}
        },
        @"required": @[@"address"]
    };

    AITool *tool = [AITool toolWithName:@"memory_region"
        description:@"Lay thong tin region cua dia chi (quyen, kich thuoc)."
        parameters:params
        handler:^id(NSDictionary *args) {
            NSString *addrStr = args[@"address"] ?: @"";
            vm_address_t addr = (vm_address_t)strtoull(addrStr.UTF8String, NULL, 16);
            if (addr == 0) return @{@"error": @"Invalid address"};

            NSString *info = [[MemoryEditor shared] regionInfoAt:addr];
            return @{@"address": addrStr, @"info": info ?: @"?"};
        }];

    [AITool registerTool:tool];
}

#pragma mark - Helper

+ (MemValueType)typeFromString:(NSString *)str {
    NSString *s = str.lowercaseString;
    if ([s isEqualToString:@"int32"] || [s isEqualToString:@"i32"]) return MemValueTypeInt32;
    if ([s isEqualToString:@"int64"] || [s isEqualToString:@"i64"]) return MemValueTypeInt64;
    if ([s isEqualToString:@"float"] || [s isEqualToString:@"f32"]) return MemValueTypeFloat;
    if ([s isEqualToString:@"double"] || [s isEqualToString:@"f64"]) return MemValueTypeDouble;
    if ([s isEqualToString:@"byte"] || [s isEqualToString:@"i8"]) return MemValueTypeByte;
    if ([s isEqualToString:@"word"] || [s isEqualToString:@"i16"]) return MemValueTypeWord;
    return MemValueTypeInt32;
}

@end
