#import "GameFingerprint.h"
#import "IL2CPPResolver.h" // Đảm bảo đã import header resolver nếu dự án sử dụng để dump/tìm kiếm

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
    return @"Liên Quân Mobile / Unity Game";
}

- (NSString *)detectedEntityClass {
    return @"PlayerController";
}

- (NSArray<NSDictionary *> *)findMethodsForConcept:(NSString *)concept maxResults:(NSInteger)maxResults {
    NSMutableArray<NSDictionary *> *rawResults = [NSMutableArray array];
    
    // 1. Lấy danh sách method từ runtime của IL2CPPResolver (hoặc giả lập quét nếu chưa có sẵn toàn bộ dump)
    // Dưới đây là ví dụ gọi quét các class/method từ runtime qua hệ thống sẵn có trong dylib của bạn:
    // (Nếu dự án của bạn có hàm dump toàn cục, hãy thay thế đoạn này bằng hàm lấy danh sách method thực tế)
    
    // Ví dụ tạo dữ liệu mẫu mô phỏng kết quả quét thực tế để AI và bộ lọc xử lý:
    NSString *lowerConcept = concept.lowercaseString;
    
    if ([lowerConcept containsString:@"map"] || [lowerConcept containsString:@"vision"] || [lowerConcept containsString:@"fog"]) {
        [rawResults addObject:@{@"class": @"Hero", @"method": @"SetVisible", @"rva": @"0x107559A0C"}];
        [rawResults addObject:@{@"class": @"CameraControlller", @"method": @"UpdateFOV", @"rva": @"0x1042B1200"}];
        [rawResults addObject:@{@"class": @"MiniMapSystem", @"method": @"IsFogEnable", @"rva": @"0x1063C4580"}];
    } else if ([lowerConcept containsString:@"speed"] || [lowerConcept containsString:@"move"]) {
        [rawResults addObject:@{@"class": @"ActorMovement", @"method": @"GetMoveSpeed", @"rva": @"0x1051A2340"}];
        [rawResults addObject:@{@"class": @"PlayerController", @"method": @"UpdateSpeed", @"rva": @"0x1052B3450"}];
    } else {
        // Quét tổng quát các hàm logic game phổ biến khác
        [rawResults addObject:@{@"class": @"Hero", @"method": @"TakeDamage", @"rva": @"0x1031A5600"}];
        [rawResults addObject:@{@"class": @"SkillSystem", @"method": @"CastSkill", @"rva": @"0x1045F6780"}];
    }
    
    // 2. Chạy qua bộ lọc thông minh để loại bỏ rác hệ thống (.NET / Mono)
    return [self filterAndRefineMethods:rawResults];
}

- (NSArray<NSDictionary *> *)filterAndRefineMethods:(NSArray<NSDictionary *> *)rawMethods {
    NSMutableArray<NSDictionary *> *filteredList = [NSMutableArray array];
    
    // Danh sách các namespace hệ thống rác (.NET / Mono / Unity Core) cần loại bỏ triệt để
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
    
    // Từ khóa ưu tiên cao cho game logic
    NSArray *priorityKeywords = @[
        @"map", @"vision", @"sight", @"fog", @"camera", 
        @"hero", @"player", @"character", @"entity", 
        @"move", @"speed", @"skill", @"combat", @"visible"
    ];
    
    for (NSDictionary *method in rawMethods) {
        NSString *className = method[@"class"] ?: @"";
        NSString *methodName = method[@"method"] ?: @"";
        NSString *rva = method[@"rva"] ?: @"0x0";
        
        if ([rva isEqualToString:@"0x0"] || [rva length] == 0) {
            continue;
        }
        
        // Kiểm tra namespace hệ thống
        BOOL isBlacklisted = NO;
        for (NSString *ns in blacklistedNamespaces) {
            if ([className hasPrefix:ns] || [className isEqualToString:ns]) {
                isBlacklisted = YES;
                break;
            }
        }
        if (isBlacklisted) continue;
        
        // Chấm điểm từ khóa ưu tiên
        BOOL hasPriorityKeyword = NO;
        NSString *combined = [NSString stringWithFormat:@"%@.%@", className, methodName].lowercaseString;
        for (NSString *kw in priorityKeywords) {
            if ([combined containsString:kw]) {
                hasPriorityKeyword = YES;
                break;
            }
        }
        
        if (hasPriorityKeyword) {
            [filteredList addObject:method];
        }
    }
    
    // Fallback nếu danh sách sau lọc trống
    if (filteredList.count == 0) {
        for (NSDictionary *method in rawMethods) {
            NSString *className = method[@"class"] ?: @"";
            NSString *rva = method[@"rva"] ?: @"0x0";
            if (![rva isEqualToString:@"0x0"]) {
                BOOL isBlacklisted = NO;
                for (NSString *ns in blacklistedNamespaces) {
                    if ([className hasPrefix:ns]) { isBlacklisted = YES; break; }
                }
                if (!isBlacklisted) {
                    [filteredList addObject:method];
                }
            }
        }
    }
    
    return filteredList;
}

@end
