#import <Foundation/Foundation.h>
#include <stdint.h>

typedef struct Il2CppDomain    Il2CppDomain;
typedef struct Il2CppAssembly  Il2CppAssembly;
typedef struct Il2CppImage     Il2CppImage;
typedef struct Il2CppClass     Il2CppClass;
typedef struct Il2CppType      Il2CppType;
typedef struct MethodInfo      MethodInfo;
typedef struct FieldInfo       FieldInfo;
typedef struct PropertyInfo    PropertyInfo;

struct Il2CppImage {
    const char     *name;
    const char     *nameNoExt;
    Il2CppAssembly *assembly;
};

struct Il2CppDomain {
    int32_t         domain_id;
    int32_t         _pad;
    void           *method_table;
    Il2CppAssembly **assemblies;
    size_t          assembly_count;
};

struct Il2CppType {
    void        *data;
    unsigned int attrs    : 16;
    unsigned int type     : 8;
    unsigned int num_mods : 6;
    unsigned int byref    : 1;
    unsigned int pinned   : 1;
};

struct FieldInfo {
    const char  *name;
    Il2CppType  *type;
    Il2CppClass *parent;
    int32_t      offset;
    uint32_t     token;
    uint32_t     flags;
};

struct PropertyInfo {
    const char  *name;
    Il2CppClass *parent;
    MethodInfo  *get;
    MethodInfo  *set;
};

struct MethodInfo {
    void        *methodPointer;
    void        *virtualMethodPointer;
    void        *invoker_method;
    const char  *name;
    Il2CppClass *klass;
    Il2CppType  *return_type;
    const void  *parameters;
    void        *methodMetadataHandle;
    void        *genericContainerHandle;
    uint32_t     token;
    uint16_t     flags;
    uint16_t     iflags;
    uint16_t     slot;
    uint8_t      parameter_count;
};

struct Il2CppClass {
    const void    *image;
    void          *gc_desc;
    const char    *name;
    const char    *namespaze;
    Il2CppType    *byval_arg;
    Il2CppType    *this_arg;
    Il2CppClass   *element_class;
    Il2CppClass   *castClass;
    Il2CppClass   *declaringType;
    Il2CppClass   *parent;
    Il2CppClass   *generic_class;
    void          *typeMetadataHandle;
    void          *interopData;
    Il2CppClass   *klass;
    FieldInfo     *fields;
    void          *events;
    PropertyInfo  *properties;
    MethodInfo   **methods;
    Il2CppClass   *nestedTypes;
    uint16_t       method_count;
    uint16_t       property_count;
    uint16_t       field_count;
    uint16_t       event_count;
    uint16_t       nested_type_count;
    uint32_t       flags;
};

@interface IL2CPPResolver : NSObject

+ (instancetype)shared;

- (BOOL)resolve;
- (BOOL)isResolved;
- (uint64_t)il2cppBase;

- (void)attachCurrentThread;

- (Il2CppDomain *)domain_get;
- (const Il2CppAssembly **)domain_get_assemblies:(const Il2CppDomain *)domain count:(size_t *)count;
- (Il2CppImage  *)assembly_get_image:(const Il2CppAssembly *)assembly;
- (const char   *)image_get_name:(Il2CppImage *)image;
- (size_t        )image_get_class_count:(Il2CppImage *)image;
- (Il2CppClass  *)image_get_class:(Il2CppImage *)image index:(size_t)index;

- (const char   *)class_get_name:(Il2CppClass *)k;
- (const char   *)class_get_namespace:(Il2CppClass *)k;
- (Il2CppClass  *)class_get_parent:(Il2CppClass *)klass;
- (void         *)class_get_static_field_data:(Il2CppClass *)klass;

- (NSArray<NSValue *> *)class_get_methods:(Il2CppClass *)klass count:(uint16_t *)count;
- (NSArray<NSValue *> *)class_get_fields:(Il2CppClass *)klass count:(uint16_t *)count;
- (NSArray<NSValue *> *)class_get_properties:(Il2CppClass *)klass count:(uint16_t *)count;

- (const char *)method_get_name:(MethodInfo *)m;
- (uint32_t   )method_get_token:(MethodInfo *)m;
- (void      *)method_get_pointer:(MethodInfo *)m;
- (const char *)method_get_return_type:(MethodInfo *)method;

- (const char *)field_get_name:(FieldInfo *)f;
- (int32_t    )field_get_offset:(FieldInfo *)f;
- (uint32_t   )field_get_token:(FieldInfo *)f;
- (const char *)field_get_type_name:(FieldInfo *)field;

- (const char *)property_get_name:(PropertyInfo *)p;

- (const char *)type_get_name:(Il2CppType *)type;

// Giao diện ghi đè bộ nhớ trực tiếp (Memory Operations & Offsets)
+ (uintptr_t)getRealOffset:(uintptr_t)offset;
+ (BOOL)writeFloat:(uintptr_t)address value:(float)value;
+ (BOOL)writeInt32:(uintptr_t)address value:(int32_t)value;
+ (float)readFloat:(uintptr_t)address;
+ (int32_t)readInt32:(uintptr_t)address;

@end
