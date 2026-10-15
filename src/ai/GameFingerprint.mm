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

        // Position — nới rộng keyword
        if ([ml containsString:@"position"] ||
            [ml containsString:@"getpos"] ||
            [ml containsString:@"get_pos"] ||
            [ml containsString:@"worldpos"] ||
            [ml containsString:@"vec3"] ||
            [ml isEqualToString:@"get_transform"]) hasPosition = YES;

        // Health
        if ([ml containsString:@"hp"] ||
            [ml containsString:@"health"] ||
            [ml containsString:@"life"]) hasHp = YES;

        // Name
        if ([ml isEqualToString:@"get_name"] ||
            [ml containsString:@"rolename"] ||
            [ml containsString:@"playername"] ||
            [ml isEqualToString:@"get_nickname"]) hasName = YES;

        // Team
        if ([ml containsString:@"team"] || [ml containsString:@"camp"]) hasTeam = YES;

        // Dead
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

    // KHÔNG scan mọi class nữa — tránh match sai (VD: BigInteger.op_Division)
    if (!gEntityClass) {
        NSLog(@"[GameFingerprint] No entity class — skip scan");
        return @[];
    }

    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (!r) return @[];
    if (![r resolve]) return @[];
    [r attachCurrentThread];

    NSMutableArray *all = [NSMutableArray array];

    uint16_t mCount = 0;
    NSArray<NSValue *> *mList = [r class_get_methods:gEntityClass count:&mCount];

    for (uint16_t j = 0; j < mCount; j++) {
        MethodInfo *m = (MethodInfo *)mList[j].pointerValue;
        if (!m || (uintptr_t)m < 0x1000) continue;
        const char *mn = [r method_get_name:m];
        if (!mn) continue;
        NSString *mName = [NSString stringWithUTF8String:mn];
        if (!mName || mName.length == 0) continue;

        if ([mName hasPrefix:@".ctor"] ||
            [mName hasPrefix:@".cctor"] ||
            [mName isEqualToString:@"ToString"] ||
            [mName isEqualToString:@"GetHashCode"] ||
            [mName isEqualToString:@"Equals"] ||
            [mName isEqualToString:@"Finalize"] ||
            [mName isEqualToString:@"GetType"]) continue;

        void *ptr = [r method_get_pointer:m];
        uint64_t rva = ptr ? (uint64_t)((uintptr_t)ptr) : 0;
        uint32_t token = [r method_get_token:m];

        [all addObject:@{
            @"class": gEntityClassName ?: @"?",
            @"method": mName,
            @"rva": [NSString stringWithFormat:@"0x%llX", rva],
            @"token": [NSString stringWithFormat:@"0x%X", token],
        }];
    }

    // Nếu có keywords → sort (match trước)
    NSArray *keywords = [self keywordsForConcept:concept];
    if (keywords.count > 0) {
        NSMutableArray *sorted = [NSMutableArray array];
        NSMutableArray *others = [NSMutableArray array];

        for (NSDictionary *m in all) {
            NSString *ml = [m[@"method"] lowercaseString];
            BOOL match = NO;
            for (NSString *kw in keywords) {
                if ([ml containsString:kw]) { match = YES; break; }
            }
            if (match) [sorted addObject:m];
            else [others addObject:m];
        }

        NSMutableArray *final = [NSMutableArray array];
        [final addObjectsFromArray:sorted];
        [final addObjectsFromArray:others];

        if (final.count > (NSUInteger)max) {
            [final removeObjectsInRange:NSMakeRange(max, final.count - max)];
        }
        return final;
    }

    if (all.count > (NSUInteger)max) {
        [all removeObjectsInRange:NSMakeRange(max, all.count - max)];
    }
    return all;
}

- (NSArray<NSString *> *)keywordsForConcept:(NSString *)concept {
    NSString *c = [concept lowercaseString];

    // Map/Vision — keyword CHÍNH XÁC, không dùng "view"/"show"/"hide"/"see" ngắn
    if ([c containsString:@"map"] || [c containsString:@"vision"] ||
        [c containsString:@"sight"] || [c containsString:@"visible"] ||
        [c containsString:@"nhin"] || [c containsString:@"xuyen"]) {
        return @[
            @"cansight", @"calcvisible", @"refreshvisible", @"setvisible",
            @"cansse", @"isvisible", @"hasvision", @"isinsight",
            @"setvision", @"checkvisible", @"updatevisible", @"onseeentity",
            @"sightrange", @"visionrange", @"visible",
        ];
    }

    if ([c containsString:@"speed"] || [c containsString:@"move"] ||
        [c containsString:@"toc"]) {
        return @[@"speed", @"movespeed", @"runspd", @"movespd", @"velocity", @"runspeed"];
    }

    if ([c containsString:@"damage"] || [c containsString:@"attack"] ||
        [c containsString:@"satthuong"]) {
        return @[@"damage", @"attack", @"atk", @"hitdamage"];
    }

    if ([c containsString:@"health"] || [c containsString:@"hp"] ||
        [c containsString:@"mau"]) {
        return @[@"hp", @"health", @"maxhp", @"hpmax", @"life", @"heal"];
    }

    if ([c containsString:@"mana"] || [c containsString:@"mp"]) {
        return @[@"mana", @"mp", @"maxmp", @"energy"];
    }

    if ([c containsString:@"money"] || [c containsString:@"gold"] ||
        [c containsString:@"tien"] || [c containsString:@"vang"]) {
        return @[@"gold", @"money", @"coin", @"cash", @"diamond"];
    }

    if ([c containsString:@"cooldown"] || [c containsString:@"cd"] ||
        [c containsString:@"hoi"]) {
        return @[@"cooldown", @"cd", @"skillcd", @"resetcd"];
    }

    return @[];
}

#pragma mark - Fallback (không dùng nữa)

- (NSArray<NSDictionary *> *)scanAllClassesForConcept:(NSString *)concept
                                           maxResults:(NSInteger)max {
    return @[];
}

@end
