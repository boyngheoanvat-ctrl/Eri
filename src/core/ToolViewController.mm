#import "ToolViewController.h"
#import "ToolTheme.h"
#import "AIChatVC.h"
#import "DumperVC.h"
#import "MemoryVC.h"
#import "MethodCallerVC.h"
#import "LuaVC.h"
#import "ESPVC.h"

@interface ToolViewController ()
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UIView *sidebarView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) NSArray *tabButtons;
@property (nonatomic, assign) NSInteger currentTabIndex;

@property (nonatomic, strong) AIChatVC *aiVC;
@property (nonatomic, strong) DumperVC *dumperVC;
@property (nonatomic, strong) MemoryVC *memoryVC;
@property (nonatomic, strong) MethodCallerVC *methodCallerVC;
@property (nonatomic, strong) LuaVC *luaVC;
@property (nonatomic, strong) ESPVC *espVC;
@end

@implementation ToolViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.08 green:0.10 blue:0.14 alpha:0.95];
    self.view.layer.cornerRadius = 12;
    self.view.clipsToBounds = YES;
    
    [self setupViewControllers];
    [self setupLayout];
    [self setupGestures];
}

- (void)setupViewControllers {
    self.aiVC = [[AIChatVC alloc] init];
    self.dumperVC = [[DumperVC alloc] init];
    self.memoryVC = [[MemoryVC alloc] init];
    self.methodCallerVC = [[MethodCallerVC alloc] init];
    self.luaVC = [[LuaVC alloc] init];
    self.espVC = [[ESPVC alloc] init];
}

- (void)setupLayout {
    CGFloat totalW = CGRectGetWidth(self.view.bounds);
    CGFloat totalH = CGRectGetHeight(self.view.bounds);
    if (totalW <= 0) totalW = 500;
    if (totalH <= 0) totalH = 320;
    
    CGFloat headerH = 36; // Chiều cao cố định thanh tiêu đề
    CGFloat sidebarW = 72; // Độ rộng cột menu tab bên trái
    
    // 1. Thanh tiêu đề đặt đúng ở góc trên cùng (Y = 0)
    self.headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, totalW, headerH)];
    self.headerView.backgroundColor = [ToolTheme shared].surfaceAlt;
    self.headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:self.headerView];
    
    UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(12, 6, totalW - 24, 24)];
    titleLbl.text = @"Mod By Eri Nguyễn (Chạm 3 ngón để Hiện & Menu Chạm 2 ngón để ẩn Menu)";
    titleLbl.textColor = [ToolTheme shared].textPrimary;
    titleLbl.font = [[ToolTheme shared] monoBoldFont:11];
    titleLbl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.headerView addSubview:titleLbl];
    
    // 2. Sidebar đặt ngay bên dưới thanh tiêu đề (Y = headerH, Chiều cao = totalH - headerH)
    self.sidebarView = [[UIView alloc] initWithFrame:CGRectMake(0, headerH, sidebarW, totalH - headerH)];
    self.sidebarView.backgroundColor = [ToolTheme shared].surfaceAlt;
    self.sidebarView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleRightMargin;
    [self.view addSubview:self.sidebarView];
    
    // 3. Content View đặt bên cạnh sidebar và bên dưới tiêu đề
    self.contentView = [[UIView alloc] initWithFrame:CGRectMake(sidebarW, headerH, totalW - sidebarW, totalH - headerH)];
    self.contentView.backgroundColor = [UIColor clearColor];
    self.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.contentView];
    
    NSArray *titles = @[@"AI", @"Dump", @"Mem", @"Call", @"Lua", @"ESP"];
    NSMutableArray *buttons = [NSMutableArray array];
    
    CGFloat btnH = 42;
    CGFloat spacing = 6;
    CGFloat startY = 8;
    
    for (int i = 0; i < titles.count; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame = CGRectMake(6, startY + (i * (btnH + spacing)), sidebarW - 12, btnH);
        btn.backgroundColor = (i == 0) ? [ToolTheme shared].accent : [ToolTheme shared].surface;
        [btn setTitle:titles[i] forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btn.titleLabel.font = [[ToolTheme shared] monoBoldFont:11];
        btn.layer.cornerRadius = 6;
        btn.tag = i;
        [btn addTarget:self action:@selector(didTapTabButton:) forControlEvents:UIControlEventTouchUpInside];
        btn.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self.sidebarView addSubview:btn];
        [buttons addObject:btn];
    }
    self.tabButtons = buttons;
    
    [self selectTab:0];
}

#pragma mark - Gestures (Chạm 2 ngón tay để ẩn menu)

- (void)setupGestures {
    UITapGestureRecognizer *twoFingerTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTwoFingerTap:)];
    twoFingerTap.numberOfTouchesRequired = 2;
    twoFingerTap.numberOfTapsRequired = 1;
    [self.view addGestureRecognizer:twoFingerTap];
}

- (void)handleTwoFingerTap:(UITapGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateEnded) {
        [UIView animateWithDuration:0.25 animations:^{
            self.view.alpha = 0.0;
        } completion:^(BOOL finished) {
            self.view.window.hidden = YES;
            self.view.alpha = 1.0;
        }];
    }
}

- (void)didTapTabButton:(UIButton *)sender {
    [self selectTab:sender.tag];
}

- (void)selectTab:(NSInteger)index {
    self.currentTabIndex = index;
    
    for (int i = 0; i < self.tabButtons.count; i++) {
        UIButton *b = self.tabButtons[i];
        b.backgroundColor = (i == index) ? [ToolTheme shared].accent : [ToolTheme shared].surface;
    }
    
    for (UIView *sub in self.contentView.subviews) {
        [sub removeFromSuperview];
    }
    
    UIViewController *targetVC = nil;
    switch (index) {
        case 0: targetVC = self.aiVC; break;
        case 1: targetVC = self.dumperVC; break;
        case 2: targetVC = self.memoryVC; break;
        case 3: targetVC = self.methodCallerVC; break: // syntax safe
        case 4: targetVC = self.luaVC; break;
        case 5: targetVC = self.espVC; break;
        default: targetVC = self.aiVC; break;
    }
    
    [self addChildViewController:targetVC];
    targetVC.view.frame = self.contentView.bounds;
    targetVC.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.contentView addSubview:targetVC.view];
    [targetVC didMoveToParentViewController:self];
    
    if ([targetVC respondsToSelector:@selector(reload)]) {
        [targetVC performSelector:@selector(reload)];
    }
}

- (void)reload {
    if ([self isViewLoaded] && self.contentView.subviews.count > 0) {
        UIViewController *currentVC = self.childViewControllers.lastObject;
        if (currentVC && [currentVC respondsToSelector:@selector(reload)]) {
            [currentVC performSelector:@selector(reload)];
        }
    }
}

@end
