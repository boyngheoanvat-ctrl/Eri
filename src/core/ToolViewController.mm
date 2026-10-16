#import "ToolViewController.h"
#import "ToolTheme.h"
#import "ToolRailButton.h"
#import "ESPVC.h"
#import "DumperVC.h"
#import "MemoryVC.h"
#import "MethodCallerVC.h"
#import "LuaVC.h"
#import "AIChatVC.h"
#import "CHookVC.h" // Thêm header module C++ Hook trong src/c/

@interface ToolViewController ()
@property (nonatomic, strong) UIView *contentArea;
@property (nonatomic, strong) UIView *railView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) NSMutableArray<ToolRailButton *> *railButtons;
@property (nonatomic, strong) NSArray<UIViewController *> *childViewControllersList;
@property (nonatomic, assign) NSInteger currentIndex;
@end

@implementation ToolViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Thiết kế khung cửa sổ chính mang phong cách ImGui Window
    self.view.backgroundColor = [ToolTheme shared].background;
    self.view.layer.cornerRadius = 4.0;
    self.view.layer.borderWidth = 1.0;
    self.view.layer.borderColor = [ToolTheme shared].border.CGColor;
    self.view.clipsToBounds = YES;
    
    [self setupImGuiLayout];
}

- (void)setupImGuiLayout {
    CGFloat totalW = CGRectGetWidth(self.view.bounds);
    CGFloat totalH = CGRectGetHeight(self.view.bounds);
    if (totalW <= 50) totalW = 550;
    if (totalH <= 50) totalH = 340;
    
    // 1. ImGui Title Bar
    UIView *titleBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, totalW, 26)];
    titleBar.backgroundColor = [ToolTheme shared].surfaceAlt;
    titleBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:titleBar];
    
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 0, totalW - 20, 26)];
    self.titleLabel.text = @"  Eri Nguyễn & Team - ImGui Mod Menu v2.0";
    self.titleLabel.textColor = [ToolTheme shared].accent;
    self.titleLabel.font = [[ToolTheme shared] monoBoldFont:11];
    self.titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [titleBar addSubview:self.titleLabel];
    
    UIView *titleSep = [[UIView alloc] initWithFrame:CGRectMake(0, 25, totalW, 1)];
    titleSep.backgroundColor = [ToolTheme shared].border;
    titleSep.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [titleBar addSubview:titleSep];
    
    // 2. Navigation Rail (Tab bên trái)
    CGFloat railW = 90;
    CGFloat railY = 26;
    CGFloat railH = totalH - railY;
    
    self.railView = [[UIView alloc] initWithFrame:CGRectMake(0, railY, railW, railH)];
    self.railView.backgroundColor = [ToolTheme shared].surface;
    self.railView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleRightMargin;
    [self.view addSubview:self.railView];
    
    UIView *railSep = [[UIView alloc] initWithFrame:CGRectMake(railW - 1, 0, 1, railH)];
    railSep.backgroundColor = [ToolTheme shared].border;
    railSep.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleLeftMargin;
    [self.railView addSubview:railSep];
    
    // 3. Content Area
    CGFloat contentX = railW;
    CGFloat contentY = railY;
    CGFloat contentW = totalW - railW;
    CGFloat contentH = railH;
    
    self.contentArea = [[UIView alloc] initWithFrame:CGRectMake(contentX, contentY, contentW, contentH)];
    self.contentArea.backgroundColor = [UIColor clearColor];
    self.contentArea.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.contentArea];
    
    // 4. Khởi tạo danh sách các Tab VC (Bổ sung CHookVC cho src/c/)
    self.childViewControllersList = @[
        [[ESPVC alloc] init],
        [[DumperVC alloc] init],
        [[MemoryVC alloc] init],
        [[MethodCallerVC alloc] init],
        [[LuaVC alloc] init],
        [[AIChatVC alloc] init],
        [[CHookVC alloc] init] // Thêm tab C++ Hook
    ];
    
    NSArray *titles = @[@"ESP", @"Dump", @"Mem", @"Call", @"Lua", @"AI", @"C++"];
    self.railButtons = [NSMutableArray array];
    
    CGFloat btnH = 34; // Tinh chỉnh chiều cao nút một chút cho vừa khít 7 tab
    CGFloat btnY = 6;
    
    for (NSInteger i = 0; i < titles.count; i++) {
        ToolRailButton *btn = [[ToolRailButton alloc] initWithFrame:CGRectMake(6, btnY, railW - 12, btnH)];
        
        // Ép kiểu tường minh để trình biên dịch Clang không báo lỗi strict selector checking
        if ([btn respondsToSelector:@selector(setTitle:forState:)]) {
            [(UIButton *)btn setTitle:titles[i] forState:UIControlStateNormal];
        } else if ([btn respondsToSelector:@selector(setTitle:)]) {
            [(id)btn setTitle:titles[i]];
        }
        
        btn.tag = i;
        [btn addTarget:self action:@selector(didSelectTab:) forControlEvents:UIControlEventTouchUpInside];
        [self.railView addSubview:btn];
        [self.railButtons addObject:btn];
        
        btnY += btnH + 4;
    }
    
    [self selectTab:0];
}

- (void)didSelectTab:(ToolRailButton *)sender {
    [self selectTab:sender.tag];
}

- (void)selectTab:(NSInteger)index {
    if (index < 0 || index >= self.childViewControllersList.count) return;
    self.currentIndex = index;
    
    for (NSInteger i = 0; i < self.railButtons.count; i++) {
        self.railButtons[i].selected = (i == index);
    }
    
    for (UIView *subview in self.contentArea.subviews) {
        [subview removeFromSuperview];
    }
    
    UIViewController *targetVC = self.childViewControllersList[index];
    targetVC.view.frame = self.contentArea.bounds;
    targetVC.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    [self addChildViewController:targetVC];
    [self.contentArea addSubview:targetVC.view];
    [targetVC didMoveToParentViewController:self];
    
    if ([targetVC respondsToSelector:@selector(reload)]) {
        [targetVC performSelector:@selector(reload)];
    }
}

- (void)reload {
    if (self.currentIndex >= 0 && self.currentIndex < self.childViewControllersList.count) {
        UIViewController *currentVC = self.childViewControllersList[self.currentIndex];
        if ([currentVC respondsToSelector:@selector(reload)]) {
            [currentVC performSelector:@selector(reload)];
        }
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (self.childViewControllersList.count > 0 && self.currentIndex < self.childViewControllersList.count) {
        UIViewController *currentVC = self.childViewControllersList[self.currentIndex];
        currentVC.view.frame = self.contentArea.bounds;
    }
}

@end
