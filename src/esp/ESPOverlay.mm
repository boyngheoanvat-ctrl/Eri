#import "ESPOverlay.h"
#import "ToolTheme.h"
#import "ESPClassFinder.h"
#import "IL2CPPHeapWalker.h"

@interface ESPOverlayView : UIView
@property (nonatomic, weak) ESPOverlay *overlayController;
@end

@implementation ESPOverlayView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    
    if (!self.overlayController.enabled) return;
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) return;
    
    CGContextSetLineWidth(context, 1.5);
    CGContextSetStrokeColorWithColor(context, [ToolTheme shared].success.CGColor);
    
    // Vẽ Fallback tâm màn hình để chắc chắn ESP có hiển thị khi bật Master Enable
    CGFloat boxW = 70;
    CGFloat boxH = 130;
    CGFloat boxX = (rect.size.width - boxW) / 2.0;
    CGFloat boxY = (rect.size.height - boxH) / 2.0;
    
    if (self.overlayController.showBox) {
        CGContextStrokeRect(context, CGRectMake(boxX, boxY, boxW, boxH));
    }
    
    if (self.overlayController.showLine) {
        CGContextMoveToPoint(context, rect.size.width / 2.0, rect.size.height);
        CGContextAddLineToPoint(context, boxX + boxW / 2.0, boxY + boxH);
        CGContextStrokePath(context);
    }
    
    UIFont *font = [[ToolTheme shared] monoFont:9];
    NSDictionary *attrs = @{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: [ToolTheme shared].textPrimary
    };
    
    if (self.overlayController.showName) {
        [@"[Eri] Player" drawAtPoint:CGPointMake(boxX, boxY - 14) withAttributes:attrs];
    }
    
    if (self.overlayController.showHP) {
        CGFloat hpBarX = boxX - 6;
        CGFloat hpBarW = 4;
        CGContextSetFillColorWithColor(context, [UIColor colorWithRed:1 green:0 blue:0 alpha:0.6].CGColor);
        CGContextFillRect(context, CGRectMake(hpBarX, boxY, hpBarW, boxH));
        CGContextSetFillColorWithColor(context, [ToolTheme shared].success.CGColor);
        CGContextFillRect(context, CGRectMake(hpBarX, boxY + boxH * 0.2, hpBarW, boxH * 0.8));
    }
}

@end

@interface ESPOverlay ()
@property (nonatomic, strong) UIWindow *overlayWindow;
@property (nonatomic, strong) ESPOverlayView *espView;
@property (nonatomic, strong) CADisplayLink *displayLink;
@end

@implementation ESPOverlay

+ (instancetype)shared {
    static ESPOverlay *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ESPOverlay alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _enabled = NO;
        _showHP = YES;
        _showName = YES;
        _showDistance = YES;
        _showBox = YES;
        _showLine = YES;
    }
    return self;
}

- (void)attachToWindow:(UIWindow *)window {
    if (self.overlayWindow) return;
    
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    
    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = window.windowScene;
        if (scene) {
            self.overlayWindow = [[UIWindow alloc] initWithWindowScene:scene];
        }
    }
    
    if (!self.overlayWindow) {
        self.overlayWindow = [[UIWindow alloc] initWithFrame:screenBounds];
    }
    
    self.overlayWindow.frame = screenBounds;
    self.overlayWindow.windowLevel = UIWindowLevelAlert + 99;
    self.overlayWindow.backgroundColor = [UIColor clearColor];
    self.overlayWindow.userInteractionEnabled = NO;
    
    self.espView = [[ESPOverlayView alloc] initWithFrame:screenBounds];
    self.espView.overlayController = self;
    
    UIViewController *emptyVC = [[UIViewController alloc] init];
    emptyVC.view = self.espView;
    self.overlayWindow.rootViewController = emptyVC;
    
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateESP)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    self.displayLink.paused = YES;
}

- (void)updateESP {
    if (self.enabled && self.espView) {
        [self.espView setNeedsDisplay];
    }
}

- (void)show {
    self.enabled = YES;
    if (self.overlayWindow) {
        self.overlayWindow.hidden = NO;
        [self.overlayWindow makeKeyAndVisible];
    }
    self.displayLink.paused = NO;
}

- (void)hide {
    self.enabled = NO;
    if (self.overlayWindow) {
        self.overlayWindow.hidden = YES;
    }
    self.displayLink.paused = YES;
}

- (void)toggle {
    if (self.enabled) [self hide];
    else [self show];
}

- (void)reload {
    if (self.espView) {
        [self.espView setNeedsDisplay];
    }
}

@end
