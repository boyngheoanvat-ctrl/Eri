#import "ESPVC.h"
#import "ESPOverlay.h"
#import "ToolTheme.h"

@interface ESPVC () <UIScrollViewDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UISwitch *masterSwitch;
@property (nonatomic, strong) UISwitch *hpSwitch;
@property (nonatomic, strong) UISwitch *nameSwitch;
@property (nonatomic, strong) UISwitch *distanceSwitch;
@property (nonatomic, strong) UISwitch *boxSwitch;
@property (nonatomic, strong) UISwitch *lineSwitch;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation ESPVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    [self buildUI];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = CGRectGetWidth(self.view.bounds);
    CGFloat h = CGRectGetHeight(self.view.bounds);
    self.scrollView.frame = CGRectMake(0, 0, w, h);
    self.scrollView.contentSize = CGSizeMake(w, 480);
}

- (void)buildUI {
    CGFloat w = CGRectGetWidth(self.view.bounds);
    
    // Sử dụng UIScrollView để chống tràn màn hình khi xoay ngang hoặc kéo khung
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.showsVerticalScrollIndicator = YES;
    [self.view addSubview:self.scrollView];
    
    CGFloat y = 16;
    CGFloat pad = 16;
    CGFloat contentW = w - pad * 2;

    // Title
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(pad, y, contentW, 28)];
    title.text = @"ESP Overlay";
    title.textColor = [ToolTheme shared].textPrimary;
    title.font = [[ToolTheme shared] monoBoldFont:16];
    [self.scrollView addSubview:title];
    y += 34;

    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(pad, y, contentW, 18)];
    sub.text = @"Hien thi thong tin entity len man hinh";
    sub.textColor = [ToolTheme shared].textMuted;
    sub.font = [[ToolTheme shared] monoFont:10];
    [self.scrollView addSubview:sub];
    y += 28;

    // Toggle rows (co giãn theo chiều rộng cửa sổ `contentW`)
    self.masterSwitch = [self addRow:@"Master Enable" desc:@"Bat/tat ESP tong" y:&y on:ESPOverlay.shared.enabled width:contentW];
    [self.masterSwitch addTarget:self action:@selector(masterChanged) forControlEvents:UIControlEventValueChanged];

    self.hpSwitch = [self addRow:@"Show HP" desc:@"Hien thi thanh mau" y:&y on:ESPOverlay.shared.showHP width:contentW];
    [self.hpSwitch addTarget:self action:@selector(optionChanged) forControlEvents:UIControlEventValueChanged];

    self.nameSwitch = [self addRow:@"Show Name" desc:@"Hien thi ten nhan vat" y:&y on:ESPOverlay.shared.showName width:contentW];
    [self.nameSwitch addTarget:self action:@selector(optionChanged) forControlEvents:UIControlEventValueChanged];

    self.distanceSwitch = [self addRow:@"Show Distance" desc:@"Hien thi khoang cach" y:&y on:ESPOverlay.shared.showDistance width:contentW];
    [self.distanceSwitch addTarget:self action:@selector(optionChanged) forControlEvents:UIControlEventValueChanged];

    self.boxSwitch = [self addRow:@"Show Box" desc:@"Ve khung vuong quanh entity" y:&y on:ESPOverlay.shared.showBox width:contentW];
    [self.boxSwitch addTarget:self action:@selector(optionChanged) forControlEvents:UIControlEventValueChanged];

    self.lineSwitch = [self addRow:@"Show Line" desc:@"Duong ke giong tu duoi man hinh" y:&y on:ESPOverlay.shared.showLine width:contentW];
    [self.lineSwitch addTarget:self action:@selector(optionChanged) forControlEvents:UIControlEventValueChanged];

    y += 10;
    // Status label
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(pad, y, contentW, 24)];
    self.statusLabel.text = ESPOverlay.shared.enabled ? @"ESP DANG HOAT DONG" : @"ESP DANG TAT";
    self.statusLabel.textColor = ESPOverlay.shared.enabled ? [ToolTheme shared].success : [ToolTheme shared].textMuted;
    self.statusLabel.font = [[ToolTheme shared] monoBoldFont:12];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    [self.scrollView addSubview:self.statusLabel];
    
    self.scrollView.contentSize = CGSizeMake(w, y + 50);
}

- (UISwitch *)addRow:(NSString *)title desc:(NSString *)desc y:(CGFloat *)yAction on:(BOOL)on width:(CGFloat)width {
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(16, *yAction, width, 50)];
    row.backgroundColor = [ToolTheme shared].surface;
    row.layer.cornerRadius = 6;
    row.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.scrollView addSubview:row];

    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(12, 7, width - 85, 18)];
    t.text = title;
    t.textColor = [ToolTheme shared].textPrimary;
    t.font = [[ToolTheme shared] monoBoldFont:12];
    t.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [row addSubview:t];

    UILabel *d = [[UILabel alloc] initWithFrame:CGRectMake(12, 26, width - 85, 16)];
    d.text = desc;
    d.textColor = [ToolTheme shared].textMuted;
    d.font = [[ToolTheme shared] monoFont:10];
    d.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [row addSubview:d];

    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(width - 65, 10, 51, 31)];
    sw.onTintColor = [ToolTheme shared].accent;
    sw.on = on;
    sw.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [row addSubview:sw];
    
    *yAction += 58;
    return sw;
}

#pragma mark - Actions

- (void)masterChanged {
    ESPOverlay *esp = [ESPOverlay shared];
    if (self.masterSwitch.isOn) {
        [esp show];
        self.statusLabel.text = @"ESP DANG HOAT DONG";
        self.statusLabel.textColor = [ToolTheme shared].success;
    } else {
        [esp hide];
        self.statusLabel.text = @"ESP DANG TAT";
        self.statusLabel.textColor = [ToolTheme shared].textMuted;
    }
}

- (void)optionChanged {
    ESPOverlay *esp = [ESPOverlay shared];
    esp.showHP = self.hpSwitch.isOn;
    esp.showName = self.nameSwitch.isOn;
    esp.showDistance = self.distanceSwitch.isOn;
    esp.showBox = self.boxSwitch.isOn;
    esp.showLine = self.lineSwitch.isOn;
    [esp reload];
}

- (void)reload {
    ESPOverlay *esp = [ESPOverlay shared];
    self.masterSwitch.on = esp.enabled;
    self.hpSwitch.on = esp.showHP;
    self.nameSwitch.on = esp.showName;
    self.distanceSwitch.on = esp.showDistance;
    self.boxSwitch.on = esp.showBox;
    self.lineSwitch.on = esp.showLine;
}

@end
