#import "AIESPTool.h"
#import "ESPClassFinder.h"

@implementation AIESPTool

+ (void)registerAll {
    [AITool registerTool:[AITool toolWithName:@"find_entity_manager"
        description:@"Tu dong tim class quan ly entity (ShowPlayerManager, EntityManager...)"
        parameters:@{@"type": @"object", @"properties": @{}}
        handler:^id(NSDictionary *args) {
            NSArray *results = [[ESPClassFinder shared] findEntityManagerClasses];
            NSMutableArray *top = [NSMutableArray array];
            for (NSInteger i = 0; i < MIN(10, (NSInteger)results.count); i++) {
                [top addObject:results[i]];
            }
            return @{@"count": @(results.count), @"top": top};
        }]];

    [AITool registerTool:[AITool toolWithName:@"find_camera_class"
        description:@"Tim class Camera co method WorldToScreenPoint"
        parameters:@{@"type": @"object", @"properties": @{}}
        handler:^id(NSDictionary *args) {
            NSArray *results = [[ESPClassFinder shared] findCameraClasses];
            return @{@"count": @(results.count), @"classes": results};
        }]];

    [AITool registerTool:[AITool toolWithName:@"find_static_entity_lists"
        description:@"Tim class co static field chua list entity"
        parameters:@{@"type": @"object", @"properties": @{}}
        handler:^id(NSDictionary *args) {
            NSArray *results = [[ESPClassFinder shared] findClassesWithStaticEntityList];
            NSMutableArray *top = [NSMutableArray array];
            for (NSInteger i = 0; i < MIN(10, (NSInteger)results.count); i++) {
                [top addObject:results[i]];
            }
            return @{@"count": @(results.count), @"top": top};
        }]];

    [AITool registerTool:[AITool toolWithName:@"find_entity_list_methods"
        description:@"Tim method tra ve list entity"
        parameters:@{@"type": @"object", @"properties": @{}}
        handler:^id(NSDictionary *args) {
            NSArray *results = [[ESPClassFinder shared] findMethodsReturningEntityList];
            NSMutableArray *top = [NSMutableArray array];
            for (NSInteger i = 0; i < MIN(20, (NSInteger)results.count); i++) {
                [top addObject:results[i]];
            }
            return @{@"count": @(results.count), @"methods": top};
        }]];

    [AITool registerTool:[AITool toolWithName:@"full_esp_scan"
        description:@"Quet toan bo — tra ve report day du ve class quan ly entity + camera"
        parameters:@{@"type": @"object", @"properties": @{}}
        handler:^id(NSDictionary *args) {
            return [[ESPClassFinder shared] fullScanReport];
        }]];
}

@end
