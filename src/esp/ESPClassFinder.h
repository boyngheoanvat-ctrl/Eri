#import <Foundation/Foundation.h>

@interface ESPClassFinder : NSObject

+ (instancetype)shared;

// Tìm class quản lý entity
- (NSArray<NSDictionary *> *)findEntityManagerClasses;

// Tìm class camera
- (NSArray<NSDictionary *> *)findCameraClasses;

// Tìm class chứa static list entity
- (NSArray<NSDictionary *> *)findClassesWithStaticEntityList;

// Tìm method trả về List<ShowEntity>
- (NSArray<NSDictionary *> *)findMethodsReturningEntityList;

// Full scan — trả về báo cáo
- (NSDictionary *)fullScanReport;

@end
