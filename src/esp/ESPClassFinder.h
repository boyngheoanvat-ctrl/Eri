#import <Foundation/Foundation.h>

@interface ESPClassFinder : NSObject

+ (instancetype)shared;

- (NSArray<NSDictionary *> *)findEntityManagerClasses;
- (NSArray<NSDictionary *> *)findCameraClasses;
- (NSArray<NSDictionary *> *)findClassesWithStaticEntityList;
- (NSArray<NSDictionary *> *)findMethodsReturningEntityList;
- (NSDictionary *)fullScanReport;

@end
