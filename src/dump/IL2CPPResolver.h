#import <Foundation/Foundation.h>

// Định nghĩa đầy đủ các cấu trúc IL2CPP để tránh lỗi incomplete type
struct Il2CppDomain {
    void *domain;
    const char *friendly_name;
    uint32_t domain_id;
    int assembly_count;
    struct Il2CppAssembly **assemblies;
};

struct Il2CppAssembly {
    void *image;
    uint32_t token;
    int32_t referencedAssemblyStart;
    int32_t referencedAssemblyCount;
    struct Il2CppAssemblyName aname;
};

struct Il2CppImage;
struct Il2CppClass;
struct MethodInfo;
struct FieldInfo;

@interface IL2CPPResolver : NSObject

+ (instancetype)shared;
- (BOOL)resolve;
- (uint64_t)il2cppBase;
- (void)attachCurrentThread;

// Quản lý Domain & Assembly
- (struct Il2CppDomain *)domain_get;
- (const struct Il2CppAssembly **)domain_get_assemblies:(struct Il2CppDomain *)domain count:(int *)count;
- (struct Il2CppImage *)assembly_get_image:(const struct Il2CppAssembly *)assembly;
- (const char *)image_get_name:(struct Il2CppImage *)image;

// Quản lý Class, Method & Field
- (size_t)image_get_class_count:(struct Il2CppImage *)image;
- (struct Il2CppClass *)image_get_class:(struct Il2CppImage *)image index:(size_t)index;
- (const char *)class_get_name:(struct Il2CppClass *)klass;
- (const char *)class_get_namespace:(struct Il2CppClass *)klass;
- (uint32_t)class_get_flags:(struct Il2CppClass *)klass;
- (BOOL)class_is_enum:(struct Il2CppClass *)klass;
- (BOOL)class_is_valuetype:(struct Il2CppClass *)klass;
- (BOOL)class_is_interface:(struct Il2CppClass *)klass;
- (struct Il2CppClass *)class_get_parent:(struct Il2CppClass *)klass;
- (void *)class_get_static_field_data:(struct Il2CppClass *)klass;

- (NSArray<NSValue *> *)class_get_methods:(struct Il2CppClass *)klass count:(uint16_t *)count;
- (NSArray<NSValue *> *)class_get_fields:(struct Il2CppClass *)klass count:(uint16_t *)count;

- (const char *)method_get_name:(struct MethodInfo *)method;
- (void *)method_get_pointer:(struct MethodInfo *)method;
- (uint32_t)method_get_flags:(struct MethodInfo *)method;
- (uint32_t)method_get_token:(struct MethodInfo *)method;
- (const char *)method_get_return_type:(struct MethodInfo *)method;
- (uint32_t)method_get_param_count:(struct MethodInfo *)method;
- (const char *)method_get_param_type_name:(struct MethodInfo *)method index:(uint32_t)index;

- (const char *)field_get_name:(struct FieldInfo *)field;
- (int32_t)field_get_offset:(struct FieldInfo *)field;
- (uint32_t)field_get_flags:(struct FieldInfo *)field;
- (const char *)field_get_type_name:(struct FieldInfo *)field;

// Giao diện ghi đè bộ nhớ trực tiếp
+ (uintptr_t)getRealOffset:(uintptr_t)offset;
+ (BOOL)writeFloat:(uintptr_t)address value:(float)value;
+ (BOOL)writeInt32:(uintptr_t)address value:(int32_t)value;
+ (float)readFloat:(uintptr_t)address;
+ (int32_t)readInt32:(uintptr_t)address;

@end
