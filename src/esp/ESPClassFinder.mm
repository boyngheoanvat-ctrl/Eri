#import "ESPClassFinder.h"
#import "IL2CPPResolver.h"

@implementation ESPTargetClass
@end

@implementation ESPClassFinder

+ (instancetype)shared {
    static ESPClassFinder *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ESPClassFinder alloc] init];
    });
    return instance;
}

- (NSArray<ESPTargetClass *> *)scanForPotentialTargets {
    NSMutableArray<ESPTargetClass *> *results = [NSMutableArray array];
    @try {
        IL2CPPResolver *r = [IL2CPPResolver shared];
        if (!r || ![r resolve]) return results;

        Il2CppDomain *domain = [r domain_get];
        if (!domain) return results;

        size_t asmCount = 0;
        const Il2CppAssembly **assemblies = [r domain_get_assemblies:domain count:&asmCount];
        if (!assemblies || asmCount == 0) return results;

        NSArray *targetKeywords = @[@"player", @"enemy", @"actor", @"unit", @"hero", @"monster", @"character", @"pawn"];

        for (size_t a = 0; a < asmCount; a++) {
            Il2CppAssembly *asm_ = (Il2CppAssembly *)assemblies[a];
            if (!asm_) continue;

            Il2CppImage *image = [r assembly_get_image:asm_];
            if (!image) continue;

            size_t classCount = [r image_get_class_count:image];
            for (size_t i = 0; i < classCount; i++) {
                Il2CppClass *klass = [r image_get_class:image index:i];
                if (!klass) continue;

                const char *cname = [r class_get_name:klass];
                if (!cname) continue;

                NSString *className = [NSString stringWithUTF8String:cname];
                NSString *lowerName = [className lowercaseString];

                BOOL matched = NO;
                for (NSString *kw in targetKeywords) {
                    if ([lowerName containsString:kw]) {
                        matched = YES;
                        break;
                    }
                }

                if (!matched) continue;

                uint16_t fCount = 0;
                NSArray<NSValue *> *fList = [r class_get_fields:klass count:&fCount];
                if (!fList || fList.count == 0) continue;

                int32_t posOff = -1;
                int32_t hpOff = -1;
                int32_t maxHpOff = -1;

                for (uint16_t j = 0; j < fCount && j < fList.count; j++) {
                    NSValue *val = fList[j];
                    if (!val) continue;
                    
                    FieldInfo *fi = (FieldInfo *)val.pointerValue;
                    if (!fi) continue;

                    const char *fn = [r field_get_name:fi];
                    if (!fn) continue;

                    NSString *fName = [[NSString stringWithUTF8String:fn] lowercaseString];
                    int32_t off = [r field_get_offset:fi];

                    if (posOff == -1 && ([fName containsString:@"pos"] || [fName containsString:@"transform"] || [fName containsString:@"location"])) {
                        posOff = off;
                    }
                    if (hpOff == -1 && ([fName containsString:@"hp"] || [fName containsString:@"health"] || [fName containsString:@"curhp"])) {
                        hpOff = off;
                    }
                    if (maxHpOff == -1 && ([fName containsString:@"maxhp"] || [fName containsString:@"maxhealth"])) {
                        maxHpOff = off;
                    }
                }

                if (posOff != -1 || hpOff != -1) {
                    ESPTargetClass *tc = [[ESPTargetClass alloc] init];
                    tc.klass = klass;
                    tc.className = className;
                    tc.positionOffset = posOff;
                    tc.hpOffset = hpOff;
                    tc.maxHpOffset = maxHpOff;
                    [results addObject:tc];
                }
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[ESPClassFinder] Exception during scan: %@", e);
    }
    return results;
}

+ (NSArray<ESPTargetClass *> *)scanActiveTargets {
    return [[ESPClassFinder shared] scanForPotentialTargets];
}

- (NSArray *)findEntityManagerClasses {
    return [self scanForPotentialTargets];
}

- (NSArray *)findCameraClasses {
    return @[];
}

- (NSArray *)findClassesWithStaticEntityList {
    return @[];
}

- (NSArray *)findMethodsReturningEntityList {
    return @[];
}

- (NSString *)fullScanReport {
    NSArray *targets = [self scanForPotentialTargets];
    return [NSString stringWithFormat:@"[ESPScan] Found %lu target classes.", (unsigned long)targets.count];
}

@end
