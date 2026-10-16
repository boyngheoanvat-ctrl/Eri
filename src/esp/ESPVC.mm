#import "ESPVC.h"
#import "ESPOverlay.h"
#import "ToolTheme.h"

@interface ESPVC ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UISwitch *masterSwitch;
@property (nonatomic, strong) UISwitch *boxSwitch;
@property (nonatomic, strong) UISwitch *lineSwitch;
@property (nonatomic, strong) UISwitch *distSwitch;
@property (nonatomic, strong) UISwitch *healthSwitch;
@end

@implementation ESPVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    [self buildUI];
}

- (void)buildUI {
    CGFloat w = CGRectGetWidth(self.view.bounds);
    CGFloat h = CGRectGetHeight(self.view.bounds);
    if (w <= 50) w = 450;
    if (h <= 50) h = 300;
    
    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
    self.scrollView.backgroundColor = [UIColor clearColor];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.scrollView];
    
    CGFloat pad = 16;
    CGFloat y = 16;
    CGFloat rowH = 44;
    CGFloat availableW = w - (pad * 2);
    
    [self addRowTitle:@"🟢 Kích Hoạt ESP (Master Toggle)" y:y w:availableW];
    self.masterSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(availableW - 50, y - 2, 51, 31)];
    self.masterSwitch.onTintColor = [ToolTheme shared].accent;
    [self.masterSwitch addTarget:self action:@selector(masterSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.scrollView addSubview:self.masterSwitch];
    
    y += rowH + 8;
    
    UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(pad, y, availableW, 1)];
    sep.backgroundColor = [ToolTheme shared].surfaceAlt;
    [self.scrollView addSubview:sep];
    y += 16;
    
    NSArray *titles = @[@"ESP Box (Khung nhân vật)", 
                          @"ESP Line (Đường gióng)", 
                          @"ESP Distance (Khoảng cách)", 
                          @"ESP Health (Thanh máu)"];
    
    NSArray *switches = @[
        (self.boxSwitch = [self makeSwitch]),
        (self.lineSwitch = [self makeSwitch]),
        (self.distSwitch = [self makeSwitch]),
        (self.healthSwitch = [self makeSwitch])
    ];
    
    for (int i = 0; i < titles.count; i++) {
        [self addRowTitle:titles[i] y:y w:availableW - 70];
        UISwitch *sw = switches[i];
        sw.frame = CGRectMake(availableW - 50, y - 2, 51, 31);
        sw.onTintColor = [ToolTheme shared].accent;
        sw.enabled = NO;
        [sw addTarget:self action:@selector(subSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        [self.scrollView addSubview:sw];
        
        y += rowH;
    }
    
    self.scrollView.contentSize = CGSizeMake(w, y + 20);
}

- (UISwitch *)makeSwitch {
    return [[UISwitch alloc] init];
}

- (void)addRowTitle:(NSString *)title y:(CGFloat)y w:(CGFloat)w {
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(16, y, w, 28)];
    lbl.text = title;
    lbl.textColor = [ToolTheme shared].textPrimary;
    lbl.font = [[ToolTheme shared] monoBoldFont:12];
    [self.scrollView addSubview:lbl];
}

- (void)masterSwitchChanged:(UISwitch *)sender {
    BOOL isOn = sender.isOn;
    
    self.boxSwitch.enabled = isOn;
    self.lineSwitch.enabled = isOn;
    self.distSwitch.enabled = isOn;
    self.healthSwitch.enabled = isOn;
    
    if (!isOn) {
        self.boxSwitch.on = NO;
        self.lineSwitch.on = NO;
        self.distSwitch.on = NO;
        self.healthSwitch.on = NO;
        [[ESPOverlay shared] hide];
    } else {
        [[ESPOverlay shared] show];
    }
    
    [self updateOverlayConfig];
}

- (void)subSwitchChanged:(UISwitch *)sender {
    [self updateOverlayConfig];
}

- (void)updateOverlayConfig {
    ESPOverlay *overlay = [ESPOverlay shared];
    overlay.enabled = self.masterSwitch.isOn;
    overlay.showBox = self.masterSwitch.isOn && self.boxSwitch.isOn;
    overlay.showLine = self.masterSwitch.isOn && self.lineSwitch.isOn;
    overlay.showDistance = self.masterSwitch.isOn && self.distSwitch.isOn;
    overlay.showHP = self.masterSwitch.isOn && self.healthSwitch.isOn;
}

- (void)reload {
    if ([self isViewLoaded]) {
        // Đồng bộ trạng thái giao diện
    }
}

@end
