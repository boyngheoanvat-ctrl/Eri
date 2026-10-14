#import <Foundation/Foundation.h>
#import "IL2CPPResolver.h"

@interface IL2CPPHeapWalker : NSObject

+ (instancetype)shared;

// Tìm class có static field (dùng cho tool/debug)
- (NSArray<NSDictionary *> *)findClassesWithStaticFields:(NSString *)keyword;

// Địa chỉ của static field
- (void *)getStaticFieldAddress:(Il2CppClass *)klass field:(FieldInfo *)field;

// Lấy instance của 1 class thông qua static field `Instance` / `_instance` / `s_instance`
// hoặc getter `get_Instance`
- (void *)getSingletonInstance:(Il2CppClass *)klass;

// Lấy tất cả entity của class cho trước bằng cách:
//   1) Thử static manager pattern (Instance + List<Entity>)
//   2) Nếu không có → trả về mảng rỗng (không crash)
- (NSArray<NSValue *> *)collectInstancesOfClass:(NSString *)className limit:(NSUInteger)limit;

// Đọc List<T> IL2CPP → mảng con trỏ phần tử
- (NSArray<NSValue *> *)readIl2CppList:(void *)listPtr limit:(NSUInteger)limit;

@end
