#import "GameFingerprint.h"
#import "IL2CPPResolver.h"

static NSString *gDetectedGame = nil;
static Il2CppClass *gEntityClass = NULL;
static NSString *gEntityClassName = nil;
static BOOL gScanned = NO;
static NSLock *gScanLock = nil;

@implementation GameFingerprint

+ (instancetype)shared {
    static GameFingerprint *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[GameFingerprint alloc] init];
        gScanLock = [[NSLock alloc] init];
    });
    return instance;
}

#pragma mark - Scan

- (void)scan {
    [gScanLock lock];
    if (gScanned) { [gScanLock unlock]; return; }
    gScanned = YES;
    [gScanLock unlock];

    @try {
        IL2CPPResolver *r = [IL2CPPResolver shared];
        if (!r) return;
        [r attachCurrentThread];
        if (![r resolve]) return;

        Il2CppDomain *domain = [r domain_get];
        if (!domain || (uintptr_t)domain < 0x1000) return;
        if (!domain->assemblies) return;

        int asmCount = (int)domain->assembly_count;
        if (asmCount <= 0 || asmCount > 10000) return;

        Il2CppClass *best = NULL;
        NSUInteger bestScore = 0;
        NSString *bestName = nil;

        int maxAsm = MIN(asmCount, 8);
        for (int a = 0; a < maxAsm; a++) {
            Il2CppAssembly *asm_ = domain->assemblies[a];
            if (!asm_ || (uintptr_t)asm_ < 0x1000) continue;
            Il2CppImage *image = [r assembly_get_image:asm_];
            if (!image || (uintptr_t)image < 0x1000) continue;

            size_t count = [r image_get_class_count:image];
            if (count == 0 || count > 100000) continue;
            size_t limit = MIN(count, (size_t)2000);

            for (size_t i = 0; i < limit; i++) {
                @autoreleasepool {
                    Il2CppClass *k = [r image_get_class:image index:i];
                    if (!k || (uintptr_t)k < 0x1000) continue;

                    const char *cn = [r class_get_name:k];
                    if (!cn) continue;
                    NSString *clsName = [NSString stringWithUTF8String:cn];
                    if (!clsName || clsName.length < 2) continue;

                    NSString *cl = clsName.lowercaseString;

                    if ([cl containsString:@"util"] ||
                        [cl containsString:@"helper"] ||
                        [cl containsString:@"config"] ||
                        [cl containsString:@"manager"] ||
                        [cl containsString:@"system"] ||
                        [cl containsString:@"panel"] ||
                        [cl containsString:@"view"] ||
                        [cl containsString:@"ui"] ||
                        [cl containsString:@"data"] ||
                        [cl containsString:@"info"] ||
                        [cl containsString:@"factory"] ||
                        [cl containsString:@"builder"] ||
                        [cl containsString:@"abstract"] ||
                        [cl containsString:@"interface"]) continue;

                    NSUInteger score = [self scoreEntityClass:k resolver:r name:clsName];
                    if (score > bestScore) {
                        bestScore = score;
                        best = k;
                        bestName = clsName;
                    }
                }
            }
        }

        if (best && bestScore >= 20) {
            gEntityClass = best;
            gEntityClassName = bestName;
            NSLog(@"[GameFingerprint] entity class = %@ (score=%lu)",
                  bestName, (unsigned long)bestScore);
        }

        NSString *bid = [[NSBundle mainBundle] bundleIdentifier].lowercaseString ?: @"";
        if ([bid containsString:@"mobilelegends"] || [bid containsString:@"moonton"]) {
            gDetectedGame = @"MLBB";
        } else if ([bid containsString:@"lienquan"] || [bid containsString:@"garena"]) {
            gDetectedGame = @"LienQuan";
        } else if ([bid containsString:@"freefire"]) {
            gDetectedGame = @"Free Fire";
        } else if ([bid containsString:@"pubg"] || [bid containsString:@"tencent"]) {
            gDetectedGame = @"PUBG Mobile";
        } else {
            gDetectedGame = @"Unity Game";
        }

        NSLog(@"[GameFingerprint] game = %@, entity = %@",
              gDetectedGame, gEntityClassName ?: @"(none)");

    } @catch (NSException *e) {
        NSLog(@"[GameFingerprint] scan exception: %@", e);
    }
}

- (NSUInteger)scoreEntityClass:(Il2CppClass *)klass resolver:(IL2CPPResolver *)r name:(NSString *)clsName {
    NSUInteger score = 0;
    NSString *cl = clsName.lowercaseString;

    if ([cl containsString:@"entity"])    score += 20;
    if ([cl containsString:@"fighter"])   score += 20;
    if ([cl containsString:@"hero"])      score += 15;
    if ([cl containsString:@"player"])    score += 15;
    if ([cl containsString:@"character"]) score += 15;
    if ([cl containsString:@"monster"])   score += 10;
    if ([cl containsString:@"mob"])       score += 10;
    if ([cl containsString:@"unit"])      score += 10;
    if ([cl containsString:@"actor"])     score += 10;
    if ([cl containsString:@"avatar"])    score += 10;

    uint16_t mCount = 0;
    NSArray<NSValue *> *mList = [r class_get_methods:klass count:&mCount];
    if (mCount == 0 || mCount > 5000) return 0;

    BOOL hasPosition = NO;
    BOOL hasHp = NO;
    BOOL hasName = NO;
    BOOL hasTeam = NO;
    BOOL hasDead = NO;

    for (uint16_t j = 0; j < mCount; j++) {
        MethodInfo *m = (MethodInfo *)mList[j].pointerValue;
        if (!m || (uintptr_t)m < 0x1000) continue;
        const char *mn = [r method_get_name:m];
        if (!mn) continue;
        NSString *mName = [NSString stringWithUTF8String:mn];
        if (!mName) continue;
        NSString *ml = mName.lowercaseString;

        if ([ml containsString:@"position"] ||
            [ml containsString:@"getpos"] ||
            [ml containsString:@"get_pos"] ||
            [ml containsString:@"worldpos"] ||
            [ml containsString:@"vec3"] ||
            [ml isEqualToString:@"get_transform"]) hasPosition = YES;

        if ([ml containsString:@"hp"] ||
            [ml containsString:@"health"] ||
            [ml containsString:@"life"]) hasHp = YES;

        if ([ml isEqualToString:@"get_name"] ||
            [ml containsString:@"rolename"] ||
            [ml containsString:@"playername"] ||
            [ml isEqualToString:@"get_nickname"]) hasName = YES;

        if ([ml containsString:@"team"] || [ml containsString:@"camp"]) hasTeam = YES;

        if ([ml containsString:@"death"] || [ml containsString:@"dead"] ||
            [ml containsString:@"alive"] || [ml containsString:@"die"]) hasDead = YES;
    }

    if (hasPosition) score += 30;
    if (hasHp)       score += 20;
    if (hasName)     score += 15;
    if (hasTeam)     score += 10;
    if (hasDead)     score += 5;

    if (!hasPosition) score = 0;
    return score;
}

#pragma mark - Public

- (NSString *)detectedGame {
    if (!gScanned) [self scan];
    return gDetectedGame ?: @"Unknown";
}

- (NSString *)detectedEntityClass {
    if (!gScanned) [self scan];
    return gEntityClassName ?: @"Unknown";
}

- (NSDictionary *)fingerprintInfo {
    return @{
        @"game": gDetectedGame ?: @"Unknown",
        @"entity_class": gEntityClassName ?: @"Unknown",
    };
}

- (NSArray<NSDictionary *> *)findMethodsForConcept:(NSString *)concept
                                         maxResults:(NSInteger)max {
    if (!gScanned) [self scan];
    if (max <= 0) max = 20;

    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (!r) return @[];
    if (![r resolve]) return @[];
    [r attachCurrentThread];

    NSMutableArray *scoredMethods = [NSMutableArray array];
    NSArray *keywords = [self keywordsForConcept:concept];

    Il2CppDomain *domain = [r domain_get];
    if (!domain || !domain->assemblies) return @[];

    // 1. Quét trên Entity Class trước nếu có (độ chính xác cao nhất)
    if (gEntityClass) {
        uint16_t mCount = 0;
        NSArray<NSValue *> *mList = [r class_get_methods:gEntityClass count:&mCount];
        for (uint16_t j = 0; j < mCount; j++) {
            MethodInfo *m = (MethodInfo *)mList[j].pointerValue;
            if (!m || (uintptr_t)m < 0x1000) continue;
            const char *mn = [r method_get_name:m];
            if (!mn) continue;
            NSString *mName = [NSString stringWithUTF8String:mn];
            if (!mName) continue;

            if ([mName hasPrefix:@".ctor"] || [mName hasPrefix:@".cctor"] ||
                [mName isEqualToString:@"ToString"] || [mName isEqualToString:@"GetHashCode"]) {
                continue;
            }

            NSInteger score = 10; // Điểm nền cho entity class
            NSString *ml = mName.lowercaseString;
            for (NSString *kw in keywords) {
                if ([ml containsString:kw]) {
                    score += 50;
                    break;
                }
            }

            void *ptr = [r method_get_pointer:m];
            uint64_t rva = ptr ? (uint64_t)((uintptr_t)ptr) : 0;
            uint32_t token = [r method_get_token:m];

            [scoredMethods addObject:@{
                @"class": gEntityClassName ?: @"Entity",
                @"method": mName,
                @"rva": [NSString stringWithFormat:@"0x%llX", rva],
                @"token": [NSString stringWithFormat:@"0x%X", token],
                @"score": @(score)
            }];
        }
    }

    // 2. Quét mở rộng toàn cục an toàn (Crash-safe global fallback) để đảm bảo hỏi gì cũng ra kết quả
    int maxAsm = MIN((int)domain->assembly_count, 3);
    for (int a = 0; a < maxAsm; a++) {
        Il2CppAssembly *asm_ = domain->assemblies[a];
        if (!asm_ || (uintptr_t)asm_ < 0x1000) continue;
        Il2CppImage *image = [r assembly_get_image:asm_];
        if (!image || (uintptr_t)image < 0x1000) continue;

        size_t count = [r image_get_class_count:image];
        size_t limit = MIN(count, (size_t)400); // Giới hạn số lượng class mỗi image tránh quá tải

        for (size_t i = 0; i < limit; i++) {
            @autoreleasepool {
                Il2CppClass *klass = [r image_get_class:image index:i];
                if (!klass || (uintptr_t)klass < 0x1000) continue;

                const char *cname = [r class_get_name:klass];
                if (!cname) continue;
                NSString *clsName = [NSString stringWithUTF8String:cname];
                if (!clsName) continue;

                // Bỏ qua các class hệ thống
                if ([clsName hasPrefix:@"System."] || [clsName hasPrefix:@"Mono."] || [clsName hasPrefix:@"UnityEngine."]) {
                    continue;
                }

                uint16_t mCount = 0;
                NSArray<NSValue *> *mList = [r class_get_methods:klass count:&mCount];
                if (mCount == 0 || mCount > 300) continue;

                for (uint16_t j = 0; j < mCount; j++) {
                    MethodInfo *m = (MethodInfo *)mList[j].pointerValue;
                    if (!m || (uintptr_t)m < 0x1000) continue;
                    const char *mn = [r method_get_name:m];
                    if (!mn) continue;
                    NSString *mName = [NSString stringWithUTF8String:mn];
                    if (!mName) continue;

                    if ([mName hasPrefix:@".ctor"] || [mName hasPrefix:@".cctor"] ||
                        [mName isEqualToString:@"ToString"] || [mName isEqualToString:@"GetHashCode"]) {
                        continue;
                    }

                    NSString *ml = mName.lowercaseString;
                    NSInteger score = 0;
                    for (NSString *kw in keywords) {
                        if ([ml containsString:kw]) {
                            score += 40;
                            break;
                        }
                    }

                    if (score > 0) {
                        void *ptr = [r method_get_pointer:m];
                        uint64_t rva = ptr ? (uint64_t)((uintptr_t)ptr) : 0;
                        uint32_t token = [r method_get_token:m];

                        [scoredMethods addObject:@{
                            @"class": clsName,
                            @"method": mName,
                            @"rva": [NSString stringWithFormat:@"0x%llX", rva],
                            @"token": [NSString stringWithFormat:@"0x%X", token],
                            @"score": @(score)
                        }];
                    }
                }
            }
        }
    }

    // Sắp xếp theo điểm số từ cao xuống thấp
    [scoredMethods sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [b[@"score"] compare:a[@"score"]];
    }];

    // Lọc bỏ trùng lặp và giới hạn số lượng kết quả trả về
    NSMutableArray *finalResults = [NSMutableArray array];
    NSMutableSet *seenSignatures = [NSMutableSet set];
    for (NSDictionary *item in scoredMethods) {
        NSString *sig = [NSString stringWithFormat:@"%@.%@", item[@"class"], item[@"method"]];
        if (![seenSignatures containsObject:sig]) {
            [seenSignatures addObject:sig];
            [finalResults addObject:item];
            if (finalResults.count >= (NSUInteger)max) break;
        }
    }

    return finalResults;
}

- (NSArray<NSString *> *)keywordsForConcept:(NSString *)concept {
    NSString *c = [concept lowercaseString];
    NSMutableArray *keywords = [NSMutableArray array];

    // 1. Nhóm Map / Tầm nhìn / Xuyên sương mù / Camera
    if ([c containsString:@"map"] || [c containsString:@"vision"] || [c containsString:@"sight"] || 
        [c containsString:@"visible"] || [c containsString:@"nhin"] || [c containsString:@"xuyen"] || 
        [c containsString:@"camera"] || [c containsString:@"goc nhìn"]) {
        [keywords addObjectsFromArray:@[
            @"visible", @"sight", @"vision", @"camp", @"team", @"sync", 
            @"camera", @"fov", @"zoom", @"frustum", @"culling", @"isvisible"
        ]];
    }

    // 2. Nhóm Tốc độ / Di chuyển (Speed, fly, noclip, tele)
    if ([c containsString:@"speed"] || [c containsString:@"toc"] || [c containsString:@"nhanh"] || 
        [c containsString:@"bay"] || [c containsString:@"tele"] || [c containsString:@"di chuyen"]) {
        [keywords addObjectsFromArray:@[
            @"speed", @"velocity", @"move", @"run", @"walk", @"fly", 
            @"teleport", @"position", @"pos", @"transform", @"movement"
        ]];
    }

    // 3. Nhóm Sát thương / Đánh (Damage, one hit, atk speed)
    if ([c containsString:@"damage"] || [c containsString:@"sat thuong"] || [c containsString:@"danh"] || 
        [c containsString:@"attack"] || [c containsString:@"dmg"] || [c containsString:@"onehit"]) {
        [keywords addObjectsFromArray:@[
            @"damage", @"atk", @"attack", @"hit", @"crit", @"power", 
            @"force", @"gore", @"hurt", @"damagefactor", @"multiplier"
        ]];
    }

    // 4. Nhóm Máu / Hồi phục / Bất tử (HP, godmode, heal)
    if ([c containsString:@"health"] || [c containsString:@"hp"] || [c containsString:@"mau"] || 
        [c containsString:@"bat tu"] || [c containsString:@"god"] || [c containsString:@"hoi"]) {
        [keywords addObjectsFromArray:@[
            @"hp", @"health", @"life", @"maxhp", @"heal", @"god", 
            @"immortal", @"invincible", @"damageable", @"take_damage"
        ]];
    }

    // 5. Nhóm Tiền / Vàng / Tài nguyên (Money, gold, gem)
    if ([c containsString:@"money"] || [c containsString:@"gold"] || [c containsString:@"tien"] || 
        [c containsString:@"vang"] || [c containsString:@"gem"] || [c containsString:@"kim cuong"]) {
        [keywords addObjectsFromArray:@[
            @"gold", @"money", @"coin", @"cash", @"diamond", @"gem", 
            @"currency", @"price", @"cost", @"shop", @"inventory"
        ]];
    }

    // 6. Nhóm Hồi chiêu / Skill (Cooldown, no cd)
    if ([c containsString:@"cooldown"] || [c containsString:@"cd"] || [c containsString:@"hoi chieu"] || 
        [c containsString:@"skill"]) {
        [keywords addObjectsFromArray:@[
            @"cooldown", @"cd", @"skill", @"spell", @"cast", @"delay", 
            @"timer", @"interval", @"ready", @"reset"
        ]];
    }

    // Fallback thông minh: Tự bóc tách từ khóa nếu gặp câu hỏi lạ ngoài danh mục trên
    if (keywords.count == 0) {
        NSArray *words = [c componentsSeparatedByString:@" "];
        for (NSString *w in words) {
            if (w.length > 2) {
                [keywords addObject:w];
            }
        }
    }

    return keywords;
}

@end
