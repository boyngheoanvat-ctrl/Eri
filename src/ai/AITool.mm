#import "AITool.h"
#import "IL2CPPResolver.h"

static NSMutableDictionary<NSString *, AITool *> *gTools = nil;

@implementation AITool

+ (instancetype)toolWithName:(NSString *)name description:(NSString *)desc parameters:(NSDictionary *)params handler:(id (^)(NSDictionary *))handler {
    @autoreleasepool {
        AITool *t = [[AITool alloc] init];
        t.name = name; t.toolDescription = desc; t.parameters = params; t.handler = handler;
        return t;
    }
}

+ (NSArray<AITool *> *)allTools { @autoreleasepool { return gTools.allValues ?: @[]; } }
+ (AITool *)toolNamed:(NSString *)name { @autoreleasepool { return gTools[name]; } }

+ (void)registerTool:(AITool *)tool {
    @autoreleasepool {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{ gTools = [NSMutableDictionary dictionary]; });
        if (tool.name) gTools[tool.name] = tool;
    }
}

+ (void)registerAll {
    @autoreleasepool {
        [self registerTool:[AITool toolWithName:@"analyze_ghidra"
            description:@"Phân tích tĩnh chuyên sâu qua Ghidra RVA."
            parameters:@{@"type": @"object", @"properties": @{@"rva": @{@"type": @"string"}}, @"required": @[@"rva"]}
            handler:^id(NSDictionary *args) {
                @autoreleasepool {
                    [[IL2CPPResolver shared] attachCurrentThread];
                    NSString *rvaStr = args[@"rva"] ?: @"0x1073083C0";
                    unsigned long long rva = strtoull(rvaStr.UTF8String, NULL, 16);
                    uintptr_t absolute = [IL2CPPResolver getRealOffset:(uintptr_t)rva];
                    return @{@"status": @"success", @"ghidra_rva": rvaStr, @"absolute_address": [NSString stringWithFormat:@"%p", (void*)absolute]};
                }
            }]];
    }
}

- (NSDictionary *)openAISchema {
    @autoreleasepool {
        return @{@"type": @"function", @"function": @{@"name": self.name ?: @"", @"description": self.toolDescription ?: @"", @"parameters": self.parameters ?: @{@"type": @"object", @"properties": @{}}}};
    }
}

@end
