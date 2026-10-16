#import <Foundation/Foundation.h>

// Định nghĩa các cấu trúc cơ bản của IL2CPP nếu chưa có
struct Il2CppDomain;
struct Il2CppAssembly;
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
- (const struct Il2CppAssembly **)domain_get_assemblies:(struct Il2CppDomain *)domain count:(size_t *)count;
- (struct Il2CppImage *)assembly_get_image:(const struct Il2CppAssembly *)assembly;
- (const char *)image_get_name:(struct Il2CppImage *)image;

// Quản lý Class & Method
- (size_t)image_get_class_count:(struct Il2CppImage *)image;
- (struct Il2CppClass *)image_get_class:(struct Il2CppImage *)image index:(size_t)index;
- (const char *)class_get_name:(struct Il2CppClass *)klass;
- (const char *)class_get_namespace:(struct Il2CppClass *)klass;
- (NSArray<NSValue *> *)class_get_methods:(struct Il2CppClass *)klass count:(size_t *)count;
- (NSArray<NSValue *> *)class_get_fields:(struct Il2CppClass *)klass count:(size_t *)count;

- (const char *)method_get_name:(struct MethodInfo *)method;
- (void *)method_get_pointer:(struct MethodInfo *)method;
- (uint32_t)method_get_flags:(struct MethodInfo *)method;

// Giao diện ghi đè bộ nhớ trực tiếp
+ (uintptr_t)getRealOffset:(uintptr_t)offset;
+ (BOOL)writeFloat:(uintptr_t)address value:(float)value;
+ (BOOL)writeInt32:(uintptr_t)address value:(int32_t)value;
+ (float)readFloat:(uintptr_t)address;
+ (int32_t)readInt32:(uintptr_t)address;

@end
