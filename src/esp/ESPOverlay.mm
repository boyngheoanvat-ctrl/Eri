#import "ESPOverlay.h"
#import "IL2CPPResolver.h"
#import "ToolTheme.h"
#import <QuartzCore/QuartzCore.h>

@interface ESPOverlay ()
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, strong) NSMutableArray *entities;
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

- (void)toggle {
    if (self.enabled) [self hide];
    else [self show];
}

- (void)reload {
    [self setNeedsDisplay];
}

#pragma mark - Display Link

- (void)startDrawing {
    if (self.displayLink) return;

    self.displayLink = [CADisplayLink displayLinkWithTarget:self
                                                    selector:@selector(tick:)];

    // Dùng respondsToSelector thay @available → tránh lỗi __isPlatformVersionAtLeast
    if ([self.displayLink respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
        self.displayLink.preferredFrameRateRange = CAFrameRateRangeMake(15, 30, 30);
    } else {
        self.displayLink.preferredFramesPerSecond = 30;
    }

    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stopDrawing {
    [self.displayLink invalidate];
    self.displayLink = nil;
}

- (void)tick:(CADisplayLink *)link {
    if (!self.enabled) return;
    [self collectEntities];
    [self setNeedsDisplay];
}

#pragma mark - Collect Entities

- (void)collectEntities {
    [self.entities removeAllObjects];

    IL2CPPResolver *r = [IL2CPPResolver shared];
    if (![r resolve]) return;

    Il2CppDomain *domain = [r domain_get];
    if (!domain) return;

    Il2CppClass *entityClass = [self findClass:@"ShowEntity" resolver:r domain:domain];
    if (!entityClass) return;

    MethodInfo *getPosition = [self findMethod:entityClass name:@"get_Position"];
    if (!getPosition) return;

    // TODO: Enumerate ShowEntity objects từ GC heap
    // Cần il2cpp_gc_heap_foreach hoặc list entity trong game
}

- (Il2CppClass *)findClass:(NSString *)name resolver:(IL2CPPResolver *)r domain:(Il2CppDomain *)domain {
    NSString *lower = name.lowercaseString;
    for (int a = 0; a < domain->assembly_count; a++) {
        Il2CppAssembly *asm_ = domain->assemblies[a];
        if (!asm_) continue;
        void *imgPtr = *(void **)asm_;
        if (!imgPtr) continue;
        Il2CppImage *image = (Il2CppImage *)imgPtr;
        if (!image || !image->name) continue;

        size_t count = [r image_get_class_count:image];
        for (size_t i = 0; i < count; i++) {
            Il2CppClass *klass = [r image_get_class:image index:i];
            if (!klass) continue;
            const char *cname = [r class_get_name:klass];
            if (!cname) continue;
            NSString *n = [NSString stringWithUTF8String:cname];
            if ([n.lowercaseString isEqualToString:lower]) return klass;
        }
    }
    return NULL;
}

- (MethodInfo *)findMethod:(Il2CppClass *)klass name:(NSString *)name {
    IL2CPPResolver *r = [IL2CPPResolver shared];
    uint16_t mCount = 0;
    const MethodInfo **mList = [r class_get_methods:klass count:&mCount];
    MethodInfo *found = NULL;
    for (uint16_t j = 0; j < mCount; j++) {
        const char *mn = [r method_get_name:(MethodInfo *)mList[j]];
        if (!mn) continue;
        NSString *n = [NSString stringWithUTF8String:mn];
        if ([n isEqualToString:name]) {
            found = (MethodInfo *)mList[j];
            break;
        }
    }
    if (mList) free(mList);
    return found;
}

#pragma mark - Draw

- (void)drawRect:(CGRect)rect {
    if (!self.enabled) return;

    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return;

    CGContextSetStrokeColorWithColor(ctx,
        [UIColor colorWithRed:0.30 green:0.70 blue:1.0 alpha:0.8].CGColor);
    CGContextSetLineWidth(ctx, 2);

    NSDictionary *attr = @{
        NSForegroundColorAttributeName: [UIColor colorWithRed:0.30 green:0.90 blue:0.50 alpha:1.0],
        NSFontAttributeName: [UIFont fontWithName:@"Menlo-Bold" size:12] ?: [UIFont boldSystemFontOfSize:12]
    };
    [@"[ESP] Active" drawAtPoint:CGPointMake(20, 60) withAttributes:attr];

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
            CGContextMoveToPoint(ctx, self.bounds.size.width / 2, self.bounds.size.height);
            CGContextAddLineToPoint(ctx, box.origin.x + box.size.width / 2,
                                     box.origin.y + box.size.height);
            CGContextStrokePath(ctx);
        }
    }
}

@end
