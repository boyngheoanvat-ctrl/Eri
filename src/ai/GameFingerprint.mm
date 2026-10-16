#import <Foundation/Foundation.h>
#import "IL2CPPResolver.h"
#include <mach-o/dyld.h>
#include <dlfcn.h>

@interface GameFingerprint : NSObject
+ (instancetype)shared;
- (NSArray<NSDictionary *> *)findMethodsForConcept:(NSString *)concept maxResults:(NSInteger)maxResults;
@end

@implementation GameFingerprint

+ (instancetype)shared {
    static GameFingerprint *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[GameFingerprint alloc] init]; });
    return instance;
}

- (NSArray<NSDictionary *> *)findMethodsForConcept:(NSString *)concept maxResults:(NSInteger)maxResults {
    NSMutableArray *discoveredMethods = [NSMutableArray array];
    
    @try {
        if (!concept || [concept isKindOfClass:[NSNull class]] || concept.length == 0) {
            return discoveredMethods;
        }
        
        NSString *lowerConcept = concept.lowercaseString;
        
        // Sử dụng IL2CPPResolver để phân giải an toàn, tránh lỗi undefined symbol lúc link
        IL2CPPResolver *r = [IL2CPPResolver shared];
        if (!r || ![r resolve]) {
            NSLog(@"[GameFingerprint] IL2CPPResolver not resolved yet.");
            return discoveredMethods;
        }
        
        Il2CppDomain *domain = [r domain_get];
        if (!domain) {
            NSLog(@"[GameFingerprint] IL2CPP Domain not initialized yet.");
            return discoveredMethods;
        }
        
        size_t assemblyCount = 0;
        const Il2CppAssembly **assemblies = [r domain_get_assemblies:domain count:&assemblyCount];
        if (!assemblies || assemblyCount == 0) {
            return discoveredMethods;
        }
        
        NSInteger foundCount = 0;
        
        // Duyệt qua từng Assembly và Class trong game thông qua Resolver
        for (size_t i = 0; i < assemblyCount; i++) {
            const Il2CppAssembly *asm_ = assemblies[i];
            if (!asm_) continue;
            
            Il2CppImage *image = [r assembly_get_image:asm_];
            if (!image) continue;
            
            size_t classCount = [r image_get_class_count:image];
            for (size_t j = 0; j < classCount; j++) {
                Il2CppClass *klass = [r image_get_class:image index:j];
                if (!klass) continue;
                
                const char *className = [r class_get_name:klass];
                if (!className) continue;
                NSString *clsNameStr = [NSString stringWithUTF8String:className];
                
                uint16_t methodCount = 0;
                NSArray<NSValue *> *methodList = [r class_get_methods:klass count:&methodCount];
                
                for (uint16_t k = 0; k < methodCount; k++) {
                    MethodInfo *method = (MethodInfo *)methodList[k].pointerValue;
                    if (!method) continue;
                    
                    const char *methodName = [r method_get_name:method];
                    if (!methodName) continue;
                    NSString *methodNameStr = [NSString stringWithUTF8String:methodName];
                    
                    // Kiểm tra xem tên class hoặc tên method có chứa keyword người dùng tìm không
                    if ([clsNameStr.lowercaseString containsString:lowerConcept] || 
                        [methodNameStr.lowercaseString containsString:lowerConcept]) {
                        
                        void *ptr = [r method_get_pointer:method];
                        uintptr_t methodPtr = ptr ? (uintptr_t)ptr : (uintptr_t)method;
                        
                        [discoveredMethods addObject:@{
                            @"class": clsNameStr,
                            @"method": methodNameStr,
                            @"rva": [NSString stringWithFormat:@"0x%lX", (unsigned long)methodPtr]
                        }];
                        
                        foundCount++;
                        if (maxResults > 0 && foundCount >= maxResults) {
                            return discoveredMethods;
                        }
                    }
                }
            }
        }
        
    } @catch (NSException *exception) {
        NSLog(@"[GameFingerprint] Error during dynamic search: %@", exception);
    }
    
    return discoveredMethods;
}

@end
