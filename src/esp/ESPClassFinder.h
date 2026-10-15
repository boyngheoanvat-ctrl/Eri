#import <Foundation/Foundation.h>
#import "IL2CPPResolver.h"

@interface ESPTargetClass : NSObject
@property (nonatomic, assign) Il2CppClass *klass;
@property (nonatomic, strong) NSString *className;
@property (nonatomic, assign) int32_t positionOffset;
@property (nonatomic, assign) int32_t hpOffset;
@property (nonatomic, assign) int32_t maxHpOffset;
@end

@interface ESPClassFinder : NSObject
+ (instancetype)shared;
- (NSArray<ESPTargetClass *> *)scanForPotentialTargets;
- (NSArray *)findEntityManagerClasses;
- (NSArray *)findCameraClasses;
- (NSArray *)findClassesWithStaticEntityList;
- (NSArray *)findMethodsReturningEntityList;
- (NSString *)fullScanReport;
@end
