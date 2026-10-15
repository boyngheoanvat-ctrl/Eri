#import <Foundation/Foundation.h>

@interface GameFingerprint : NSObject
+ (NSArray<NSDictionary *> *)filterAndRefineMethods:(NSArray<NSDictionary *> *)rawMethods;
@end

@implementation GameFingerprint

+ (NSArray<NSDictionary *> *)filterAndRefineMethods:(NSArray<NSDictionary *> *)rawMethods {
    NSMutableArray<NSDictionary *> *filteredList = [NSMutableArray array];
    
    // Danh sách các namespace hệ thống cần loại bỏ triệt để (Rác .NET / Mono / Unity Core)
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
    
    // Danh sách từ khóa ưu tiên cao cho các tính năng Mod/Hack (Map, Vision, Speed, Combat)
    NSArray *priorityKeywords = @[
        @"map", @"vision", @"sight", @"fog", @"camera", 
        @"hero", @"player", @"character", @"entity", 
        @"move", @"speed", @"skill", @"combat", @"visible"
    ];
    
    for (NSDictionary *method in rawMethods) {
        NSString *className = method[@"class"] ?: @"";
        NSString *methodName = method[@"method"] ?: @"";
        NSString *rva = method[@"rva"] ?: @"0x0";
        
        // Bỏ qua nếu RVA bằng 0 hoặc không hợp lệ
        if ([rva isEqualToString:@"0x0"] || [rva length] == 0) {
            continue;
        }
        
        // Kiểm tra xem class có thuộc namespace hệ thống bị cấm không
        BOOL isBlacklisted = NO;
        for (NSString *ns in blacklistedNamespaces) {
            if ([className hasPrefix:ns] || [className isEqualToString:ns]) {
                isBlacklisted = YES;
                break;
            }
        }
        
        if (isBlacklisted) continue; // Bỏ qua các class rác hệ thống
        
        // Chấm điểm ưu tiên dựa trên từ khóa game logic
        BOOL hasPriorityKeyword = NO;
        NSString *combined = [NSString stringWithFormat:@"%@.%@", className, methodName].lowercaseString;
        for (NSString *kw in priorityKeywords) {
            if ([combined containsString:kw]) {
                hasPriorityKeyword = YES;
                break;
            }
        }
        
        // Chỉ thêm vào danh sách nếu khớp từ khóa game hoặc ít nhất là class custom của game
        if (hasPriorityKeyword) {
            [filteredList addObject:method];
        }
    }
    
    // Nếu lọc xong mà danh sách trống (đề phòng game dùng tên obfuscate), trả về danh sách đã bỏ rác hệ thống
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
