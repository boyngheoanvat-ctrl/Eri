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
@property (nonatomic, strong) UIView *contentArea;
@property (nonatomic, strong) UIView *topTabBar;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIView *resizeHandle;
@property (nonatomic, strong) NSMutableArray<UIButton *> *tabButtons;
@property (nonatomic, strong) NSArray<UIViewController *> *childViewControllersList;
@property (nonatomic, assign) NSInteger currentIndex;
@end

@implementation ToolViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [ToolTheme shared].background;
    self.view.layer.cornerRadius = 6.0;
    self.view.layer.borderWidth = 1.0;
    self.view.layer.borderColor = [ToolTheme shared].border.CGColor;
    self.view.clipsToBounds = YES;
    
    [self setupImGuiLayout];
}

- (void)setupImGuiLayout {
    CGFloat totalW = CGRectGetWidth(self.view.bounds);
    CGFloat totalH = CGRectGetHeight(self.view.bounds);
    if (totalW <= 50) totalW = 600;
    if (totalH <= 50) totalH = 360;
    
    // 1. Title Bar (Kéo di chuyển cửa sổ)
    UIView *titleBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, totalW, 26)];
    titleBar.backgroundColor = [ToolTheme shared].surfaceAlt;
    titleBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:titleBar];
    
    UIPanGestureRecognizer *moveGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleWindowPan:)];
    [titleBar addGestureRecognizer:moveGesture];
    
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 0, totalW - 20, 26)];
    self.titleLabel.text = @" [ MOD BY @Eri Nguyễn ]";
    self.titleLabel.textColor = [ToolTheme shared].accent;
    self.titleLabel.font = [[ToolTheme shared] monoBoldFont:11];
    self.titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [titleBar addSubview:self.titleLabel];
    
    UIView *titleSep = [[UIView alloc] initWithFrame:CGRectMake(0, 25, totalW, 1)];
    titleSep.backgroundColor = [ToolTheme shared].border;
    titleSep.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [titleBar addSubview:titleSep];
    
    // 2. Top Tab Bar (Menu ngang ở đỉnh)
    CGFloat tabBarH = 32;
    CGFloat tabBarY = 26;
    
    self.topTabBar = [[UIView alloc] initWithFrame:CGRectMake(0, tabBarY, totalW, tabBarH)];
    self.topTabBar.backgroundColor = [ToolTheme shared].surface;
    self.topTabBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:self.topTabBar];
    
    UIView *tabSep = [[UIView alloc] initWithFrame:CGRectMake(0, tabBarH - 1, totalW, 1)];
    tabSep.backgroundColor = [ToolTheme shared].border;
    tabSep.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.topTabBar addSubview:tabSep];
    
    // 3. Content Area
    CGFloat contentY = tabBarY + tabBarH;
    CGFloat contentH = totalH - contentY;
    
    self.contentArea = [[UIView alloc] initWithFrame:CGRectMake(0, contentY, totalW, contentH)];
    self.contentArea.backgroundColor = [UIColor clearColor];
    self.contentArea.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.contentArea];
    
    // 4. Khởi tạo danh sách các Tab VC
    self.childViewControllersList = @[
        [[ESPVC alloc] init],
        [[DumperVC alloc] init],
        [[MemoryVC alloc] init],
        [[MethodCallerVC alloc] init],
        [[LuaVC alloc] init],
        [[AIChatVC alloc] init],
        [[CHookVC alloc] init]
    ];
    
    NSArray *titles = @[@"Esp", @"Dumper", @"Memory", @"Call", @"Scripting", @"AI", @"C++"];
    self.tabButtons = [NSMutableArray array];
    
    CGFloat startX = 8;
    CGFloat btnH = 24;
    CGFloat btnY = 4;
    
    for (NSInteger i = 0; i < titles.count; i++) {
        NSString *title = titles[i];
        CGFloat btnW = [title sizeWithAttributes:@{NSFontAttributeName: [[ToolTheme shared] monoBoldFont:11]}].width + 20;
        if (btnW < 60) btnW = 60;
        
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame = CGRectMake(startX, btnY, btnW, btnH);
        [btn setTitle:title forState:UIControlStateNormal];
        btn.titleLabel.font = [[ToolTheme shared] monoBoldFont:11];
        
        btn.backgroundColor = [ToolTheme shared].surfaceAlt;
        btn.layer.cornerRadius = 3;
        btn.layer.borderWidth = 1;
        btn.layer.borderColor = [ToolTheme shared].border.CGColor;
        
        btn.tag = i;
        [btn addTarget:self action:@selector(didSelectTab:) forControlEvents:UIControlEventTouchUpInside];
        [self.topTabBar addSubview:btn];
        [self.tabButtons addObject:btn];
        
        startX += btnW + 6;
    }
    
    // 5. Resize Handle (Góc phải dưới để kéo to nhỏ cửa sổ)
    self.resizeHandle = [[UIView alloc] initWithFrame:CGRectMake(totalW - 20, totalH - 20, 20, 20)];
    self.resizeHandle.backgroundColor = [UIColor clearColor];
    self.resizeHandle.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
    
    for (int i = 0; i < 3; i++) {
        UIView *line = [[UIView alloc] initWithFrame:CGRectMake(14 - (i * 5), 18 - (i * 5), 4 + (i * 5), 2)];
        line.backgroundColor = [ToolTheme shared].textSecondary;
        line.alpha = 0.6;
        [self.resizeHandle addSubview:line];
    }
    
    UIPanGestureRecognizer *resizeGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleResizePan:)];
    [self.resizeHandle addGestureRecognizer:resizeGesture];
    [self.view addSubview:self.resizeHandle];
    
    [self selectTab:0];
}

- (void)handleWindowPan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.view.superview];
    CGPoint center = self.view.center;
    self.view.center = CGPointMake(center.x + translation.x, center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:self.view.superview];
}

- (void)handleResizePan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.view];
    CGRect frame = self.view.frame;
    
    CGFloat newWidth = frame.size.width + translation.x;
    CGFloat newHeight = frame.size.height + translation.y;
    
    if (newWidth < 400) newWidth = 400;
    if (newHeight < 250) newHeight = 250;
    
    self.view.frame = CGRectMake(frame.origin.x, frame.origin.y, newWidth, newHeight);
    [gesture setTranslation:CGPointZero inView:self.view];
}

- (void)didSelectTab:(UIButton *)sender {
    [self selectTab:sender.tag];
}

- (void)selectTab:(NSInteger)index {
    if (index < 0 || index >= self.childViewControllersList.count) return;
    self.currentIndex = index;
    
    for (NSInteger i = 0; i < self.tabButtons.count; i++) {
        UIButton *btn = self.tabButtons[i];
        BOOL isSelected = (i == index);
        btn.selected = isSelected;
        if (isSelected) {
            btn.backgroundColor = [ToolTheme shared].accent;
            [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            btn.layer.borderColor = [ToolTheme shared].accent.CGColor;
        } else {
            btn.backgroundColor = [ToolTheme shared].surfaceAlt;
            [btn setTitleColor:[ToolTheme shared].textSecondary forState:UIControlStateNormal];
            btn.layer.borderColor = [ToolTheme shared].border.CGColor;
        }
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
