#import "LuaVC.h"
#import "ToolTheme.h"

@interface LuaVC ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UITextView *consoleView;
@end

@implementation LuaVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    [self buildUI];
}

- (void)buildUI {
    @autoreleasepool {
        CGFloat w = CGRectGetWidth(self.view.bounds);
        CGFloat h = CGRectGetHeight(self.view.bounds);
        if (w <= 50) w = 400;
        if (h <= 50) h = 600;

        // ScrollView chính chứa menu để cuộn mượt mà
        self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, w, h - 110)];
        self.scrollView.contentSize = CGSizeMake(w, 420);
        [self.view addSubview:self.scrollView];

        CGFloat y = 16;
        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(16, y, w - 32, 28)];
        title.text = @"MOD MENU ALL-IN-ONE";
        title.textColor = [ToolTheme shared].textPrimary;
        title.font = [[ToolTheme shared] monoBoldFont:16];
        [self.scrollView addSubview:title];
        y += 36;

        // Tạo các hàng tính năng kèm nút Switch Bật/Tắt
        NSArray *features = @[@"1. Hack Map (CanSight)", @"2. Camera Xa (Zoom)", @"3. Mod Skin", @"4. Bất Tử (God Mode)", @"5. Không Cooldown"];
        for (int i = 0; i < features.count; i++) {
            UIView *rowView = [[UIView alloc] initWithFrame:CGRectMake(16, y, w - 32, 46)];
            rowView.backgroundColor = [ToolTheme shared].surface;
            rowView.layer.cornerRadius = 6;

            UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(12, 3, w - 100, 40)];
            lbl.text = features[i];
            lbl.textColor = [ToolTheme shared].textPrimary;
            lbl.font = [[ToolTheme shared] monoFont:11];
            [rowView addSubview:lbl];

            UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(w - 32 - 60, 7, 51, 31)];
            sw.onTintColor = [ToolTheme shared].accent;
            sw.tag = 100 + i;
            [sw addTarget:self action:@selector(didToggleFeature:) forControlEvents:UIControlEventValueChanged];
            [rowView addSubview:sw];

            [self.scrollView addSubview:rowView];
            y += 54;
        }

        // Console hiển thị log trạng thái ở phía dưới
        self.consoleView = [[UITextView alloc] initWithFrame:CGRectMake(16, h - 102, w - 32, 90)];
        self.consoleView.backgroundColor = [UIColor colorWithRed:0.02 green:0.03 blue:0.05 alpha:1.0];
        self.consoleView.textColor = [ToolTheme shared].success;
        self.consoleView.font = [[ToolTheme shared] monoFont:10];
        self.consoleView.editable = NO;
        self.consoleView.layer.cornerRadius = 6;
        self.consoleView.text = @"[System] Mod Menu Interface Ready. Vui lòng bật tính năng bất kỳ.";
        [self.view addSubview:self.consoleView];
    }
}

- (void)didToggleFeature:(UISwitch *)sender {
    @autoreleasepool {
        NSArray *names = @[@"Hack Map", @"Camera Xa", @"Mod Skin", @"Bất Tử", @"Không Cooldown"];
        NSInteger index = sender.tag - 100;
        if (index >= 0 && index < names.count) {
            NSString *status = sender.isOn ? @"BẬT" : @"TẮT";
            self.consoleView.text = [NSString stringWithFormat:@"[ModMenu] Đã %@ tính năng: %@", status, names[index]];
        }
    }
}

- (void)setScriptContent:(NSString *)content {}
- (void)reload {}

@end
