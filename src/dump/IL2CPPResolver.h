#import <Foundation/Foundation.h>
#include <stdint.h>

// --- Opaque forward decls (không cần biết layout đầy đủ) ---
typedef struct Il2CppDomain    Il2CppDomain;
typedef struct Il2CppAssembly  Il2CppAssembly;
typedef struct Il2CppImage     Il2CppImage;
typedef struct Il2CppClass     Il2CppClass;
typedef struct Il2CppType      Il2CppType;
typedef struct MethodInfo      MethodInfo;
typedef struct FieldInfo       FieldInfo;
typedef struct PropertyInfo    PropertyInfo;

// --- Struct tối thiểu (chỉ dùng làm fallback nếu symbol dlsym fail) ---
// Layout dưới đây theo Unity 2019–2022. Nếu version khác, sửa lại cho khớp il2cpp.h.
struct Il2CppDomain {
    int32_t       domain_id;
    int32_t       _pad;
    void         *method_table;
    Il2CppAssembly **assemblies;
    size_t         assembly_count;
};

struct Il2CppClass {
    const void    *image;
    void          *gc_desc;
    const char    *name;
    const char    *namespaze;
    void          *byval_arg;
    void          *this_arg;
    Il2CppClass   *element_class;
    Il2CppClass   *castClass;
    Il2CppClass   *declaringType;
    Il2CppClass   *parent;
    Il2CppClass   *generic_class;
    void          *typeMetadataHandle;
    void          *interopData;
    Il2CppClass   *klass;
    void          *fields;
    void          *events;
    void          *properties;
    void          *methods;
    Il2CppClass   *nestedTypes;
    uint16_t       method_count;
    uint16_t       property_count;
    uint16_t       field_count;
    uint16_t       event_count;
    uint16_t       nested_type_count;
    // ... còn nữa nhưng không dùng
};

@interface IL2CPPResolver : NSObject

+ (instancetype)shared;

- (BOOL)resolve;
- (BOOL)isResolved;

// Core
- (Il2CppDomain *)domain_get;
- (Il2CppImage  *)assembly_get_image:(Il2CppAssembly *)assembly;
- (const char   *)image_get_name:(Il2CppImage *)image;
- (size_t        )image_get_class_count:(Il2CppImage *)image;
- (Il2CppClass  *)image_get_class:(Il2CppImage *)image index:(size_t)index;

// Class
- (const char   *)class_get_name:(Il2CppClass *)k;
- (const char   *)class_get_namespace:(Il2CppClass *)k;
- (Il2CppClass  *)class_get_parent:(Il2CppClass *)klass;

// Methods / Fields / Properties -> trả NSArray<NSValue *> để không phải free thủ công
- (NSArray<NSValue *> *)class_get_methods:(Il2CppClass *)klass count:(uint16_t *)count;
- (NSArray<NSValue *> *)class_get_fields:(Il2CppClass *)klass count:(uint16_t *)count;
- (NSArray<NSValue *> *)class_get_properties:(Il2CppClass *)klass count:(uint16_t *)count;

// Method info
- (const char *)method_get_name:(MethodInfo *)m;
- (uint32_t   )method_get_token:(MethodInfo *)m;
- (void      *)method_get_pointer:(MethodInfo *)m;
- (const char *)method_get_return_type:(MethodInfo *)method;

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
