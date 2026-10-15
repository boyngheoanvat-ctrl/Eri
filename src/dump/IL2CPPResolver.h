#import <Foundation/Foundation.h>
#include <stdint.h>

typedef struct Il2CppDomain    Il2CppDomain;
typedef struct Il2CppAssembly  Il2CppAssembly;
typedef struct Il2CppImage     Il2CppImage;
typedef struct Il2CppClass     Il2CppClass;
typedef struct Il2CppType      Il2CppType;
typedef struct FieldInfo       FieldInfo;
typedef struct PropertyInfo    PropertyInfo;

typedef struct MethodInfo {
    void *methodPointer;
} MethodInfo;

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
- (uint64_t)il2cppBase;

- (Il2CppDomain *)domain_get;
- (const Il2CppAssembly **)domain_get_assemblies:(Il2CppDomain *)domain count:(size_t *)count;

- (Il2CppImage  *)assembly_get_image:(Il2CppAssembly *)assembly;
- (const char   *)image_get_name:(Il2CppImage *)image;
- (size_t        )image_get_class_count:(Il2CppImage *)image;
- (Il2CppClass  *)image_get_class:(Il2CppImage *)image index:(size_t)index;

- (const char   *)class_get_name:(Il2CppClass *)k;
- (const char   *)class_get_namespace:(Il2CppClass *)k;
- (Il2CppClass  *)class_get_parent:(Il2CppClass *)klass;
- (void         *)class_get_static_field_data:(Il2CppClass *)klass;
- (uint32_t     )class_get_flags:(Il2CppClass *)klass;
- (BOOL          )class_is_enum:(Il2CppClass *)klass;
- (BOOL          )class_is_valuetype:(Il2CppClass *)klass;
- (BOOL          )class_is_interface:(Il2CppClass *)klass;

- (NSArray<NSValue *> *)class_get_methods:(Il2CppClass *)klass count:(uint16_t *)count;
- (NSArray<NSValue *> *)class_get_fields:(Il2CppClass *)klass count:(uint16_t *)count;
- (NSArray<NSValue *> *)class_get_properties:(Il2CppClass *)klass count:(uint16_t *)count;

- (const char *)method_get_name:(MethodInfo *)m;
- (uint32_t   )method_get_token:(MethodInfo *)m;
- (void      *)method_get_pointer:(MethodInfo *)m;
- (const char *)method_get_return_type:(MethodInfo *)method;
- (uint32_t   )method_get_flags:(MethodInfo *)method;
- (uint32_t   )method_get_param_count:(MethodInfo *)method;
- (const char *)method_get_param_name:(MethodInfo *)method index:(uint32_t)index;
- (const char *)method_get_param_type_name:(MethodInfo *)method index:(uint32_t)index;

- (const char *)field_get_name:(FieldInfo *)f;
- (int32_t    )field_get_offset:(FieldInfo *)f;
- (uint32_t   )field_get_token:(FieldInfo *)f;
- (const char *)field_get_type_name:(FieldInfo *)field;
- (uint32_t   )field_get_flags:(FieldInfo *)field;

- (const char *)property_get_name:(PropertyInfo *)p;
- (MethodInfo *)property_get_get_method:(PropertyInfo *)p;
- (MethodInfo *)property_get_set_method:(PropertyInfo *)p;
- (const char *)type_get_name:(Il2CppType *)type;

@end
