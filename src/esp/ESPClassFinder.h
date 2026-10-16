#import <Foundation/Foundation.h>
#import "IL2CPPResolver.h"

@interface ESPTargetClass : NSObject
@property (nonatomic, assign) Il2CppClass *klass;
@property (nonatomic, strong) NSString *className;
@property (nonatomic, assign) int32_t positionOffset;
@property (nonatomic, assign) int32_t hpOffset;
@property (nonatomic, assign) int32_t maxHpOffset;
@property (nonatomic, assign) float screenX;
@property (nonatomic, assign) float screenY;
@property (nonatomic, assign) float width;
@property (nonatomic, assign) float height;
@property (nonatomic, assign) float distance;
@property (nonatomic, assign) float health;
@property (nonatomic, strong) NSString *name;
@end

@interface ESPClassFinder : NSObject
+ (instancetype)shared;
- (NSArray<ESPTargetClass *> *)scanForPotentialTargets;
+ (NSArray<ESPTargetClass *> *)scanActiveTargets;
- (NSArray *)findEntityManagerClasses;
- (NSArray *)findCameraClasses;
- (NSArray *)findClassesWithStaticEntityList;
- (NSArray *)findMethodsReturningEntityList;
- (NSString *)fullScanReport;
@end
