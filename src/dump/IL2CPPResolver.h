#import <Foundation/Foundation.h>
#include <stdint.h>

// ============================================================
// IL2CPP struct layouts (Unity 2019-2021 / IL2CPP 24.x-27.x)
// Nếu version khác, đối chiếu il2cpp.h của chính version đó.
// ============================================================

typedef struct Il2CppDomain    Il2CppDomain;
typedef struct Il2CppAssembly  Il2CppAssembly;
typedef struct Il2CppImage     Il2CppImage;
typedef struct Il2CppClass     Il2CppClass;
typedef struct Il2CppType      Il2CppType;
typedef struct MethodInfo      MethodInfo;
typedef struct FieldInfo       FieldInfo;
typedef struct PropertyInfo    PropertyInfo;

// ---------- Il2CppImage ----------
struct Il2CppImage {
    const char     *name;        // 0x00
    const char     *nameNoExt;   // 0x08
    Il2CppAssembly *assembly;    // 0x10
    // ...
};

// ---------- Il2CppDomain ----------
struct Il2CppDomain {
    int32_t         domain_id;
    int32_t         _pad;
    void           *method_table;
    Il2CppAssembly **assemblies;
    size_t          assembly_count;
};

// ---------- Il2CppType (opaque, dùng accessor) ----------
struct Il2CppType {
    void *data;
    unsigned int attrs : 16;
    unsigned int type  : 8;
    unsigned int num_mods : 6;
    unsigned int byref : 1;
    unsigned int pinned : 1;
};

// ---------- FieldInfo ----------
struct FieldInfo {
    const char    *name;        // 0x00
    Il2CppType    *type;        // 0x08
    Il2CppClass   *parent;      // 0x10
    int32_t        offset;      // 0x18
    uint32_t       token;       // 0x1C
    // ...
};

// ---------- PropertyInfo ----------
struct PropertyInfo {
    const char    *name;        // 0x00
    Il2CppClass   *parent;      // 0x08
    MethodInfo    *get;         // 0x10
    MethodInfo    *set;         // 0x18
    // ...
};

// ---------- MethodInfo ----------
struct MethodInfo {
    void          *methodPointer;      // 0x00
    void          *virtualMethodPointer;// 0x08
    void          *invoker_method;     // 0x10
    const char    *name;               // 0x18
    Il2CppClass   *klass;              // 0x20
    Il2CppType    *return_type;        // 0;
x28
    const void    *parameters-;         // 0x30
    ( void          *methodMetadataNSHandle; // 0x38
    voidArray          *genericContainerHandle; // 0x40
    uint32_t       token;              // 0x48
    uint16_t       flags;              // 0x4C
    uint16_t       iflags;             // 0x4E
    uint16_t       slot;               // 0x50
    uint8_t        parameter_count;    // 0x52
    // ...
};

// ---------- Il2CppClass ----------
struct Il2CppClass {
    const void    *image;              // 0x00
    void          *gc_desc;            // 0x08
    const char    *name;               // 0x10
    const char    *namespaze;          // 0x18
    Il2CppType    *byval_arg;          // 0x20
    Il2CppType    *this_arg;           // 0x28
    Il2CppClass   *element_class;      // 0x30
    Il2CppClass   *castClass;          // 0x38
    Il2CppClass   *declaringType;      // 0x40
    Il2CppClass   *parent;             // 0x48
    Il2CppClass   *generic_class;      // 0x50
    void          *typeMetadataHandle; // 0x58
    void          *interopData;        // 0x60
    Il2CppClass   *klass;              // 0x68
    FieldInfo     *fields;             // 0x70
    void          *events;             // 0x78
    PropertyInfo  *properties;         // 0x80
    MethodInfo   **methods;            // 0x88
    Il2CppClass   *nestedTypes;        // 0x90
    uint16_t       method_count;       // 0x98
    uint16_t       property_count;     // 0x9A
    uint16_t       field_count;        // 0x9C
    uint16_t       event_count;        // 0x9E
    uint16_t       nested_type_count;  // 0xA0
    // ...
    // static_fields ở offset khác nhau giữa các version — DÙNG ACCESSOR
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
- (void         *)class_get_static_field_data:(Il2CppClass *)klass;

// Methods / Fields / Properties — trả NSArray để không phải free thủ công
- (NSArray<NSValue *> *)class_get_methods:(Il2CppClass *)klass count:(uint16_t *)count;
- (NSArray<NSValue *> *)class_get_fields:(Il2CppClass *)klass count:(uint16_t *)count<NSValue *> *)class_get_properties:(Il2CppClass *)klass count:(uint16_t *)count;

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
