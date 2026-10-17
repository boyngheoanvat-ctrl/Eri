#import "ToolViewController.h"
#import "ToolTheme.h"
#import "ESPVC.h"
#import "DumperVC.h"
#import "MemoryVC.h"
#import "MethodCallerVC.h"
#import "LuaVC.h"
#import "AIChatVC.h"
#import "CHookVC.h"

@interface ToolViewController ()
@property (nonatomic, strong) UIView *sidebarView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) NSArray *controllers;
@property (nonatomic, strong) NSArray *buttons;
@property (nonatomic, assign) NSInteger currentIndex;
@end

@implementation ToolViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    self.view.layer.cornerRadius = 10;
    self.view.layer.masksToBounds = YES;

    // Khởi tạo các View Controller cho từng tab chức năng
    self.controllers = @[
        [[ESPVC alloc] init],
        [[DumperVC alloc] init],
        [[MemoryVC alloc] init],
        [[MethodCallerVC alloc] init],
        [[LuaVC alloc] init],
        [[AIChatVC alloc] init],
        [[CHookVC alloc] init]
    ];

    [self buildUI];
    [self switchTab:0];
}

- (void)buildUI {
    @autoreleasepool {
        CGFloat w = CGRectGetWidth(self.view.bounds);
        CGFloat h = CGRectGetHeight(self.view.bounds);

        // Thanh Header phía trên
        UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 40)];
        header.backgroundColor = [ToolTheme shared].surface;
        header.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self.view addSubview:header];

        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, 200, 40)];
        title.text = @"ToolKit - AI Agent";
        title.textColor = [ToolTheme shared].textPrimary;
        title.font = [[ToolTheme shared] monoBoldFont:13];
        [header addSubview:title];

        // Sidebar bên trái chứa các nút tab (Đã fix hoàn toàn lỗi font chữ)
        CGFloat sidebarW = 75;
        self.sidebarView = [[UIView alloc] initWithFrame:CGRectMake(0, 40, sidebarW, h - 40)];
        self.sidebarView.backgroundColor = [ToolTheme shared].surfaceAlt;
        self.sidebarView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
        [self.view addSubview:self.sidebarView];

        NSArray *titles = @[@"ESP", @"Dump", @"Mem", @"Call", @"Lua", @"AI", @"C++"];
        NSMutableArray *btnArray = [NSMutableArray array];
        CGFloat btnH = 50;

        for (NSInteger i = 0; i < titles.count; i++) {
            UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
            btn.frame = CGRectMake(0, i * btnH, sidebarW, btnH);
            [btn setTitle:titles[i] forState:UIControlStateNormal];
            [btn setTitleColor:[ToolTheme shared].textPrimary forState:UIControlStateNormal];
            btn.titleLabel.font = [[ToolTheme shared] monoBoldFont:12];
            btn.tag = i;
            [btn addTarget:self action:@selector(didTapTab:) forControlEvents:UIControlEventTouchUpInside];
            [self.sidebarView addSubview:btn];
            [btnArray addObject:btn];
        }
        self.buttons = btnArray;

        // Vùng chứa nội dung chính của tab
        self.contentView = [[UIView alloc] initWithFrame:CGRectMake(sidebarW, 40, w - sidebarW, h - 40)];
        self.contentView.backgroundColor = [ToolTheme shared].background;
        self.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.view addSubview:self.contentView];
    }
}

- (void)didTapTab:(UIButton *)sender {
    [self switchTab:sender.tag];
}

- (void)switchTab:(NSInteger)index {
    if (index < 0 || index >= self.controllers.count) return;
    self.currentIndex = index;

    for (NSInteger i = 0; i < self.buttons.count; i++) {
        UIButton *b = self.buttons[i];
        if (i == index) {
            b.backgroundColor = [ToolTheme shared].accent;
            [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        } else {
            b.backgroundColor = [UIColor clearColor];
            [b setTitleColor:[ToolTheme shared].textPrimary forState:UIControlStateNormal];
        }
    }

    for (UIView *sub in self.contentView.subviews) {
        [sub removeFromSuperview];
    }

    UIViewController *vc = self.controllers[index];
    vc.view.frame = self.contentView.bounds;
    vc.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.contentView addSubview:vc.view];

    @try {
        if ([vc respondsToSelector:@selector(reload)]) {
            [vc performSelector:@selector(reload)];
        }
    } @catch (NSException *e) {}
}

- (void)reload {
    if (self.currentIndex < self.controllers.count) {
        UIViewController *vc = self.controllers[self.currentIndex];
        @try {
            if ([vc respondsToSelector:@selector(reload)]) {
                [vc performSelector:@selector(reload)];
            }
        } @catch (NSException *e) {}
    }
}

@end
