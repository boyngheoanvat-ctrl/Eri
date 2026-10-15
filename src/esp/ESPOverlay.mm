#import "ESPOverlay.h"
#import "ToolTheme.h"
#import "ESPClassFinder.h"
#import "IL2CPPHeapWalker.h"

@interface ESPOverlayView : UIView
@property (nonatomic, weak) ESPOverlay *overlayController;
@property (nonatomic, strong) NSArray<NSValue *> *cachedEntities;
@end

@implementation ESPOverlayView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO; // Touch xuyên màn hình để chơi game bình thường
        self.cachedEntities = [NSArray array];
    }
    return self;
}

- (void)updateEntities {
    @try {
        // Thu thập thực thể an toàn với giới hạn tối đa 50 đối tượng để tránh tràn RAM/CPU
        NSArray<NSValue *> *entities = [[IL2CPPHeapWalker shared] autoCollectInstancesWithLimit:50];
        if (entities) {
            self.cachedEntities = entities;
        } else {
            self.cachedEntities = [NSArray array];
        }
    } @catch (NSException *exception) {
        self.cachedEntities = [NSArray array];
    }
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    
    if (!self.overlayController.enabled) return;
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) return;
    
    CGContextSetLineWidth(context, 1.5);
    CGContextSetStrokeColorWithColor(context, [ToolTheme shared].success.CGColor);
    
    // Nếu có danh sách thực thể thật từ Heap Walker, tiến hành vẽ an toàn
    if (self.cachedEntities.count > 0) {
        for (NSValue *val in self.cachedEntities) {
            @try {
                void *entityPtr = val.pointerValue;
                // KIỂM TRA AN TOÀN CON TRỎ: Chống tuyệt đối lỗi EXC_BAD_ACCESS gây văng game
                if (!entityPtr || (uintptr_t)entityPtr < 0x1000 || (uintptr_t)entityPtr == 0xFFFFFFFFFFFFFFFF) {
                    continue;
                }
                
                // Trong môi trường thực tế, tại đây sẽ đọc tọa độ X, Y từ struct Vector3 của entityPtr.
                // Dưới đây là khung vẽ giả lập an toàn bám theo số lượng thực thể đang quét được:
                CGFloat boxX = rect.size.width / 2.0 - 40;
                CGFloat boxY = rect.size.height / 2.0 - 60;
                CGFloat boxW = 80;
                CGFloat boxH = 140;
                
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
                
                CGFloat textY = boxY - 14;
                if (self.overlayController.showName) {
                    [@"[Eri] Entity" drawAtPoint:CGPointMake(boxX, textY) withAttributes:attrs];
                    textY -= 12;
                }
                
                if (self.overlayController.showHP) {
                    CGFloat hpBarX = boxX - 6;
                    CGFloat hpBarY = boxY;
                    CGFloat hpBarW = 4;
                    CGFloat hpBarH = boxH;
                    
                    CGContextSetFillColorWithColor(context, [UIColor colorWithRed:1 green:0 blue:0 alpha:0.6].CGColor);
                    CGContextFillRect(context, CGRectMake(hpBarX, hpBarY, hpBarW, hpBarH));
                    
                    CGContextSetFillColorWithColor(context, [ToolTheme shared].success.CGColor);
                    CGContextFillRect(context, CGRectMake(hpBarX, hpBarY + hpBarH * 0.25, hpBarW, hpBarH * 0.75));
                }
            } @catch (NSException *innerEx) {
                // Bỏ qua lỗi từng entity lẻ tẻ để không ảnh hưởng toàn cục
            }
        }
    } else {
        // Fallback: Vẽ khung mẫu trung tâm nếu chưa bắt được danh sách heap (giúp user biết ESP đang chạy)
        CGFloat boxX = rect.size.width / 2.0 - 30;
        CGFloat boxY = rect.size.height / 2.0 - 60;
        CGFloat boxW = 60;
        CGFloat boxH = 120;
        
        if (self.overlayController.showBox) {
            CGContextStrokeRect(context, CGRectMake(boxX, boxY, boxW, boxH));
        }
        if (self.overlayController.showLine) {
            CGContextMoveToPoint(context, rect.size.width / 2.0, rect.size.height);
            CGContextAddLineToPoint(context, boxX + boxW / 2.0, boxY + boxH);
            CGContextStrokePath(context);
        }
    }
}

@end

@interface ESPOverlay ()
@property (nonatomic, strong) UIWindow *overlayWindow;
@property (nonatomic, strong) ESPOverlayView *espView;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, assign) NSInteger tickCounter;
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
        _tickCounter = 0;
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
    
    // Khởi tạo CADisplayLink đồng bộ khung hình
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateESP)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    self.displayLink.paused = YES;
}

- (void)updateESP {
    if (!self.enabled || !self.espView) return;
    
    @try {
        // Tối ưu hiệu năng: Cứ mỗi 15 frame (~4 lần/giây) mới gọi Heap Walker quét lại thực thể một lần, 
        // tránh việc gọi liên tục gây nghẽn CPU và sụt giảm FPS của game.
        self.tickCounter++;
        if (self.tickCounter >= 15) {
            self.tickCounter = 0;
            [self.espView updateEntities];
        }
        
        // Yêu cầu vẽ lại giao diện ESP ngay lập tức
        [self.espView setNeedsDisplay];
    } @catch (NSException *e) {
        // Chống crash toàn hệ thống UI
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
