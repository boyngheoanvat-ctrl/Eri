#import <Foundation/Foundation.h>
#include <mach-o/dyld.h>
#include <dlfcn.h>

// Khai báo cơ bản IL2CPP API (nếu chưa có header riêng)
extern "C" {
    typedef struct Il2CppDomain Il2CppDomain;
    typedef struct Il2CppAssembly Il2CppAssembly;
    typedef struct Il2CppImage Il2CppImage;
    typedef struct Il2CppClass Il2CppClass;
    typedef struct MethodInfo MethodInfo;

    Il2CppDomain* il2cpp_domain_get(void);
    const Il2CppAssembly** il2cpp_domain_get_assemblies(const Il2CppDomain* domain, size_t *size);
    const Il2CppImage* il2cpp_assembly_get_image(const Il2CppAssembly *assembly);
    size_t il2cpp_image_get_class_count(const Il2CppImage *image);
    const Il2CppClass* il2cpp_image_get_class(const Il2CppImage *image, size_t index);
    const char* il2cpp_class_get_name(const Il2CppClass *klass);
    const char* il2cpp_class_get_namespace(const Il2CppClass *klass);
    MethodInfo* il2cpp_class_get_methods(const Il2CppClass *klass, void **iter);
    const char* il2cpp_method_get_name(const MethodInfo *method);
}

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
        
        // Kiểm tra xem IL2CPP domain có sẵn sàng không
        Il2CppDomain *domain = il2cpp_domain_get();
        if (!domain) {
            NSLog(@"[GameFingerprint] IL2CPP Domain not initialized yet.");
            return discoveredMethods;
        }
        
        size_t assemblyCount = 0;
        const Il2CppAssembly **assemblies = il2cpp_domain_get_assemblies(domain, &assemblyCount);
        if (!assemblies) {
            return discoveredMethods;
        }
        
        NSInteger foundCount = 0;
        
        // Duyệt qua từng Assembly và Class trong game để tìm chính xác method khớp với từ khóa
        for (size_t i = 0; i < assemblyCount; i++) {
            const Il2CppImage *image = il2cpp_assembly_get_image(assemblies[i]);
            if (!image) continue;
            
            size_t classCount = il2cpp_image_get_class_count(image);
            for (size_t j = 0; j < classCount; j++) {
                const Il2CppClass *klass = il2cpp_image_get_class(image, j);
                if (!klass) continue;
                
                const char *className = il2cpp_class_get_name(klass);
                if (!className) continue;
                NSString *clsNameStr = [NSString stringWithUTF8String:className];
                
                void *iter = NULL;
                MethodInfo *method = NULL;
                while ((method = il2cpp_class_get_methods((Il2CppClass *)klass, &iter)) != NULL) {
                    const char *methodName = il2cpp_method_get_name(method);
                    if (!methodName) continue;
                    NSString *methodNameStr = [NSString stringWithUTF8String:methodName];
                    
                    // Kiểm tra xem tên class hoặc tên method có chứa keyword người dùng tìm không
                    if ([clsNameStr.lowercaseString containsString:lowerConcept] || 
                        [methodNameStr.lowercaseString containsString:lowerConcept]) {
                        
                        // Lấy địa chỉ thực tế (RVA / pointer) của method nếu có
                        uintptr_t methodPtr = (uintptr_t)method;
                        
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
