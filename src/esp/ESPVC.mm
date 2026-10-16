#import "ESPVC.h"
#import "ESPOverlay.h"
#import "ToolTheme.h"

@interface ESPVC ()
@property (nonatomic, strong) UISwitch *espSwitch;
@property (nonatomic, strong) UISwitch *boxSwitch;
@property (nonatomic, strong) UISwitch *lineSwitch;
@property (nonatomic, strong) UISwitch *hpSwitch;
@property (nonatomic, strong) UISwitch *nameDistSwitch; // Thêm property cho nút Tên/Khoảng cách
@end

@implementation ESPVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    [self buildUI];
}

- (void)buildUI {
    @autoreleasepool {
        CGFloat w = CGRectGetWidth(self.view.bounds);
        CGFloat y = 16;
        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(16, y, w - 32, 28)];
        title.text = @"ESP Overlay & Target Configuration";
        title.textColor = [ToolTheme shared].textPrimary;
        title.font = [[ToolTheme shared] monoBoldFont:16];
        [self.view addSubview:title];
        y += 40;

        self.espSwitch = [self addRow:@"Kích Hoạt ESP" desc:@"Hiển thị trực tiếp lên màn hình game" y:y on:NO action:@selector(toggleESP:)];
        y += 65;
        self.boxSwitch = [self addRow:@"Bật/Tắt ESP Box" desc:@"Khung bao quanh mục tiêu" y:y on:NO action:nil];
        y += 65;
        self.lineSwitch = [self addRow:@"Bật/Tắt ESP Line" desc:@"Đường chỉ hướng mục tiêu" y:y on:NO action:nil];
        y += 65;
        self.hpSwitch = [self addRow:@"Bật/Tắt ESP HP" desc:@"Hiển thị HP thời gian thực" y:y on:NO action:nil];
        y += 65;
        self.nameDistSwitch = [self addRow:@"Bật/Tắt ESP Tên/Khoảng cách" desc:@"Hiển thị tên và khoảng cách (CM)" y:y on:NO action:nil];
    }
}

- (UISwitch *)addRow:(NSString *)title desc:(NSString *)desc y:(CGFloat)y on:(BOOL)on action:(SEL)action {
    @autoreleasepool {
        CGFloat w = CGRectGetWidth(self.view.bounds);
        UIView *row = [[UIView alloc] initWithFrame:CGRectMake(16, y, w - 32, 54)];
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
        if (action) [sw addTarget:self action:action forControlEvents:UIControlEventValueChanged];
        [row addSubview:sw];
        return sw;
    }
}

- (void)toggleESP:(UISwitch *)sender {
    @autoreleasepool {
        if (sender.isOn) [[ESPOverlay shared] show];
        else [[ESPOverlay shared] hide];
    }
}

- (void)reload {}

@end
