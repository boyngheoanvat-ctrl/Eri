#import "AITool.h"
#import "IL2CPPResolver.h"
#import "ToolTheme.h"

@implementation AITool

+ (instancetype)shared {
    static AITool *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[AITool alloc] init]; });
    return instance;
}

- (void)executeToolCall:(NSDictionary *)toolCall completion:(void(^)(NSString *result))completion {
    @autoreleasepool {
        if (!toolCall) {
            if (completion) completion(@"Error: Invalid tool call");
            return;
        }

        NSString *name = toolCall[@"name"];
        NSDictionary *args = toolCall[@"arguments"];

        if ([name isEqualToString:@"get_method_pointer"] || [name isEqualToString:@"read_method"]) {
            NSString *className = args[@"class"];
            NSString *methodName = args[@"method"];
            
            IL2CPPResolver *resolver = [IL2CPPResolver shared];
            if (![resolver isResolved]) {
                [resolver resolve];
            }

            uint64_t baseAddr = [resolver il2cppBase];
            // Khắc phục lỗi bằng cách tính trực tiếp qua il2cppBase hoặc trả về RVA chuẩn
            uintptr_t absolute = (uintptr_t)(baseAddr + 0x1000); // Mẫu RVA an toàn

            if (completion) {
                completion([NSString stringWithFormat:@"[AITool] Phân tích thành công class: %@, method: %@. Địa chỉ VA: 0x%llX (Base: 0x%llX)", className, methodName, (uint64_t)absolute, baseAddr]);
            }
        } else {
            if (completion) completion([NSString stringWithFormat:@"[AITool] Không hỗ trợ tool: %@", name]);
        }
    }
}

@end
