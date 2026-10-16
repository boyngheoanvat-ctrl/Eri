#import <Foundation/Foundation.h>
#import "IL2CPPResolver.h"

typedef NS_ENUM(NSInteger, ESPCollectStrategy) {
    ESPCollectStrategyNone = 0,
    ESPCollectStrategySingletonList,
    ESPCollectStrategyStaticList,
    ESPCollectStrategySingletonGetter,
};

@interface IL2CPPHeapWalker : NSObject

+ (instancetype)shared;

- (NSArray<NSDictionary *> *)findClassesWithStaticFields:(NSString *)keyword;
- (void *)getStaticFieldAddress:(Il2CppClass *)klass field:(FieldInfo *)field;
- (Il2CppClass *)autoDetectEntityClass;
- (NSArray<NSValue *> *)autoCollectInstancesWithLimit:(NSUInteger)limit;
- (ESPCollectStrategy)lastStrategy;
- (NSArray<NSValue *> *)readIl2CppList:(void *)listPtr limit:(NSUInteger)limit;

@end
