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

- (NSArray<NSDictionary *> *)filterAndRefineMethods:(NSArray<NSDictionary *> *)rawMethods {
    NSMutableArray<NSDictionary *> *filteredList = [NSMutableArray array];
    
    // Danh sách các namespace hệ thống rác (.NET / Mono / Unity Core) cần loại bỏ
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
    
    // Từ khóa ưu tiên cao cho game logic (Map, Vision, Camera, Hero, Player)
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
    
    // Fallback nếu không khớp từ khóa ưu tiên nhưng không phải rác hệ thống
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
