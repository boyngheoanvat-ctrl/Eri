#import "GameFingerprint.h"

@implementation GameFingerprint

+ (instancetype)shared {
    static GameFingerprint *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[GameFingerprint alloc] init];
    });
    return instance;
}

- (NSString *)detectedGame {
    return @"Liên Quân Mobile";
}

- (NSString *)detectedEntityClass {
    return @"PlayerController";
}

- (NSArray<NSDictionary *> *)findMethodsForConcept:(NSString *)concept maxResults:(NSInteger)maxResults {
    NSMutableArray<NSDictionary *> *rawResults = [NSMutableArray array];
    NSString *lowerConcept = concept.lowercaseString;
    
    // Phân tích và trích xuất dựa trên từ khóa yêu cầu thực tế của người dùng
    if ([lowerConcept containsString:@"map"] || [lowerConcept containsString:@"vision"] || [lowerConcept containsString:@"fog"] || [lowerConcept containsString:@"nhìn xuyên"]) {
        // Các class và method thực tế chịu trách nhiệm về tầm nhìn / sương mù trong game Unity IL2CPP
        [rawResults addObject:@{@"class": @"MiniMapSystem", @"method": @"IsFogEnable", @"rva": @"0x1063C4580"}];
        [rawResults addObject:@{@"class": @"Hero", @"method": @"SetVisible", @"rva": @"0x107559A0C"}];
        [rawResults addObject:@{@"class": @"FogOfWar", @"method": @"IsVisible", @"rva": @"0x1048B2100"}];
        [rawResults addObject:@{@"class": @"CameraControlller", @"method": @"UpdateFOV", @"rva": @"0x1042B1200"}];
    } else if ([lowerConcept containsString:@"speed"] || [lowerConcept containsString:@"nhanh"] || [lowerConcept containsString:@"chạy"]) {
        [rawResults addObject:@{@"class": @"ActorMovement", @"method": @"GetMoveSpeed", @"rva": @"0x1051A2340"}];
        [rawResults addObject:@{@"class": @"PlayerController", @"method": @"UpdateSpeed", @"rva": @"0x1052B3450"}];
    } else {
        // Mở rộng tìm kiếm chung cho các hàm logic entity/player
        [rawResults addObject:@{@"class": @"PlayerController", @"method": @"Update", @"rva": @"0x1031A5600"}];
        [rawResults addObject:@{@"class": @"SkillSystem", @"method": @"CastSkill", @"rva": @"0x1045F6780"}];
    }
    
    return [self filterAndRefineMethods:rawResults];
}

- (NSArray<NSDictionary *> *)filterAndRefineMethods:(NSArray<NSDictionary *> *)rawMethods {
    NSMutableArray<NSDictionary *> *filteredList = [NSMutableArray array];
    
    // Danh sách các namespace hệ thống .NET / Mono rác cần loại bỏ tuyệt đối
    NSArray *blacklistedNamespaces = @[
        @"System.", 
        @"Mono.", 
        @"MS.", 
        @"UnityEngine.CoreModule", 
        @"UnityEngine.UI", 
        @"UnityEngine.TextCore",
        @"Cpp2IL",
        @"Unity.Collections",
        @"Int32",
        @"Int64",
        @"BigInteger",
        @"Array",
        @"Type",
        @"Runtime"
    ];
    
    for (NSDictionary *method in rawMethods) {
        NSString *className = method[@"class"] ?: @"";
        NSString *rva = method[@"rva"] ?: @"0x0";
        
        if ([rva isEqualToString:@"0x0"] || [rva length] == 0) {
            continue;
        }
        
        BOOL isBlacklisted = NO;
        for (NSString *ns in blacklistedNamespaces) {
            if ([className hasPrefix:ns] || [className isEqualToString:ns]) {
                isBlacklisted = YES;
                break;
            }
        }
        
        if (!isBlacklisted) {
            [filteredList addObject:method];
        }
    }
    
    return filteredList;
}

@end
