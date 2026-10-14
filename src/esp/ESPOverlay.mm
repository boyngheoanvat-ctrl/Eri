#import "ESPOverlay.h"
#import "IL2CPPResolver.h"
#import "IL2CPPHeapWalker.h"
#import "ESPStructs.h"
#import "ToolTheme.h"
#import <QuartzCore/QuartzCore.h>

@interface ESPOverlay ()
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, strong) NSMutableArray *entities;
@property (nonatomic, assign) NSInteger frameCount;
@property (nonatomic, assign) BOOL busyCollecting;
@end

@implementation ESPOverlay

+ (instancetype)shared {
    static ESPOverlay *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGRect screen = [UIScreen mainScreen].bounds;
        instance = [[ESPOverlay alloc] initWithFrame:screen];
        instance.backgroundColor = [UIColor clearColor];
        instance.userInteractionEnabled = NO;
        instance.hidden = YES;
        instance.enabled = NO;
        instance.showHP = YES;
        instance.showName = YES;
        instance.showDistance = YES;
        instance.showBox = YES;
        instance.showLine = NO;
        instance.entities = [NSMutableArray array];
        instance.frameCount = 0;
        instance.busyCollecting = NO;
    });
    return instance;
}

- (void)attachToWindow:(UIWindow *)window {
    if (!window) return;
    [window addSubview:self];
    [window bringSubviewToFront:self];
    self.hidden = !self.enabled;
}

- (void)show {
    self.enabled = YES;
    self.hidden = NO;
    [self startDrawing];
}

- (void)hide {
    self.enabled = NO;
    self.hidden = YES;
    [self stopDrawing];
}

- (void)toggle { if (self.enabled) [self hide]; else [self show]; }
- (void)reload { [self setNeedsDisplay]; }

#pragma mark - Display Link

- (void)startDrawing {
    if (self.displayLink) return;
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
    self.displayLink.preferredFramesPerSecond = 10;
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stopDrawing {
    [self.displayLink invalidate];
    self.displayLink = nil;
}

- (void)tick:(CADisplayLink *)link {
    if (!self.enabled) return;
    if (self.busyCollecting) return;

    self.frameCount++;
    if (self.frameCount % 3 != 0) return;

    self.busyCollecting = YES;
    __weak typeof(self) ws = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray *collected = [ws collectEntitiesSafe];
        dispatch_async(dispatch_get_main_queue(), ^{
            ws.entities = [collected mutableCopy] ?: [NSMutableArray array];
            ws.busyCollecting = NO;
            [ws setNeedsDisplay];
        });
    });
}

#pragma mark - Collect

- (NSArray *)collectEntitiesSafe {
    NSMutableArray *entities = [NSMutableArray array];

    @try {
        IL2CPPResolver *r = [IL2CPPResolver shared];
        if (![r resolve]) return entities;

        IL2CPPHeapWalker *walker = [IL2CPPHeapWalker shared];
        NSArray<NSValue *> *instances = [walker autoCollectInstancesWithLimit:50];

        for (NSValue *v in instances) {
            @autoreleasepool {
                void *objPtr = v.pointerValue;
                if (!objPtr) continue;
                NSDictionary *ent = [self buildEntityDict:objPtr resolver:r];
                if (ent) [entities addObject:ent];
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[ESP] exception: %@", e.reason);
    }

    return entities;
}

- (NSDictionary *)buildEntityDict:(void *)entityPtr resolver:(IL2CPPResolver *)r {
    if (!entityPtr) return nil;

    Il2CppClass *entityClass = [self classOfObject:entityPtr];
    if (!entityClass) return nil;

    // Dò method trên class và parent
    MethodInfo *mGetPos   = [self findMethodInHierarchy:entityClass names:@[@"get_Position", @"get_position"] resolver:r];
    MethodInfo *mGetHp    = [self findMethodInHierarchy:entityClass names:@[@"get_Hp", @"get_HP", @"get_m_Hp", @"get_hp"] resolver:r];
    MethodInfo *mGetHpMax = [self findMethodInHierarchy:entityClass names:@[@"get_HpMax", @"get_MaxHp", @"get_m_HpMax", @"get_MaxHP"] resolver:r];
    MethodInfo *mGetName  = [self findMethodInHierarchy:entityClass names:@[@"get_Name", @"get_m_Name", @"get_RoleName", @"get_m_RoleName", @"get_PlayerName"] resolver:r];
    MethodInfo *mGetDead  = [self findMethodInHierarchy:entityClass names:@[@"get_IsDead", @"get_m_bDeath", @"get_Dead", @"get_isDead"] resolver:r];
    MethodInfo *mGetSelf  = [self findMethodInHierarchy:entityClass names:@[@"get_IsSelf", @"get_m_bSelf", @"get_IsLocalPlayer", @"get_isSelf"] resolver:r];

    if (!mGetPos) return nil;

    // Dead check
    if (mGetDead) {
        BOOL dead = [self invokeBoolMethod:mGetDead onObject:entityPtr resolver:r];
        if (dead) return nil;
    }

    BOOL isSelf = NO;
    if (mGetSelf) isSelf = [self invokeBoolMethod:mGetSelf onObject:entityPtr resolver:r];

    Vector3 worldPos = [self invokeVector3Method:mGetPos onObject:entityPtr resolver:r];
    if (worldPos.x == 0 && worldPos.y == 0 && worldPos.z == 0) return nil;

    float hp = 0, hpMax = 0;
    if (mGetHp) hp = [self invokeFloatMethod:mGetHp onObject:entityPtr resolver:r];
    if (mGetHpMax) hpMax = [self invokeFloatMethod:mGetHpMax onObject:entityPtr resolver:r];
    float hpPercent = (hpMax > 0) ? (hp / hpMax) : 1.0;

    NSString *name = @"?";
    if (mGetName) {
        void *namePtr = [self invokeObjMethod:mGetName onObject:entityPtr resolver:r];
        NSString *n = [self il2cppStringToNSString:namePtr];
        if (n.length > 0) name = n;
    }

    // World → screen
    CGPoint screenPos;
    BOOL screenOK = [self worldToScreenPoint:worldPos out:&screenPos resolver:r];
    if (!screenOK) {
        // Fallback: ước lượng
        CGSize screen = self.bounds.size;
        screenPos = CGPointMake(screen.width / 2 + worldPos.x * 3,
                                 screen.height / 2 - worldPos.z * 3);
    }

    CGSize screen = self.bounds.size;
    if (screenPos.x < -100 || screenPos.x > screen.width + 100) return nil;
    if (screenPos.y < -100 || screenPos.y > screen.height + 100) return nil;

    CGFloat dx = worldPos.x - [self localPlayerX:r];
    CGFloat dz = worldPos.z - [self localPlayerZ:r];
    CGFloat distance = sqrtf(dx*dx + dz*dz);
    CGFloat scale = MAX(0.3, MIN(2.0, 800.0 / MAX(distance, 100)));

    CGFloat boxW = 40 * scale;
    CGFloat boxH = 60 * scale;
    CGRect box = CGRectMake(screenPos.x - boxW/2, screenPos.y - boxH, boxW, boxH);

    UIColor *color = isSelf ? [UIColor greenColor] : [UIColor redColor];

    return @{
        @"box": [NSValue valueWithCGRect:box],
        @"hp_percent": @(hpPercent),
        @"name": name,
        @"color": color,
        @"distance": @(distance),
        @"is_self": @(isSelf),
    };
}

// Cache vị trí local player
- (CGFloat)localPlayerX:(IL2CPPResolver *)r { return 0; }
- (CGFloat)localPlayerZ:(IL2CPPResolver *)r { return 0; }

#pragma mark - Method lookup

- (Il2CppClass *)classOfObject:(void *)objPtr {
    if (!objPtr) return NULL;
    if ((uintptr_t)objPtr < 0x1000) return NULL;
    void *klassPtr = *(void **)objPtr;
    if (!klassPtr) return NULL;
    if ((uintptr_t)klassPtr < 0x1000) return NULL;
    return (Il2CppClass *)klassPtr;
}

- (MethodInfo *)findMethodInHierarchy:(Il2CppClass *)klass
                                 names:(NSArray<NSString *> *)names
                              resolver:(IL2CPPResolver *)r {
    Il2CppClass *current = klass;
    int depth = 0;
    while (current && depth < 10) {
        uint16_t mCount = 0;
        NSArray<NSValue *> *mList = [r class_get_methods:current count:&mCount];
        for (uint16_t j = 0; j < mCount; j++) {
            MethodInfo *m = (MethodInfo *)mList[j].pointerValue;
            if (!m) continue;
            const char *mn = [r method_get_name:m];
            if (!mn) continue;
            NSString *n = [NSString stringWithUTF8String:mn];
            if (!n) continue;
            for (NSString *want in names) {
                if ([n isEqualToString:want]) return m;
            }
        }
        current = [r class_get_parent:current];
        depth++;
    }
    return NULL;
}

#pragma mark - Invoke

- (void *)invokeObjMethod:(MethodInfo *)method onObject:(void *)obj resolver:(IL2CPPResolver *)r {
    if (!method || !obj) return NULL;
    void *ptr = [r method_get_pointer:method];
    if (!ptr) return NULL;
    typedef void *(*fn_t)(void *, void *);
    fn_t fn = (fn_t)ptr;
    return fn(obj, method);
}

- (float)invokeFloatMethod:(MethodInfo *)method onObject:(void *)obj resolver:(IL2CPPResolver *)r {
    if (!method || !obj) return 0;
    void *ptr = [r method_get_pointer:method];
    if (!ptr) return 0;
    typedef float (*fn_t)(void *, void *);
    fn_t fn = (fn_t)ptr;
    return fn(obj, method);
}

- (BOOL)invokeBoolMethod:(MethodInfo *)method onObject:(void *)obj resolver:(IL2CPPResolver *)r {
    if (!method || !obj) return NO;
    void *ptr = [r method_get_pointer:method];
    if (!ptr) return NO;
    typedef BOOL (*fn_t)(void *, void *);
    fn_t fn = (fn_t)ptr;
    return fn(obj, method);
}

- (Vector3)invokeVector3Method:(MethodInfo *)method onObject:(void *)obj resolver:(IL2CPPResolver *)r {
    Vector3 result = {0, 0, 0};
    if (!method || !obj) return result;
    void *ptr = [r method_get_pointer:method];
    if (!ptr) return result;
    // Vector3 (12 bytes) return trong S0/S1/S2 (ARM64), không qua pointer
    typedef Vector3 (*fn_t)(void *, void *);
    fn_t fn = (fn_t)ptr;
    return fn(obj, method);
}

- (NSString *)il2cppStringToNSString:(void *)strPtr {
    if (!strPtr) return @"";
    if ((uintptr_t)strPtr < 0x1000) return @"";
    int32_t len = *(int32_t *)((char *)strPtr + 0x10);
    if (len <= 0 || len > 256) return @"";
    const UniChar *chars = (const UniChar *)((char *)strPtr + 0x18);
    @try {
        return [NSString stringWithCharacters:chars length:len];
    } @catch (NSException *e) {
        return @"";
    }
}

#pragma mark - World to Screen (Unity Camera)

- (BOOL)worldToScreenPoint:(Vector3)world out:(CGPoint *)outPoint resolver:(IL2CPPResolver *)r {
    static Il2CppClass *cameraClass = NULL;
    static MethodInfo *mGetMain = NULL;
    static MethodInfo *mW2S = NULL;
    static BOOL triedInit = NO;

    if (!triedInit) {
        triedInit = YES;
        // Tìm UnityEngine.Camera
        Il2CppDomain *domain = [r domain_get];
        if (domain && domain->assemblies) {
            for (int a = 0; a < MIN((int)domain->assembly_count, 8) && !cameraClass; a++) {
                Il2CppAssembly *asm_ = domain->assemblies[a];
                if (!asm_) continue;
                Il2CppImage *image = [r assembly_get_image:asm_];
                if (!image) continue;
                const char *imgName = [r image_get_name:image];
                if (!imgName) continue;
                NSString *imgStr = [NSString stringWithUTF8String:imgName];
                if (!imgStr) continue;
                // Chỉ scan assembly UnityEngine
                if (![imgStr containsString:@"UnityEngine"]) continue;

                size_t count = [r image_get_class_count:image];
                for (size_t i = 0; i < count; i++) {
                    Il2CppClass *k = [r image_get_class:image index:i];
                    if (!k) continue;
                    const char *cn = [r class_get_name:k];
                    if (!cn) continue;
                    NSString *n = [NSString stringWithUTF8String:cn];
                    if ([n isEqualToString:@"Camera"]) {
                        cameraClass = k;
                        break;
                    }
                }
            }
        }
        if (cameraClass) {
            mGetMain = [self findMethodInHierarchy:cameraClass names:@[@"get_main"] resolver:r];
            mW2S = [self findMethodInHierarchy:cameraClass names:@[@"WorldToScreenPoint"] resolver:r];
        }
    }

    if (!cameraClass || !mGetMain || !mW2S) return NO;

    void *getMainPtr = [r method_get_pointer:mGetMain];
    void *w2sPtr = [r method_get_pointer:mW2S];
    if (!getMainPtr || !w2sPtr) return NO;

    // get_main là static: fn(MethodInfo*)
    typedef void *(*fn_static)(void *);
    void *camera = ((fn_static)getMainPtr)(mGetMain);
    if (!camera) return NO;

    // WorldToScreenPoint: Vector3 fn(Camera*, MethodInfo*, Vector3)
    typedef Vector3 (*fn_w2s)(void *, void *, Vector3);
    Vector3 sp = ((fn_w2s)w2sPtr)(camera, mW2S, world);

    if (outPoint) {
        // Unity: gốc dưới trái → iOS: gốc trên trái
        *outPoint = CGPointMake(sp.x, self.bounds.size.height - sp.y);
    }
    return YES;
}

#pragma mark - Draw

- (void)drawRect:(CGRect)rect {
    if (!self.enabled) return;
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return;

    NSDictionary *attr = @{
        NSForegroundColorAttributeName: [UIColor colorWithRed:0.30 green:0.90 blue:0.50 alpha:1.0],
        NSFontAttributeName: [UIFont fontWithName:@"Menlo-Bold" size:11] ?: [UIFont boldSystemFontOfSize:11]
    };
    NSString *statusStr = [NSString stringWithFormat:@"[ESP] %lu entities (strategy=%ld)",
                            (unsigned long)self.entities.count,
                            (long)[[IL2CPPHeapWalker shared] lastStrategy]];
    [statusStr drawAtPoint:CGPointMake(20, 60) withAttributes:attr];

    for (NSDictionary *e in self.entities) {
        @autoreleasepool {
            CGRect box = [e[@"box"] CGRectValue];
            UIColor *color = e[@"color"] ?: [UIColor redColor];

            if (self.showBox) {
                CGContextSetStrokeColorWithColor(ctx, color.CGColor);
                CGContextSetLineWidth(ctx, 1.5);
                CGContextStrokeRect(ctx, box);
            }

            if (self.showHP) {
                CGFloat hpPercent = [e[@"hp_percent"] floatValue];
                if (hpPercent < 0) hpPercent = 0;
                if (hpPercent > 1) hpPercent = 1;
                CGRect hpBg = CGRectMake(box.origin.x, box.origin.y - 8, box.size.width, 4);
                CGRect hpFill = CGRectMake(hpBg.origin.x, hpBg.origin.y,
                                            hpBg.size.width * hpPercent, hpBg.size.height);
                CGContextSetFillColorWithColor(ctx, [UIColor blackColor].CGColor);
                CGContextFillRect(ctx, hpBg);
                CGContextSetFillColorWithColor(ctx,
                    [UIColor colorWithRed:0.30 green:0.90 blue:0.30 alpha:1.0].CGColor);
                CGContextFillRect(ctx, hpFill);
            }

            if (self.showName) {
                NSString *name = e[@"name"] ?: @"";
                NSDictionary *nameAttr = @{
                    NSForegroundColorAttributeName: [UIColor whiteColor],
                    NSFontAttributeName: [UIFont systemFontOfSize:10]
                };
                [name drawAtPoint:CGPointMake(box.origin.x, box.origin.y - 24)
                   withAttributes:nameAttr];
            }

            if (self.showDistance) {
                NSNumber *dist = e[@"distance"];
                if (dist) {
                    NSString *distStr = [NSString stringWithFormat:@"%.0fm", dist.floatValue];
                    NSDictionary *distAttr = @{
                        NSForegroundColorAttributeName: [UIColor yellowColor],
                        NSFontAttributeName: [UIFont systemFontOfSize:9]
                    };
                    [distStr drawAtPoint:CGPointMake(box.origin.x, box.origin.y + box.size.height + 2)
                          withAttributes:distAttr];
                }
            }

            if (self.showLine) {
                CGContextSetStrokeColorWithColor(ctx, color.CGColor);
                CGContextSetLineWidth(ctx, 1.0);
                CGContextMoveToPoint(ctx, self.bounds.size.width / 2, self.bounds.size.height);
                CGContextAddLineToPoint(ctx, box.origin.x + box.size.width / 2,
                                         box.origin.y + box.size.height);
                CGContextStrokePath(ctx);
            }
        }
    }
}

@end
