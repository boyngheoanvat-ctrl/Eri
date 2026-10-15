#import "GameFingerprint.h"
#import "IL2CPPResolver.h"

static NSDictionary<NSString *, NSArray<NSString *> *> *gSynonyms = nil;
static NSString *gDetectedGame = nil;
static BOOL gScanned = NO;

@implementation GameFingerprint

+ (instancetype)shared {
    static GameFingerprint *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[GameFingerprint alloc] init];
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
    if (gScanned) return;
    gScanned = YES;

    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (!r) {
        gDetectedGame = @"Unknown";
        gScanned = NO;
        return;
    }
    if (![r resolve]) {
        gDetectedGame = @"Unknown";
        gScanned = NO;
        return;
    }

    Il2CppDomain *domain = [r domain_get];
    if (!domain || !domain->assemblies || domain->assembly_count == 0) {
        NSLog(@"[GameFingerprint] IL2CPP not ready yet");
        gDetectedGame = @"Unknown";
        gScanned = NO;
        return;
    }

    @try {
        BOOL hasCanSight    = [self hasAnyMethodNamed:@[@"CanSight"]];
        BOOL hasCalcVisible = [self hasAnyMethodNamed:@[@"CalcVisible", @"RefreshVisible"]];
        BOOL hasSetVisible  = [self hasAnyMethodNamed:@[@"SetVisible"]];
        BOOL hasShowEntity  = [self hasAnyClassNamed:@[@"ShowEntity", @"LogicFighter"]];

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
        NSLog(@"[GameFingerprint] scan crash: %@", e);
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
    return @{
        @"game": gDetectedGame ?: @"Unknown",
        @"has_CanSight":       @([self hasAnyMethodNamed:@[@"CanSight"]]),
        @"has_CalcVisible":    @([self hasAnyMethodNamed:@[@"CalcVisible"]]),
        @"has_RefreshVisible": @([self hasAnyMethodNamed:@[@"RefreshVisible"]]),
        @"has_SetVisible":     @([self hasAnyMethodNamed:@[@"SetVisible"]]),
        @"has_ShowEntity":     @([self hasAnyClassNamed:@[@"ShowEntity"]]),
        @"has_LogicFighter":   @([self hasAnyClassNamed:@[@"LogicFighter"]]),
    };
}

- (BOOL)hasAnyMethodNamed:(NSArray<NSString *> *)names {
    if (names.count == 0) return NO;

    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (!r) return NO;
    if (![r resolve]) return NO;

    Il2CppDomain *domain = [r domain_get];
    if (!domain) return NO;
    if (!domain->assemblies) return NO;

    int maxAsm = MIN((int)domain->assembly_count, 5);
    if (maxAsm <= 0) return NO;

    for (int a = 0; a < maxAsm; a++) {
        Il2CppAssembly *asm_ = domain->assemblies[a];
        if (!asm_) continue;
        Il2CppImage *image = [r assembly_get_image:asm_];
        if (!image) continue;
        size_t count = [r image_get_class_count:image];
        for (size_t i = 0; i < count; i++) {
            Il2CppClass *k = [r image_get_class:image index:i];
            if (!k) continue;
            uint16_t mCount = 0;
            NSArray<NSValue *> *mList = [r class_get_methods:k count:&mCount];
            for (uint16_t j = 0; j < mCount; j++) {
                MethodInfo *m = (MethodInfo *)mList[j].pointerValue;
                if (!m) continue;
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

- (BOOL)hasAnyClassNamed:(NSArray<NSString *> *)names {
    if (names.count == 0) return NO;

    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (!r) return NO;
    if (![r resolve]) return NO;

    Il2CppDomain *domain = [r domain_get];
    if (!domain) return NO;
    if (!domain->assemblies) return NO;

    int maxAsm = MIN((int)domain->assembly_count, 5);
    if (maxAsm <= 0) return NO;

    for (int a = 0; a < maxAsm; a++) {
        Il2CppAssembly *asm_ = domain->assemblies[a];
        if (!asm_) continue;
        Il2CppImage *image = [r assembly_get_image:asm_];
        if (!image) continue;
        size_t count = [r image_get_class_count:image];
        for (size_t i = 0; i < count; i++) {
            Il2CppClass *k = [r image_get_class:image index:i];
            if (!k) continue;
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
    if (![r resolve]) return @[];

    Il2CppDomain *domain = [r domain_get];
    if (!domain) return @[];
    if (!domain->assemblies) return @[];

    NSMutableArray *found = [NSMutableArray array];

    @try {
        int maxAsm = MIN((int)domain->assembly_count, 5);
        for (int a = 0; a < maxAsm; a++) {
            Il2CppAssembly *asm_ = domain->assemblies[a];
            if (!asm_) continue;
            Il2CppImage *image = [r assembly_get_image:asm_];
            if (!image) continue;

            size_t count = [r image_get_class_count:image];
            for (size_t i = 0; i < count && found.count < (NSUInteger)max * 3; i++) {
                @autoreleasepool {
                    Il2CppClass *klass = [r image_get_class:image index:i];
                    if (!klass) continue;
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
                        if (!m) continue;
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
