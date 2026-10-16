#import "ESPVC.h"
#import "ToolTheme.h"
#import "ESPOverlay.h"

@interface ESPVC ()
@property (nonatomic, strong) UISwitch *espSwitch;
@property (nonatomic, strong) UIView *overlayContainer;
@property (nonatomic, strong) id espOverlayView; // ESPOverlayView
@end

@implementation ESPVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    [self buildUI];
}

- (void)buildUI {
    CGFloat w = CGRectGetWidth(self.view.bounds);
    CGFloat pad = 16;
    CGFloat y = 20;
    
    UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(pad, y, w - pad * 2, 24)];
    titleLbl.text = @"ESP Radar & Circle Settings";
    titleLbl.textColor = [ToolTheme shared].textPrimary;
    titleLbl.font = [[ToolTheme shared] monoBoldFont:13];
    [self.view addSubview:titleLbl];
    y += 36;
    
    // Dòng bật/tắt ESP vẽ vòng tròn
    UIView *rowView = [[UIView alloc] initWithFrame:CGRectMake(pad, y, w - pad * 2, 44)];
    rowView.backgroundColor = [ToolTheme shared].surface;
    rowView.layer.cornerRadius = 6;
    [self.view addSubview:rowView];
    
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(12, 10, w - 100, 24)];
    lbl.text = @"Bật Vòng Tròn ESP (Circle Radar)";
    lbl.textColor = [ToolTheme shared].textPrimary;
    lbl.font = [[ToolTheme shared] monoFont:11];
    [rowView addSubview:lbl];
    
    self.espSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(CGRectGetWidth(rowView.bounds) - 65, 8, 50, 24)];
    self.espSwitch.onTintColor = [ToolTheme shared].accent;
    [self.espSwitch addTarget:self action:@selector(espSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [rowView addSubview:self.espSwitch];
}

- (void)espSwitchChanged:(UISwitch *)sender {
    if (sender.isOn) {
        [self showESPOverlayCircle];
        [self log:@"[ESP] Đã kích hoạt vẽ vòng tròn trên màn hình!"];
    } else {
        [self hideESPOverlayCircle];
        [self log:@"[ESP] Đã tắt vòng tròn ESP."];
    }
}

- (void)showESPOverlayCircle {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) return;
    
    if (!self.overlayContainer) {
        self.overlayContainer = [[UIView alloc] initWithFrame:keyWindow.bounds];
        self.overlayContainer.backgroundColor = [UIColor clearColor];
        self.overlayContainer.userInteractionEnabled = NO;
        
        // Khởi tạo ESPOverlayView vẽ vòng tròn
        Class overlayClass = NSClassFromString(@"ESPOverlayView");
        if (overlayClass) {
            id overlay = [[overlayClass alloc] initWithFrame:keyWindow.bounds];
            [self.overlayContainer addSubview:overlay];
            self.espOverlayView = overlay;
        }
    }
    
    // Bật cờ isESPEnabled thành YES và gọi setNeedsDisplay để vẽ lại
    if (self.espOverlayView && [self.espOverlayView respondsToSelector:@selector(setIsESPEnabled:)]) {
        [self.espOverlayView performSelector:@selector(setIsESPEnabled:) withObject:@(YES)];
    }
    if (self.espOverlayView && [self.espOverlayView respondsToSelector:@selector(setNeedsDisplay)]) {
        [self.espOverlayView performSelector:@selector(setNeedsDisplay)];
    }
    
    [keyWindow addSubview:self.overlayContainer];
}

- (void)hideESPOverlayCircle {
    if (self.overlayContainer) {
        if (self.espOverlayView && [self.espOverlayView respondsToSelector:@selector(setIsESPEnabled:)]) {
            [self.espOverlayView performSelector:@selector(setIsESPEnabled:) withObject:@(NO)];
        }
        [self.overlayContainer removeFromSuperview];
        self.overlayContainer = nil;
    }
}

- (void)log:(NSString *)text {
    // Ghi log trạng thái ESP
    NSLog(@"%@", text);
}

- (void)reload {
    // Đồng bộ trạng thái khi chuyển tab ESP
}

@end
