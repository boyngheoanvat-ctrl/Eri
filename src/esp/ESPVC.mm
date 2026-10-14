#import "ESPVC.h"
#import "ESPOverlay.h"
#import "ToolTheme.h"

@interface ESPVC ()
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

- (void)buildUI {
    CGFloat w = CGRectGetWidth(self.view.bounds);
    CGFloat y = 16;
    CGFloat pad = 16;

    // Title
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(pad, y, w - pad * 2, 28)];
    title.text = @"ESP Overlay";
    title.textColor = [ToolTheme shared].textPrimary;
    title.font = [[ToolTheme shared] monoBoldFont:16];
    [self.view addSubview:title];
    y += 36;

    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(pad, y, w - pad * 2, 18)];
    sub.text = @"Hien thi thong tin entity len man hinh";
    sub.textColor = [ToolTheme shared].textMuted;
    sub.font = [[ToolTheme shared] monoFont:10];
    [self.view addSubview:sub];
    y += 30;

    // Toggle rows
    self.masterSwitch = [self addRow:@"Master Enable" desc:@"Bat/tat ESP" y:y on:ESPOverlay.shared.enabled];
    [self.masterSwitch addTarget:self action:@selector(masterChanged)
                forControlEvents:UIControlEventValueChanged];
    y += 60;

    self.hpSwitch = [self addRow:@"Show HP" desc:@"Thanh mau" y:y on:ESPOverlay.shared.showHP];
    [self.hpSwitch addTarget:self action:@selector(optionChanged)
            forControlEvents:UIControlEventValueChanged];
    y += 60;

    self.nameSwitch = [self addRow:@"Show Name" desc:@"Ten entity" y:y on:ESPOverlay.shared.showName];
    [self.nameSwitch addTarget:self action:@selector(optionChanged)
              forControlEvents:UIControlEventValueChanged];
    y += 60;

    self.distanceSwitch = [self addRow:@"Show Distance" desc:@"Khoang cach" y:y on:ESPOverlay.shared.showDistance];
    [self.distanceSwitch addTarget:self action:@selector(optionChanged)
                  forControlEvents:UIControlEventValueChanged];
    y += 60;

    self.boxSwitch = [self addRow:@"Show Box" desc:@"Khung vuong" y:y on:ESPOverlay.shared.showBox];
    [self.boxSwitch addTarget:self action:@selector(optionChanged)
             forControlEvents:UIControlEventValueChanged];
    y += 60;

    self.lineSwitch = [self addRow:@"Show Line" desc:@"Duong ke tu duoi man hinh" y:y on:ESPOverlay.shared.showLine];
    [self.lineSwitch addTarget:self action:@selector(optionChanged)
              forControlEvents:UIControlEventValueChanged];
    y += 70;

    // Status
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(pad, y, w - pad * 2, 20)];
    self.statusLabel.text = ESPOverlay.shared.enabled ? @"ESP DANG BAT" : @"ESP DANG TAT";
    self.statusLabel.textColor = ESPOverlay.shared.enabled ? [ToolTheme shared].success : [ToolTheme shared].textMuted;
    self.statusLabel.font = [[ToolTheme shared] monoBoldFont:12];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.statusLabel];
}

- (UISwitch *)addRow:(NSString *)title desc:(NSString *)desc y:(CGFloat)y on:(BOOL)on {
    CGFloat w = CGRectGetWidth(self.view.bounds);
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(16, y, w - 32, 52)];
    row.backgroundColor = [ToolTheme shared].surface;
    row.layer.cornerRadius = 6;
    [self.view addSubview:row];

    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, w - 100, 18)];
    t.text = title;
    t.textColor = [ToolTheme shared].textPrimary;
    t.font = [[ToolTheme shared] monoBoldFont:12];
    [row addSubview:t];

    UILabel *d = [[UILabel alloc] initWithFrame:CGRectMake(12, 28, w - 100, 16)];
    d.text = desc;
    d.textColor = [ToolTheme shared].textMuted;
    d.font = [[ToolTheme shared] monoFont:10];
    [row addSubview:d];

    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(CGRectGetWidth(row.bounds) - 60, 11, 51, 31)];
    sw.onTintColor = [ToolTheme shared].accent;
    sw.on = on;
    [row addSubview:sw];
    return sw;
}

#pragma mark - Actions

- (void)masterChanged {
    ESPOverlay *esp = [ESPOverlay shared];
    if (self.masterSwitch.isOn) {
        [esp show];
        self.statusLabel.text = @"ESP DANG BAT";
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
