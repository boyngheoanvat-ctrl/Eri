#import <Foundation/Foundation.h>
#include <stdint.h>

// ============================================================
// IL2CPP struct — OPAQUE
// KHÔNG định nghĩa field vì layout thay đổi theo Unity version.
// Chỉ forward-declare, mọi truy cập phải qua API function.
// ============================================================

typedef struct Il2CppDomain    Il2CppDomain;
typedef struct Il2CppAssembly  Il2CppAssembly;
typedef struct Il2CppImage     Il2CppImage;
typedef struct Il2CppClass     Il2CppClass;
typedef struct Il2CppType      Il2CppType;
typedef struct MethodInfo      MethodInfo;
typedef struct FieldInfo       FieldInfo;
typedef struct PropertyInfo    PropertyInfo;

// Il2CppDomain — giữ định nghĩa tối thiểu vì DumperVC dùng
// domain->assembly_count và domain->assemblies
struct Il2CppDomain {
    int32_t         domain_id;
    int32_t         _pad;
    void           *method_table;
    Il2CppAssembly **assemblies;
    size_t          assembly_count;
};

@interface IL2CPPResolver : NSObject

+ (instancetype)shared;

- (BOOL)resolve;
- (BOOL)isResolved;

- (void)attachCurrentThread;

// Domain
- (Il2CppDomain *)domain_get;

// Image
- (Il2CppImage  *)assembly_get_image:(Il2CppAssembly *)assembly;
- (const char   *)image_get_name:(Il2CppImage *)image;
- (size_t        )image_get_class_count:(Il2CppImage *)image;
- (Il2CppClass  *)image_get_class:(Il2CppImage *)image index:(size_t)index;

// Class
- (const char   *)class_get_name:(Il2CppClass *)k;
- (const char   *)class_get_namespace:(Il2CppClass *)k;
- (Il2CppClass  *)class_get_parent:(Il2CppClass *)klass;
- (void         *)class_get_static_field_data:(Il2CppClass *)klass;

// Methods / Fields / Properties
- (NSArray<NSValue *> *)class_get_methods:(Il2CppClass *)klass count:(uint16_t *)count;
- (NSArray<NSValue *> *)class_get_fields:(Il2CppClass *)klass count:(uint16_t *)count;
- (NSArray<NSValue *> *)class_get_properties:(Il2CppClass *)klass count:(uint16_t *)count;

// Method info
- (const char *)method_get_name:(MethodInfo *)m;
- (uint32_t   )method_get_token:(MethodInfo *)m;
- (void      *)method_get_pointer:(MethodInfo *)m;
- (const char *)method_get_return_type:(MethodInfo *)method;
- (uint32_t   )method_get_flags:(MethodInfo *)method;

// Field info
- (const char *)field_get_name:(FieldInfo *)f;
- (int32_t    )field_get_offset:(FieldInfo *)f;
- (uint32_t   )field_get_token:(FieldInfo *)f;
- (const char *)field_get_type_name:(FieldInfo *)field;

// Property info
- (const char *)property_get_name:(PropertyInfo *)p;

// Type info
- (const char *)type_get_name:(Il2CppType *)type;

@end
