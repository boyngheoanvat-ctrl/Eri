#import <Foundation/Foundation.h>
#import "IL2CPPResolver.h"

typedef NS_ENUM(NSInteger, ESPCollectStrategy) {
    ESPCollectStrategyNone = 0,
    ESPCollectStrategySingletonList,   // Manager.Instance + List<Entity>
    ESPCollectStrategyStaticList,      // static List<Entity>
    ESPCollectStrategySingletonGetter, // get_Instance() + List field
};

@interface IL2CPPHeapWalker : NSObject

+ (instancetype)shared;

#pragma mark - Existing

- (NSArray<NSDictionary *> *)findClassesWithStaticFields:(NSString *)keyword;
- (void *)getStaticFieldAddress:(Il2CppClass *)klass field:(FieldInfo *)field;

#pragma mark - Auto-discovery

// Tự động dò class entity: class có get_Position + tên khớp heuristic
- (Il2CppClass *)autoDetectEntityClass;

// Tự động dò tất cả instance của entity class (thử nhiều strategy)
- (NSArray<NSValue *> *)autoCollectInstancesWithLimit:(NSUInteger)limit;

// Debug: strategy nào đã dùng thành công
- (ESPCollectStrategy)lastStrategy;

// List<T> IL2CPP → NSArray<NSValue *>
- (NSArray<NSValue *> *)readIl2CppList:(void *)listPtr limit:(NSUInteger)limit;

@end
