#import "ESPVC.h"
#import "ESPOverlay.h"
#import "ToolTheme.h"

@interface ESPVC ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UISwitch *espSwitch;
@property (nonatomic, strong) UISwitch *boxSwitch;
@property (nonatomic, strong) UISwitch *lineSwitch;
@property (nonatomic, strong) UISwitch *hpSwitch;
@property (nonatomic, strong) UISwitch *nameDistSwitch;
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
    if (w <= 50) w = 400;
    
    self.scrollView.frame = CGRectMake(0, 0, w, h);
    self.scrollView.contentSize = CGSizeMake(w, 420);
    
    // Tự động căn chỉnh lại chiều rộng row và lùi vị trí UISwitch vào trong an toàn tuyệt đối
    for (UIView *subview in self.scrollView.subviews) {
        if ([subview isKindOfClass:[UIView class]] && subview != self.scrollView.subviews.firstObject) {
            CGRect f = subview.frame;
            f.size.width = w - 32;
            subview.frame = f;
            
            for (UIView *inner in subview.subviews) {
                if ([inner isKindOfClass:[UISwitch class]]) {
                    CGRect sf = inner.frame;
                    // Đặt lùi switch cách mép phải 85pt để không bao giờ bị lẹm viền
                    sf.origin.x = f.size.width - sf.size.width - 20;
                    inner.frame = sf;
                } else if ([inner isKindOfClass:[UILabel class]]) {
                    CGRect lf = inner.frame;
                    lf.size.width = f.size.width - 100;
                    inner.frame = lf;
                }
            }
        }
    }
}

- (void)buildUI {
    @autoreleasepool {
        CGFloat w = CGRectGetWidth(self.view.bounds);
        CGFloat h = CGRectGetHeight(self.view.bounds);
        if (w <= 50) w = 400;

        self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
        self.scrollView.backgroundColor = [UIColor clearColor];
        self.scrollView.showsVerticalScrollIndicator = YES;
        self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.view addSubview:self.scrollView];

        CGFloat y = 16;
        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(16, y, w - 32, 28)];
        title.text = @"ESP All Game";
        title.textColor = [ToolTheme shared].textPrimary;
        title.font = [[ToolTheme shared] monoBoldFont:16];
        title.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self.scrollView addSubview:title];
        y += 40;

        self.espSwitch = [self addRow:@"Kích Hoạt ESP" desc:@"Hiển thị trực tiếp lên màn hình game" y:y on:YES action:@selector(toggleESP:)];
        y += 65;
        self.boxSwitch = [self addRow:@"Bật/Tắt ESP Box" desc:@"Khung bao quanh mục tiêu" y:y on:YES action:nil];
        y += 65;
        self.lineSwitch = [self addRow:@"Bật/Tắt ESP Line" desc:@"Đường chỉ hướng mục tiêu" y:y on:YES action:nil];
        y += 65;
        self.hpSwitch = [self addRow:@"Bật/Tắt ESP HP" desc:@"Hiển thị HP thời gian thực" y:y on:YES action:nil];
        y += 65;
        self.nameDistSwitch = [self addRow:@"Bật/Tắt ESP Tên/Khoảng cách" desc:@"Hiển thị tên và khoảng cách (CM)" y:y on:YES action:nil];
        y += 80;

        self.scrollView.contentSize = CGSizeMake(w, y);
    }
}

- (UISwitch *)addRow:(NSString *)title desc:(NSString *)desc y:(CGFloat)y on:(BOOL)on action:(SEL)action {
    @autoreleasepool {
        CGFloat w = CGRectGetWidth(self.view.bounds);
        if (w <= 50) w = 400;
        
        UIView *row = [[UIView alloc] initWithFrame:CGRectMake(16, y, w - 32, 54)];
        row.backgroundColor = [ToolTheme shared].surface;
        row.layer.cornerRadius = 6;
        row.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self.scrollView addSubview:row];

        UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, w - 120, 18)];
        t.text = title;
        t.textColor = [ToolTheme shared].textPrimary;
        t.font = [[ToolTheme shared] monoBoldFont:12];
        t.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [row addSubview:t];

        UILabel *d = [[UILabel alloc] initWithFrame:CGRectMake(12, 28, w - 120, 16)];
        d.text = desc;
        d.textColor = [ToolTheme shared].textMuted;
        d.font = [[ToolTheme shared] monoFont:10];
        d.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [row addSubview:d];

        // Cố định vị trí switch lùi vào trong an toàn
        UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(CGRectGetWidth(row.bounds) - 71, 11, 51, 31)];
        sw.onTintColor = [ToolTheme shared].accent;
        sw.on = on;
        sw.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
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
