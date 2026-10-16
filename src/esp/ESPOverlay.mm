#import "ESPOverlay.h"
#import "ToolTheme.h"
#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>

@interface ESPOverlayView : UIView
@property (nonatomic, assign) BOOL isESPEnabled;
@end

@implementation ESPOverlayView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO; // Cho phép chạm xuyên qua màn hình game
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    
    if (!self.isESPEnabled) return;
    
    // Lấy context vẽ đồ họa
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) return;
    
    // Cấu hình nét vẽ vòng tròn (Màu xanh accent nổi bật, độ dày nét 2.0)
    CGContextSetStrokeColorWithColor(context, [ToolTheme shared].accent.CGColor);
    CGContextSetLineWidth(context, 2.0);
    
    // Vẽ 1 vòng tròn ở chính giữa màn hình (hoặc tọa độ radar tâm ngắm)
    CGFloat centerX = CGRectGetWidth(rect) / 2.0;
    CGFloat centerY = CGRectGetHeight(rect) / 2.0;
    CGFloat radius = 80.0; // Bán kính vòng tròn ESP
    
    CGRect circleRect = CGRectMake(centerX - radius, centerY - radius, radius * 2, radius * 2);
    CGContextStrokeEllipseInRect(context, circleRect);
    
    // Vẽ thêm một chấm tâm nhỏ chính giữa vòng tròn để bắt mục tiêu chuẩn xác
    CGFloat dotRadius = 3.0;
    CGRect dotRect = CGRectMake(centerX - dotRadius, centerY - dotRadius, dotRadius * 2, dotRadius * 2);
    CGContextSetFillColorWithColor(context, [UIColor redColor].CGColor);
    CGContextFillEllipseInRect(context, dotRect);
}

@end
