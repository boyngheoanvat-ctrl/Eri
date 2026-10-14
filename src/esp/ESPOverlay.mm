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
    });
    return instance;
}

- (void)attachToWindow:(UIWindow *)window {
    if (!window) return;
    [window addSubview:self];
    [window bringSubviewToFront:self];
    self.hidden = !self.enabled;
}

- (void)show { self.enabled = YES; self.hidden = NO; [self startDrawing]; }
- (void)hide { self.enabled = NO; self.hidden = YES; [self stopDrawing]; }
- (void)toggle { if (self.enabled) [self hide]; else [self show]; }
- (void)reload { [self setNeedsDisplay]; }

#pragma mark - Display Link

- (void)startDrawing {
    if (self.displayLink) return;

    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];

    // KHÔNG dùng preferredFrameRateRange (iOS 15) → tránh warning
    self.displayLink.preferredFramesPerSecond = 15;

    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stopDrawing {
    [self.displayLink invalidate];
    self.displayLink = nil;
}

- (void)tick:(CADisplayLink *)link {
    if (!self.enabled) return;

    self.frameCount++;
    if (self.frameCount % 5 != 0) return;

    [self collectEntities];
    [self setNeedsDisplay];
}

#pragma mark - Collect Entities

- (void)collectEntities {
    [self.entities removeAllObjects];

    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (![r resolve]) return;

    __weak typeof(self) ws = self;
    [[IL2CPPHeapWalker shared] enumerateObjectsOfClass:@"ShowEntity"
                                                 block:^(void *objPtr, Il2CppClass *klass) {
        [ws addEntity:objPtr resolver:r];
    } limit:50];
}

- (void)addEntity:(void *)entityPtr resolver:(IL2CPPResolver *)r {
    if (!entityPtr) return;

    Il2CppClass *entityClass = [self classOfObject:entityPtr];
    if (!entityClass) return;

    MethodInfo *mGetPos = [self findMethod:entityClass name:@"get_Position" resolver:r];
    MethodInfo *mGetHp = [self findMethod:entityClass name:@"get_m_Hp" resolver:r];
    MethodInfo *mGetHpMax = [self findMethod:entityClass name:@"get_m_HpMax" resolver:r];
    MethodInfo *mGetName = [self findMethod:entityClass name:@"get_m_RoleName" resolver:r];
    MethodInfo *mGetDead = [self findMethod:entityClass name:@"get_m_bDeath" resolver:r];
    MethodInfo *mGetSelf = [self findMethod:entityClass name:@"get_m_bSelf" resolver:r];

    if (!mGetPos) return;

    if (mGetDead && [self invokeBoolMethod:mGetDead onObject:entityPtr resolver:r]) return;

    BOOL isSelf = mGetSelf ? [self invokeBoolMethod:mGetSelf onObject:entityPtr resolver:r] : NO;

    Vector3 worldPos = [self invokeVector3Method:mGetPos onObject:entityPtr resolver:r];

    float hp = mGetHp ? [self invokeFloatMethod:mGetHp onObject:entityPtr resolver:r] : 0;
    float hpMax = mGetHpMax ? [self invokeFloatMethod:mGetHpMax onObject:entityPtr resolver:r] : 0;
    float hpPercent = hpMax > 0 ? hp / hpMax : 1.0;

    NSString *name = @"";
    if (mGetName) {
        void *namePtr = [self invokeObjMethod:mGetName onObject:entityPtr resolver:r];
        name = [self il2cppStringToNSString:namePtr];
    }

    CGPoint screenPos = [self worldToScreen:worldPos];
    CGSize screen = self.bounds.size;

    if (screenPos.x < 0 || screenPos.x > screen.width) return;
    if (screenPos.y < 0 || screenPos.y > screen.height) return;

    CGFloat distance = sqrtf(worldPos.x*worldPos.x + worldPos.y*worldPos.y + worldPos.z*worldPos.z);
    CGFloat scale = 800.0 / MAX(distance, 100);
    scale = MAX(0.3, MIN(2.0, scale));

    CGFloat boxW = 50 * scale;
    CGFloat boxH = 70 * scale;
    CGRect box = CGRectMake(screenPos.x - boxW/2, screenPos.y - boxH, boxW, boxH);

    UIColor *color = isSelf ? [UIColor greenColor] : [UIColor redColor];

    [self.entities addObject:@{
        @"box": [NSValue valueWithCGRect:box],
        @"hp_percent": @(hpPercent),
        @"name": name.length > 0 ? name : @"?",
        @"color": color,
        @"distance": @(distance)
    }];
}

#pragma mark - Method Invocation

- (Il2CppClass *)classOfObject:(void *)objPtr {
    if (!objPtr) return NULL;
    void *klassPtr = *(void **)objPtr;
    return (Il2CppClass *)klassPtr;
}

- (MethodInfo *)findMethod:(Il2CppClass *)klass name:(NSString *)name resolver:(IL2CPPResolver *)r {
    uint16_t mCount = 0;
    const MethodInfo **mList = [r class_get_methods:klass count:&mCount];
    MethodInfo *found = NULL;
    for (uint16_t j = 0; j < mCount; j++) {
        const char *mn = [r method_get_name:(MethodInfo *)mList[j]];
        if (!mn) continue;
        NSString *n = [NSString stringWithUTF8String:mn];
        if ([n isEqualToString:name]) { found = (MethodInfo *)mList[j]; break; }
    }
    if (mList) free(mList);
    return found;
}

- (void *)invokeObjMethod:(MethodInfo *)method onObject:(void *)obj resolver:(IL2CPPResolver *)r {
    if (!method || !obj) return NULL;
    typedef void *(*fn_t)(void *, void *);
    fn_t fn = (fn_t)[r method_get_pointer:method];
    if (!fn) return NULL;
    return fn(obj, NULL);
}

- (float)invokeFloatMethod:(MethodInfo *)method onObject:(void *)obj resolver:(IL2CPPResolver *)r {
    if (!method || !obj) return 0;
    typedef float (*fn_t)(void *, void *);
    fn_t fn = (fn_t)[r method_get_pointer:method];
    if (!fn) return 0;
    return fn(obj, NULL);
}

- (BOOL)invokeBoolMethod:(MethodInfo *)method onObject:(void *)obj resolver:(IL2CPPResolver *)r {
    if (!method || !obj) return NO;
    typedef BOOL (*fn_t)(void *, void *);
    fn_t fn = (fn_t)[r method_get_pointer:method];
    if (!fn) return NO;
    return fn(obj, NULL);
}

- (Vector3)invokeVector3Method:(MethodInfo *)method onObject:(void *)obj resolver:(IL2CPPResolver *)r {
    Vector3 result = {0, 0, 0};
    if (!method || !obj) return result;
    typedef void (*fn_t)(void *, void *, void *);
    fn_t fn = (fn_t)[r method_get_pointer:method];
    if (!fn) return result;
    fn(obj, NULL, &result);
    return result;
}

- (NSString *)il2cppStringToNSString:(void *)strPtr {
    if (!strPtr) return @"";
    uint32_t len = *(uint32_t *)strPtr;
    if (len > 256) len = 256;
    const UniChar *chars = (const UniChar *)((char *)strPtr + 0x10);
    return [NSString stringWithCharacters:chars length:len];
}

#pragma mark - World to Screen

- (CGPoint)worldToScreen:(Vector3)world {
    CGSize screen = self.bounds.size;
    return CGPointMake(screen.width / 2 + world.x * 5,
                        screen.height / 2 - world.z * 5);
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
    NSString *statusStr = [NSString stringWithFormat:@"[ESP] %lu entities",
                            (unsigned long)self.entities.count];
    [statusStr drawAtPoint:CGPointMake(20, 60) withAttributes:attr];

    for (NSDictionary *e in self.entities) {
        CGRect box = [e[@"box"] CGRectValue];
        UIColor *color = e[@"color"] ?: [UIColor redColor];

        if (self.showBox) {
            CGContextSetStrokeColorWithColor(ctx, color.CGColor);
            CGContextSetLineWidth(ctx, 1.5);
            CGContextStrokeRect(ctx, box);
        }

        if (self.showHP) {
            CGFloat hpPercent = [e[@"hp_percent"] floatValue];
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
                NSString *distStr = [NSString stringWithFormat:@"%.0fm", dist.floatValue / 100];
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

@end
