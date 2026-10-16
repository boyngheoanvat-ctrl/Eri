#import "ESPVC.h"
#import "ESPOverlay.h"
#import "ToolTheme.h"

@interface ESPVC ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UISwitch *masterSwitch; // Nút kích hoạt ESP tổng (vẽ vòng tròn màn hình)
@property (nonatomic, strong) UISwitch *boxSwitch;    // ESP Box
@property (nonatomic, strong) UISwitch *lineSwitch;   // ESP Line
@property (nonatomic, strong) UISwitch *distSwitch;   // ESP Distance
@property (nonatomic, strong) UISwitch *healthSwitch; // ESP Health
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
    
    // 1. Master Toggle: Kích hoạt ESP tổng (vẽ vòng tròn trên màn hình)
    [self addRowTitle:@"🟢 Kích Hoạt ESP (Master Toggle)" y:y w:availableW];
    self.masterSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(availableW - 50, y - 2, 51, 31)];
    self.masterSwitch.onTintColor = [ToolTheme shared].accent;
    [self.masterSwitch addTarget:self action:@selector(masterSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.scrollView addSubview:self.masterSwitch];
    
    y += rowH + 8;
    
    // Vạch ngăn cách
    UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(pad, y, availableW, 1)];
    sep.backgroundColor = [ToolTheme shared].surfaceAlt;
    [self.scrollView addSubview:sep];
    y += 16;
    
    // 2. Các tính năng chi tiết (Box, Line, Distance, Health)
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
        sw.enabled = NO; // Ban đầu tắt Master thì các tính năng con bị vô hiệu hóa
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

#pragma mark - Actions & Logic ESP

- (void)masterSwitchChanged:(UISwitch *)sender {
    BOOL isOn = sender.isOn;
    
    // Kích hoạt hoặc vô hiệu hóa các tính năng con khi bật/tắt Master Switch
    self.boxSwitch.enabled = isOn;
    self.lineSwitch.enabled = isOn;
    self.distSwitch.enabled = isOn;
    self.healthSwitch.enabled = isOn;
    
    if (!isOn) {
        // Nếu tắt master, tự động tắt luôn các tính năng con và xóa sạch overlay
        self.boxSwitch.on = NO;
        self.lineSwitch.on = NO;
        self.distSwitch.on = NO;
        self.healthSwitch.on = NO;
    }
    
    // Gọi sang lớp ESPOverlay để hiển thị/ẩn vòng tròn trạng thái màn hình và render
    [ESPOverlay setMasterEnabled:isOn];
    [self updateOverlayConfig];
}

- (void)subSwitchChanged:(UISwitch *)sender {
    [self updateOverlayConfig];
}

- (void)updateOverlayConfig {
    BOOL master = self.masterSwitch.isOn;
    BOOL box = master && self.boxSwitch.isOn;
    BOOL line = master && self.lineSwitch.isOn;
    BOOL dist = master && self.distSwitch.isOn;
    BOOL health = master && self.healthSwitch.isOn;
    
    // Truyền cấu hình trực tiếp vào engine vẽ ESPOverlay
    [ESPOverlay updateConfigWithMaster:master box:box line:line distance:dist health:health];
}

- (void)reload {
    if ([self isViewLoaded]) {
        // Đồng bộ trạng thái giao diện hiện tại
    }
}

@end
