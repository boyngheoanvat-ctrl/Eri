#import <Foundation/Foundation.h>
#include <stdint.h>

// ============================================================
// IL2CPP types
// MethodInfo: chỉ có 1 field duy nhất methodPointer — được khai báo ĐẦY ĐỦ
// Các type khác: opaque
// ============================================================

typedef struct Il2CppDomain    Il2CppDomain;
typedef struct Il2CppAssembly  Il2CppAssembly;
typedef struct Il2CppImage     Il2CppImage;
typedef struct Il2CppClass     Il2CppClass;
typedef struct Il2CppType      Il2CppType;
typedef struct FieldInfo       FieldInfo;
typedef struct PropertyInfo    PropertyInfo;

// MethodInfo — ĐẦY ĐỦ (IL2CPP thật chỉ có 1 field methodPointer)
typedef struct MethodInfo {
    void *methodPointer;
} MethodInfo;

// Il2CppDomain — ĐẦY ĐỦ (nhiều file khác dùng domain->assemblies)
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

// Base address của UnityFramework (để tính RVA)
- (uint64_t)il2cppBase;

// Domain
- (Il2CppDomain *)domain_get;
- (const Il2CppAssembly **)domain_get_assemblies:(Il2CppDomain *)domain count:(size_t *)count;
- (const Il2CppAssembly **)domain_get_assemblies:(Il2CppDomain *)domain count:(int *)count; // Bổ sung tương thích int*

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
- (uint32_t     )class_get_flags:(Il2CppClass *)klass;
- (BOOL          )class_is_enum:(Il2CppClass *)klass;
- (BOOL          )class_is_valuetype:(Il2CppClass *)klass;
- (BOOL          )class_is_interface:(Il2CppClass *)klass;

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
- (uint32_t   )method_get_param_count:(MethodInfo *)method;
- (const char *)method_get_param_name:(MethodInfo *)method index:(uint32_t)index;
- (const char *)method_get_param_type_name:(MethodInfo *)method index:(uint32_t)index;

// Field info
- (const char *)field_get_name:(FieldInfo *)f;
- (int32_t    )field_get_offset:(FieldInfo *)f;
- (uint32_t   )field_get_token:(FieldInfo *)f;
- (const char *)field_get_type_name:(FieldInfo *)field;
- (uint32_t   )field_get_flags:(FieldInfo *)field;

// Property info
- (const char *)property_get_name:(PropertyInfo *)p;
- (MethodInfo *)property_get_get_method:(PropertyInfo *)p;
- (MethodInfo *)property_get_set_method:(PropertyInfo *)p;

// Type info
- (const char *)type_get_name:(Il2CppType *)type;

// Giao diện ghi đè bộ nhớ trực tiếp (Memory Operations bổ sung cho CHookVC)
+ (uintptr_t)getRealOffset:(uintptr_t)offset;
+ (BOOL)writeFloat:(uintptr_t)address value:(float)value;
+ (BOOL)writeInt32:(uintptr_t)address value:(int32_t)value;
+ (float)readFloat:(uintptr_t)address;
+ (int32_t)readInt32:(uintptr_t)address;

@end
