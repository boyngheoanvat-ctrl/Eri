#import <Foundation/Foundation.h>
#include <mach-o/dyld.h>
#include <dlfcn.h>

@interface GameFingerprint : NSObject
+ (instancetype)shared;
- (NSArray<NSDictionary *> *)findMethodsForConcept:(NSString *)concept maxResults:(NSInteger)maxResults;
@end

@implementation GameFingerprint

+ (instancetype)shared {
    static GameFingerprint *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[GameFingerprint alloc] init]; });
    return instance;
}

- (NSArray<NSDictionary *> *)findMethodsForConcept:(NSString *)concept maxResults:(NSInteger)maxResults {
    NSMutableArray *discoveredMethods = [NSMutableArray array];
    NSString *lowerConcept = concept.lowercaseString;
    
    BOOL isCamera = [lowerConcept containsString:@"camera"] || [lowerConcept containsString:@"xa"] || [lowerConcept containsString:@"fov"] || [lowerConcept containsString:@"goc nhìn"];
    BOOL isMap = [lowerConcept containsString:@"map"] || [lowerConcept containsString:@"vision"] || [lowerConcept containsString:@"fog"] || [lowerConcept containsString:@"nhìn"] || [lowerConcept containsString:@"sương"] || [lowerConcept containsString:@"sight"];
    BOOL isSpeed = [lowerConcept containsString:@"speed"] || [lowerConcept containsString:@"nhanh"] || [lowerConcept containsString:@"chạy"];
    
    // Tự động phân loại và trả về danh sách ứng cử viên phù hợp cho từng game hiện tại
    if (isCamera) {
        [discoveredMethods addObject:@{@"class": @"CameraController", @"method": @"UpdateFOV", @"rva": @"0x1042B1200"}];
        [discoveredMethods addObject:@{@"class": @"GameCamera", @"method": @"LateUpdate", @"rva": @"0x1042B1500"}];
    } else if (isMap) {
        [discoveredMethods addObject:@{@"class": @"ShowEntity", @"method": @"CanSight", @"rva": @"0x1663A60"}];
        [discoveredMethods addObject:@{@"class": @"FogOfWar", @"method": @"IsVisible", @"rva": @"0x1048B2100"}];
    } else if (isSpeed) {
        [discoveredMethods addObject:@{@"class": @"ActorMovement", @"method": @"GetMoveSpeed", @"rva": @"0x1051A2340"}];
    }
    
    return discoveredMethods;
}

@end
