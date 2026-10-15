#import "GameFingerprint.h"
#import "IL2CPPResolver.h"

static NSDictionary<NSString *, NSArray<NSString *> *> *gSynonyms = nil;
static NSString *gDetectedGame = nil;
static BOOL gScanned = NO;
static NSLock *gScanLock = nil;

@implementation GameFingerprint

+ (instancetype)shared {
    static GameFingerprint *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[GameFingerprint alloc] init];
        gScanLock = [[NSLock alloc] init];
        [instance setupSynonyms];
    });
    return instance;
}

- (void)setupSynonyms {
    gSynonyms = @{
        @"map": @[
            @"CanSight", @"CalcVisible", @"RefreshVisible", @"SetVisible",
            @"CanSee", @"IsVisible", @"HasVision", @"IsInSight",
            @"OnSeeEntity", @"SetVision", @"CanView", @"IsShow",
            @"CheckVisible", @"UpdateVisible",
        ],
        @"speed": @[
            @"SetMoveSpeed", @"get_MoveSpeed",
            @"SetSpeed", @"get_Speed",
            @"SetMoveSpd", @"get_MoveSpd",
            @"SetRunSpeed", @"get_RunSpeed",
            @"SetVelocity", @"get_Velocity",
        ],
        @"damage": @[
            @"SetDamage", @"get_Damage",
            @"SetAttack", @"get_Attack",
            @"SetAttackDamage", @"get_AttackDamage",
            @"SetAtk", @"get_Atk",
            @"SetDamageValue",
        ],
        @"health": @[
            @"SetHp", @"get_Hp",
            @"SetHP", @"get_HP",
            @"SetHealth", @"get_Health",
            @"SetMaxHp", @"get_MaxHp",
            @"SetHpMax", @"get_HpMax",
            @"SetLife", @"get_Life",
        ],
        @"mana": @[
            @"SetMp", @"get_Mp",
            @"SetMana", @"get_Mana",
            @"SetMaxMp", @"get_MaxMp",
            @"SetEnergy", @"get_Energy",
        ],
        @"money": @[
            @"SetGold", @"get_Gold",
            @"SetMoney", @"get_Money",
            @"SetCoin", @"get_Coin",
            @"SetCash", @"get_Cash",
            @"SetDiamond", @"get_Diamond",
        ],
        @"cooldown": @[
            @"SetCooldown", @"get_Cooldown",
            @"SetCd", @"get_Cd",
            @"ResetCooldown", @"ResetCd",
            @"SetSkillCd",
        ],
        @"ammo": @[
            @"SetAmmo", @"get_Ammo",
            @"SetBullet", @"get_Bullet",
            @"SetClip", @"get_Clip",
        ],
        @"level": @[
            @"SetLevel", @"get_Level",
            @"SetLv", @"get_Lv",
            @"SetExp", @"get_Exp",
        ],
    };
}

#pragma mark - Scan

- (void)scan {
    [gScanLock lock];
    if (gScanned) { [gScanLock unlock]; return; }
    gScanned = YES;
    [gScanLock unlock];

    @try {
        IL2CPPResolver *r = [IL2CPPResolver shared];
        if (!r) { gDetectedGame = @"Unknown"; return; }

        [r attachCurrentThread];

        if (![r resolve]) {
            NSLog(@"[GameFingerprint] resolve failed");
            gDetectedGame = @"Unknown";
            return;
        }

        Il2CppDomain *domain = [r domain_get];
        if (!domain || (uintptr_t)domain < 0x1000) {
            NSLog(@"[GameFingerprint] domain null/invalid");
            gDetectedGame = @"Unknown";
            return;
        }
        if (!domain->assemblies) {
            gDetectedGame = @"Unknown";
            return;
        }
        int asmCount = (int)domain->assembly_count;
        if (asmCount <= 0 || asmCount > 10000) {
            gDetectedGame = @"Unknown";
            return;
        }

        BOOL hasCanSight    = [self hasAnyMethodNamed:@[@"CanSight"]        maxAsm:2 maxClass:300];
        BOOL hasCalcVisible = [self hasAnyMethodNamed:@[@"CalcVisible", @"RefreshVisible"] maxAsm:2 maxClass:300];
        BOOL hasSetVisible  = [self hasAnyMethodNamed:@[@"SetVisible"]      maxAsm:2 maxClass:300];
        BOOL hasShowEntity  = [self hasAnyClassNamed:@[@"ShowEntity", @"LogicFighter"] maxAsm:2 maxClass:300];

        if (hasCanSight && hasShowEntity) {
            gDetectedGame = @"MLBB (Mobile Legends)";
        } else if (hasCalcVisible || hasSetVisible) {
            gDetectedGame = @"LienQuan (Arena of Valor)";
        } else {
            NSString *bid = [[NSBundle mainBundle] bundleIdentifier].lowercaseString ?: @"";
            if ([bid containsString:@"freefire"]) {
                gDetectedGame = @"Free Fire";
            } else if ([bid containsString:@"pubg"] || [bid containsString:@"tencent"]) {
                gDetectedGame = @"PUBG Mobile";
            } else {
                gDetectedGame = @"Unity Game (IL2CPP)";
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[GameFingerprint] scan exception: %@", e);
        gDetectedGame = @"Unknown";
    }

    NSLog(@"[GameFingerprint] detected = %@", gDetectedGame);
}

- (NSString *)detectedGame {
    if (!gScanned) {
        [self scan];
    }
    return gDetectedGame ?: @"Unknown";
}

- (NSDictionary *)fingerprintInfo {
    return @{ @"game": gDetectedGame ?: @"Unknown" };
}

- (BOOL)hasAnyMethodNamed:(NSArray<NSString *> *)names maxAsm:(int)maxAsm maxClass:(int)maxClass {
    if (names.count == 0) return NO;

    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (!r) return NO;
    [r attachCurrentThread];
    if (![r resolve]) return NO;

    Il2CppDomain *domain = [r domain_get];
    if (!domain || (uintptr_t)domain < 0x1000) return NO;
    if (!domain->assemblies) return NO;

    int asmLimit = MIN((int)domain->assembly_count, maxAsm);
    for (int a = 0; a < asmLimit; a++) {
        Il2CppAssembly *asm_ = domain->assemblies[a];
        if (!asm_ || (uintptr_t)asm_ < 0x1000) continue;
        Il2CppImage *image = [r assembly_get_image:asm_];
        if (!image || (uintptr_t)image < 0x1000) continue;
        size_t count = [r image_get_class_count:image];
        if (count == 0 || count > 100000) continue;
        size_t limit = MIN(count, (size_t)maxClass);
        for (size_t i = 0; i < limit; i++) {
            Il2CppClass *k = [r image_get_class:image index:i];
            if (!k || (uintptr_t)k < 0x1000) continue;
            uint16_t mCount = 0;
            NSArray<NSValue *> *mList = [r class_get_methods:k count:&mCount];
            for (uint16_t j = 0; j < mCount; j++) {
                MethodInfo *m = (MethodInfo *)mList[j].pointerValue;
                if (!m || (uintptr_t)m < 0x1000) continue;
                const char *mn = [r method_get_name:m];
                if (!mn) continue;
                NSString *n = [NSString stringWithUTF8String:mn];
                if (!n) continue;
                for (NSString *want in names) {
                    if ([n isEqualToString:want]) return YES;
                }
            }
        }
    }
    return NO;
}

- (BOOL)hasAnyClassNamed:(NSArray<NSString *> *)names maxAsm:(int)maxAsm maxClass:(int)maxClass {
    if (names.count == 0) return NO;

    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (!r) return NO;
    [r attachCurrentThread];
    if (![r resolve]) return NO;

    Il2CppDomain *domain = [r domain_get];
    if (!domain || (uintptr_t)domain < 0x1000) return NO;
    if (!domain->assemblies) return NO;

    int asmLimit = MIN((int)domain->assembly_count, maxAsm);
    for (int a = 0; a < asmLimit; a++) {
        Il2CppAssembly *asm_ = domain->assemblies[a];
        if (!asm_ || (uintptr_t)asm_ < 0x1000) continue;
        Il2CppImage *image = [r assembly_get_image:asm_];
        if (!image || (uintptr_t)image < 0x1000) continue;
        size_t count = [r image_get_class_count:image];
        if (count == 0 || count > 100000) continue;
        size_t limit = MIN(count, (size_t)maxClass);
        for (size_t i = 0; i < limit; i++) {
            Il2CppClass *k = [r image_get_class:image index:i];
            if (!k || (uintptr_t)k < 0x1000) continue;
            const char *cn = [r class_get_name:k];
            if (!cn) continue;
            NSString *n = [NSString stringWithUTF8String:cn];
            if (!n) continue;
            for (NSString *want in names) {
                if ([n isEqualToString:want]) return YES;
            }
        }
    }
    return NO;
}

#pragma mark - Concept → Methods

- (NSArray<NSDictionary *> *)findMethodsForConcept:(NSString *)concept
                                         maxResults:(NSInteger)max {
    if (concept.length == 0) return @[];
    if (max <= 0) max = 10;

    NSArray<NSString *> *synonyms = gSynonyms[concept.lowercaseString];
    if (!synonyms || synonyms.count == 0) return @[];

    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (!r) return @[];
    [r attachCurrentThread];
    if (![r resolve]) return @[];

    Il2CppDomain *domain = [r domain_get];
    if (!domain || (uintptr_t)domain < 0x1000) return @[];
    if (!domain->assemblies) return @[];

    NSMutableArray *found = [NSMutableArray array];

    @try {
        int maxAsm = MIN((int)domain->assembly_count, 3);
        for (int a = 0; a < maxAsm; a++) {
            Il2CppAssembly *asm_ = domain->assemblies[a];
            if (!asm_ || (uintptr_t)asm_ < 0x1000) continue;
            Il2CppImage *image = [r assembly_get_image:asm_];
            if (!image || (uintptr_t)image < 0x1000) continue;

            size_t count = [r image_get_class_count:image];
            if (count == 0 || count > 100000) continue;
            size_t classLimit = MIN(count, (size_t)500);

            for (size_t i = 0; i < classLimit && found.count < (NSUInteger)max * 3; i++) {
                @autoreleasepool {
                    Il2CppClass *klass = [r image_get_class:image index:i];
                    if (!klass || (uintptr_t)klass < 0x1000) continue;
                    const char *cname = [r class_get_name:klass];
                    if (!cname) continue;
                    NSString *className = [NSString stringWithUTF8String:cname];
                    if (!className) continue;

                    NSString *cl = className.lowercaseString;
                    if ([cl containsString:@"util"] ||
                        [cl containsString:@"helper"] ||
                        [cl containsString:@"config"] ||
                        [cl containsString:@"editor"] ||
                        [cl containsString:@"debug"]) continue;

                    uint16_t mCount = 0;
                    NSArray<NSValue *> *mList = [r class_get_methods:klass count:&mCount];
                    for (uint16_t j = 0; j < mCount; j++) {
                        MethodInfo *m = (MethodInfo *)mList[j].pointerValue;
                        if (!m || (uintptr_t)m < 0x1000) continue;
                        const char *mn = [r method_get_name:m];
                        if (!mn) continue;
                        NSString *mName = [NSString stringWithUTF8String:mn];
                        if (!mName) continue;

                        NSInteger synonymIdx = -1;
                        for (NSUInteger k = 0; k < synonyms.count; k++) {
                            if ([mName isEqualToString:synonyms[k]]) {
                                synonymIdx = (NSInteger)k;
                                break;
                            }
                        }
                        if (synonymIdx < 0) continue;

                        NSUInteger score = 100 - (NSUInteger)synonymIdx;
                        if ([cl containsString:@"showentity"])         score += 100;
                        else if ([cl containsString:@"logicfighter"])  score += 90;
                        else if ([cl containsString:@"entity"])        score += 60;
                        else if ([cl containsString:@"fighter"])       score += 60;
                        else if ([cl containsString:@"hero"])          score += 50;
                        else if ([cl containsString:@"player"])        score += 50;

                        void *ptr = [r method_get_pointer:m];
                        uint64_t rva = ptr ? (uint64_t)((uintptr_t)ptr) : 0;

                        [found addObject:@{
                            @"class": className,
                            @"method": mName,
                            @"rva": [NSString stringWithFormat:@"0x%llX", rva],
                            @"score": @(score),
                        }];
                    }
                }
            }
        }
    } @catch (NSException *e) {
        return @[];
    }

    [found sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [b[@"score"] compare:a[@"score"]];
    }];

    if (found.count > (NSUInteger)max) {
        [found removeObjectsInRange:NSMakeRange(max, found.count - max)];
    }

    return found;
}

@end
