#import <Foundation/Foundation.h>

typedef struct Il2CppImage {
    const char *name; const char *nameNoExt; void *assembly;
    uint32_t typeStart; uint32_t typeCount;
} Il2CppImage;

typedef struct Il2CppAssembly { void *image; } Il2CppAssembly;

typedef struct Il2CppType {
    void *data; unsigned int attrs : 16; unsigned int type : 8;
    unsigned int num_mods : 6; unsigned int byref : 1;
    unsigned int pinned : 1; unsigned int valuetype : 1;
} Il2CppType;

typedef struct Il2CppClass {
    const void *image; void *gc_desc; const char *name; const char *namespaze;
    Il2CppType *byval_arg; Il2CppType *this_arg;
    void *element_class; void *castClass; void *declaringType; void *parent;
    void *generic_class; void *typeMetadataHandle; void *interopData;
    void *klass; void *fields; void *events; void *properties;
    void *methods; void *nestedTypes; void *implementedInterfaces;
    int32_t interfaceOffsets; void *static_fields; void *rgctx_data; void *typeHierarchy;
    uint32_t instance_size; int32_t vtable_size;
    uint16_t flags; uint16_t token; uint16_t method_count; uint16_t property_count;
    uint16_t field_count; uint16_t event_count; uint16_t nested_type_count;
    uint16_t vtable_count; uint16_t interfaces_count; uint16_t interface_offsets_count;
} Il2CppClass;

typedef struct MethodInfo {
    void *methodPointer; void *invoker_method; const char *name; Il2CppClass *klass;
    void *return_type; void *parameters; uint32_t token;
    uint16_t flags; uint16_t iflags; uint16_t slot; uint8_t parameter_count;
} MethodInfo;

typedef struct FieldInfo {
    const char *name; Il2CppType *type; Il2CppClass *parent;
    int32_t offset; uint32_t token;
} FieldInfo;

typedef struct PropertyInfo {
    Il2CppClass *parent; const char *name; MethodInfo *get;
    MethodInfo *set; uint32_t attrs; uint32_t token;
} PropertyInfo;

typedef struct Il2CppDomain {
    int32_t domain_id; int32_t assembly_count;
    Il2CppAssembly **assemblies; void *setup;
} Il2CppDomain;

@interface IL2CPPResolver : NSObject
@property (nonatomic, assign, readonly) BOOL isResolved;

+ (instancetype)shared;
- (BOOL)resolve;
- (Il2CppDomain *)domain_get;
- (size_t)image_get_class_count:(Il2CppImage *)image;
- (Il2CppClass *)image_get_class:(Il2CppImage *)image index:(size_t)index;
- (const char *)class_get_name:(Il2CppClass *)klass;
- (const char *)class_get_namespace:(Il2CppClass *)klass;
- (const MethodInfo **)class_get_methods:(Il2CppClass *)klass count:(uint16_t *)count;
- (const FieldInfo **)class_get_fields:(Il2CppClass *)klass count:(uint16_t *)count;
- (const PropertyInfo **)class_get_properties:(Il2CppClass *)klass count:(uint16_t *)count;
- (const char *)method_get_name:(MethodInfo *)method;
- (const char *)field_get_name:(FieldInfo *)field;
- (const char *)property_get_name:(PropertyInfo *)prop;
- (int32_t)field_get_offset:(FieldInfo *)field;
- (uint32_t)method_get_token:(MethodInfo *)method;
- (uint32_t)field_get_token:(FieldInfo *)field;
- (void *)method_get_pointer:(MethodInfo *)method;
- (Il2CppClass *)class_get_parent:(Il2CppClass *)klass;

// Type API
- (const char *)type_get_name:(Il2CppType *)type;
- (const char *)field_get_type_name:(FieldInfo *)field;
- (const char *)method_get_return_type:(MethodInfo *)method;

@end
