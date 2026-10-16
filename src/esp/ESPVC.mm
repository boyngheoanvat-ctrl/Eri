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
    self.view.backgroundColor = [UIColor clearColor];
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
    
    CGFloat y = 12;
    CGFloat rowH = 36; // Chiều cao dòng gọn nhẹ kiểu ImGui
    CGFloat availableW = w - 24;
    
    // Header Section / Group Box style ImGui
    [self addImGuiSectionHeader:@"[ CONFIGURATION ]" y:y w:availableW];
    y += 24;
    
    [self addRowTitle:@"  > Master Toggle (Bật/Tắt ESP)" y:y w:availableW];
    self.masterSwitch = [self makeImGuiSwitch];
    self.masterSwitch.frame = CGRectMake(availableW - 55, y - 4, 51, 31);
    [self.masterSwitch addTarget:self action:@selector(masterSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.scrollView addSubview:self.masterSwitch];
    y += rowH + 6;
    
    // Separator line
    UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(12, y, availableW, 1)];
    sep.backgroundColor = [ToolTheme shared].border;
    [self.scrollView addSubview:sep];
    y += 12;
    
    [self addImGuiSectionHeader:@"[ VISUAL FEATURES ]" y:y w:availableW];
    y += 24;
    
    NSArray *titles = @[@"  > Box (Khung nhân vật)", 
                          @"  > Line (Đường gióng)", 
                          @"  > Distance (Khoảng cách)", 
                          @"  > Health Bar (Thanh máu)"];
    
    NSArray *switches = @[
        (self.boxSwitch = [self makeImGuiSwitch]),
        (self.lineSwitch = [self makeImGuiSwitch]),
        (self.distSwitch = [self makeImGuiSwitch]),
        (self.healthSwitch = [self makeImGuiSwitch])
    ];
    
    for (int i = 0; i < titles.count; i++) {
        [self addRowTitle:titles[i] y:y w:availableW - 70];
        UISwitch *sw = switches[i];
        sw.frame = CGRectMake(availableW - 55, y - 4, 51, 31);
        sw.enabled = NO;
        [sw addTarget:self action:@selector(subSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        [self.scrollView addSubview:sw];
        y += rowH;
    }
    
    self.scrollView.contentSize = CGSizeMake(w, y + 20);
}

- (UISwitch *)makeImGuiSwitch {
    UISwitch *sw = [[UISwitch alloc] init];
    sw.onTintColor = [ToolTheme shared].accent;
    return sw;
}

- (void)addImGuiSectionHeader:(NSString *)title y:(CGFloat)y w:(CGFloat)w {
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(12, y, w, 18)];
    lbl.text = title;
    lbl.textColor = [ToolTheme shared].accent;
    lbl.font = [[ToolTheme shared] monoBoldFont:11];
    [self.scrollView addSubview:lbl];
}

- (void)addRowTitle:(NSString *)title y:(CGFloat)y w:(CGFloat)w {
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(12, y, w, 24)];
    lbl.text = title;
    lbl.textColor = [ToolTheme shared].textPrimary;
    lbl.font = [[ToolTheme shared] monoFont:11];
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
    if ([self isViewLoaded]) {}
}

@end
