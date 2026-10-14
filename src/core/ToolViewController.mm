#import "ToolViewController.h"
#import "ToolWindow.h"
#import "ToolTheme.h"
#import "ToolRailButton.h"
#import "AIChatVC.h"
#import "DumperVC.h"
#import "MemoryVC.h"
#import "MethodCallerVC.h"
#import "LuaVC.h"
#import "ESPVC.h"
#import "ESPOverlay.h"

@interface ToolViewController () <UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIView *backdrop;
@property (nonatomic, strong) UIView *panel;
@property (nonatomic, strong) UIView *titleBar;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UIView *railView;
@property (nonatomic, strong) UIStackView *railStack;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIView *resizeHandle;

@property (nonatomic, strong) ToolRailButton *aiButton;
@property (nonatomic, strong) ToolRailButton *dumpButton;
@property (nonatomic, strong) ToolRailButton *memoryButton;
@property (nonatomic, strong) ToolRailButton *methodButton;
@property (nonatomic, strong) ToolRailButton *luaButton;
@property (nonatomic, strong) ToolRailButton *espButton;

@property (nonatomic, strong) AIChatVC *aiVC;
@property (nonatomic, strong) DumperVC *dumpVC;
@property (nonatomic, strong) MemoryVC *memoryVC;
@property (nonatomic, strong) MethodCallerVC *methodVC;
@property (nonatomic, strong) LuaVC *luaVC;
@property (nonatomic, strong) ESPVC *espVC;
@property (nonatomic, strong) UIViewController *currentVC;
@property (nonatomic, assign) NSInteger currentTab;

@property (nonatomic, assign) CGSize dragStartSize;
@property (nonatomic, assign) CGPoint dragStartPoint;
@property (nonatomic, assign) BOOL isResizing;
@end

@implementation ToolViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSLog(@"[ToolVC] viewDidLoad START");

    self.view.frame = [UIScreen mainScreen].bounds;
    self.view.backgroundColor = [UIColor clearColor];

    [self buildUI];
    NSLog(@"[ToolVC] after buildUI");

    [self selectTab:0];
    NSLog(@"[ToolVC] after selectTab:0");

    NSLog(@"[ToolVC] viewDidLoad DONE");
}

- (void)buildUI {
    CGRect screen = self.view.bounds;
    if (CGRectIsEmpty(screen)) {
        screen = [UIScreen mainScreen].bounds;
    }

    self.backdrop = [[UIView alloc] initWithFrame:screen];
    self.backdrop.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.5];
    self.backdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    UITapGestureRecognizer *bgTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(closeTapped)];
    [self.backdrop addGestureRecognizer:bgTap];
    [self.view addSubview:self.backdrop];

    CGFloat panelW = MIN(screen.size.width - 40, 600);
    CGFloat panelH = MIN(screen.size.height - 120, 500);
    CGFloat panelX = (screen.size.width - panelW) / 2.0;
    CGFloat panelY = (screen.size.height - panelH) / 2.0;

    self.panel = [[UIView alloc] initWithFrame:CGRectMake(panelX, panelY, panelW, panelH)];
    self.panel.backgroundColor = [ToolTheme shared].background;
    self.panel.layer.cornerRadius = 12;
    self.panel.layer.borderWidth = 1;
    self.panel.layer.borderColor = [ToolTheme shared].border.CGColor;
    self.panel.layer.masksToBounds = YES;
    self.panel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
                                   UIViewAutoresizingFlexibleRightMargin |
                                   UIViewAutoresizingFlexibleTopMargin |
                                   UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:self.panel];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    pan.delegate = self;
    pan.cancelsTouchesInView = NO;
    [self.panel addGestureRecognizer:pan];

    self.titleBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, panelW, 36)];
    self.titleBar.backgroundColor = [ToolTheme shared].surfaceAlt;
    self.titleBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.panel addSubview:self.titleBar];

    UIView *titleLine = [[UIView alloc] initWithFrame:CGRectMake(0, 35, panelW, 1)];
    titleLine.backgroundColor = [ToolTheme shared].divider;
    titleLine.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.titleBar addSubview:titleLine];

    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, 80, 36)];
    self.titleLabel.text = @"ToolKit";
    self.titleLabel.textColor = [ToolTheme shared].textPrimary;
    self.titleLabel.font = [[ToolTheme shared] monoBoldFont:13];
    [self.titleBar addSubview:self.titleLabel];

    self.subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(100, 0, panelW - 160, 36)];
    self.subtitleLabel.text = @"";
    self.subtitleLabel.textColor = [ToolTheme shared].textMuted;
    self.subtitleLabel.font = [[ToolTheme shared] monoFont:10];
    self.subtitleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.titleBar addSubview:self.subtitleLabel];

    self.closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.closeButton.frame = CGRectMake(panelW - 36, 4, 28, 28);
    self.closeButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.closeButton setTitle:@"✕" forState:UIControlStateNormal];
    [self.closeButton setTitleColor:[ToolTheme shared].textPrimary forState:UIControlStateNormal];
    self.closeButton.backgroundColor = [ToolTheme shared].mutedFill;
    self.closeButton.layer.cornerRadius = 5;
    self.closeButton.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [self.closeButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.titleBar addSubview:self.closeButton];

    CGFloat railW = 60;
    CGFloat railH = panelH - 36;
    self.railView = [[UIView alloc] initWithFrame:CGRectMake(0, 36, railW, railH)];
    self.railView.backgroundColor = [ToolTheme shared].surface;
    self.railView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    [self.panel addSubview:self.railView];

    UIView *railDivider = [[UIView alloc] initWithFrame:CGRectMake(railW - 1, 0, 1, railH)];
    railDivider.backgroundColor = [ToolTheme shared].divider;
    railDivider.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    [self.railView addSubview:railDivider];

    CGFloat btnH = 46;
    CGFloat spacing = 4;
    CGFloat totalH = (btnH * 6) + (spacing * 5);
    self.railStack = [[UIStackView alloc] initWithFrame:CGRectMake(0, 8, railW, totalH)];
    self.railStack.axis = UILayoutConstraintAxisVertical;
    self.railStack.spacing = spacing;
    self.railStack.distribution = UIStackViewDistributionFillEqually;
    self.railStack.alignment = UIStackViewAlignmentFill;
    [self.railView addSubview:self.railStack];

    self.aiButton = [self makeRailButton:@"AI" symbol:@"AI" tag:0];
    [self.railStack addArrangedSubview:self.aiButton];
    self.dumpButton = [self makeRailButton:@"Dump" symbol:@"▼" tag:1];
    [self.railStack addArrangedSubview:self.dumpButton];
    self.memoryButton = [self makeRailButton:@"Mem" symbol:@"⚡" tag:2];
    [self.railStack addArrangedSubview:self.memoryButton];
    self.methodButton = [self makeRailButton:@"Call" symbol:@"▶" tag:3];
    [self.railStack addArrangedSubview:self.methodButton];
    self.luaButton = [self makeRailButton:@"Lua" symbol:@"μ" tag:4];
    [self.railStack addArrangedSubview:self.luaButton];
    self.espButton = [self makeRailButton:@"ESP" symbol:@"◉" tag:5];
    [self.railStack addArrangedSubview:self.espButton];

    self.contentView = [[UIView alloc] initWithFrame:CGRectMake(railW, 36, panelW - railW, panelH - 36)];
    self.contentView.backgroundColor = [ToolTheme shared].background;
    self.contentView.clipsToBounds = YES;
    self.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.panel addSubview:self.contentView];

    CGFloat handleSize = 28;
    self.resizeHandle = [[UIView alloc] initWithFrame:
        CGRectMake(panelW - handleSize, panelH - handleSize, handleSize, handleSize)];
    self.resizeHandle.backgroundColor = [UIColor colorWithRed:0.30 green:0.70 blue:1.0 alpha:0.5];
    self.resizeHandle.layer.cornerRadius = handleSize / 2.0;
    self.resizeHandle.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
                                          UIViewAutoresizingFlexibleTopMargin;
    self.resizeHandle.userInteractionEnabled = YES;
    [self.panel addSubview:self.resizeHandle];

    UILabel *dotsLabel = [[UILabel alloc] initWithFrame:self.resizeHandle.bounds];
    dotsLabel.text = @"⋰";
    dotsLabel.textColor = [UIColor whiteColor];
    dotsLabel.font = [UIFont boldSystemFontOfSize:18];
    dotsLabel.textAlignment = NSTextAlignmentCenter;
    [self.resizeHandle addSubview:dotsLabel];

    UIPanGestureRecognizer *resizePan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleResize:)];
    [self.resizeHandle addGestureRecognizer:resizePan];
}

- (ToolRailButton *)makeRailButton:(NSString *)title symbol:(NSString *)symbol tag:(NSInteger)tag {
    ToolRailButton *btn = [[ToolRailButton alloc] initWithTitle:title symbol:symbol];
    btn.tag = tag;
    [btn addTarget:self action:@selector(railButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

- (void)railButtonTapped:(ToolRailButton *)sender {
    [self selectTab:sender.tag];
}

- (void)buildVCs {
    // Không tạo gì cả — lazy create trong selectTab
}

- (void)selectTab:(NSInteger)index {
    NSLog(@"[ToolVC] selectTab %ld START", (long)index);

    if (self.currentVC) {
        [self.currentVC.view removeFromSuperview];
        [self.currentVC removeFromParentViewController];
        self.currentVC = nil;
    }

    UIViewController *newVC = nil;

    if (index == 0) {
        if (!self.aiVC) {
            @try { self.aiVC = [[AIChatVC alloc] init]; }
            @catch (NSException *e) { NSLog(@"[ToolVC] AIChatVC crash: %@", e); return; }
        }
        newVC = self.aiVC;
        self.subtitleLabel.text = @"AI Agent";
    }
    else if (index == 1) {
        if (!self.dumpVC) {
            @try { self.dumpVC = [[DumperVC alloc] init]; }
            @catch (NSException *e) { NSLog(@"[ToolVC] DumperVC crash: %@", e); return; }
        }
        newVC = self.dumpVC;
        self.subtitleLabel.text = @"IL2CPP Dumper";
    }
    else if (index == 2) {
        if (!self.memoryVC) {
            @try { self.memoryVC = [[MemoryVC alloc] init]; }
            @catch (NSException *e) { NSLog(@"[ToolVC] MemoryVC crash: %@", e); return; }
        }
        newVC = self.memoryVC;
        self.subtitleLabel.text = @"Memory Editor";
    }
    else if (index == 3) {
        if (!self.methodVC) {
            @try { self.methodVC = [[MethodCallerVC alloc] init]; }
            @catch (NSException *e) { NSLog(@"[ToolVC] MethodCallerVC crash: %@", e); return; }
        }
        newVC = self.methodVC;
        self.subtitleLabel.text = @"Method Caller";
    }
    else if (index == 4) {
        if (!self.luaVC) {
            @try { self.luaVC = [[LuaVC alloc] init]; }
            @catch (NSException *e) { NSLog(@"[ToolVC] LuaVC crash: %@", e); return; }
        }
        newVC = self.luaVC;
        self.subtitleLabel.text = @"Lua Console";
    }
    else if (index == 5) {
        if (!self.espVC) {
            @try { self.espVC = [[ESPVC alloc] init]; }
            @catch (NSException *e) { NSLog(@"[ToolVC] ESPVC crash: %@", e); return; }
        }
        newVC = self.espVC;
        self.subtitleLabel.text = @"ESP Overlay";
    }

    if (!newVC) return;

    @try {
        [self addChildViewController:newVC];
        newVC.view.frame = self.contentView.bounds;
        newVC.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.contentView addSubview:newVC.view];
        [newVC didMoveToParentViewController:self];
    } @catch (NSException *e) {
        NSLog(@"[ToolVC] addChild crash: %@", e);
        return;
    }

    self.currentVC = newVC;
    self.currentTab = index;

    self.aiButton.active = (index == 0);
    self.dumpButton.active = (index == 1);
    self.memoryButton.active = (index == 2);
    self.methodButton.active = (index == 3);
    self.luaButton.active = (index == 4);
    self.espButton.active = (index == 5);
}

- (void)closeTapped { [[ToolWindow shared] hide]; }

- (void)handlePan:(UIPanGestureRecognizer *)g {
    if (self.isResizing) return;

    CGPoint p = [g translationInView:self.view];
    CGPoint center = self.panel.center;

    center.x += p.x;
    center.y += p.y;

    self.panel.center = center;

    [g setTranslation:CGPointZero inView:self.view];
}

- (void)handleResize:(UIPanGestureRecognizer *)g {
    CGPoint p = [g translationInView:self.view];

    if (g.state == UIGestureRecognizerStateBegan) {
        self.isResizing = YES;
        self.dragStartSize = self.panel.frame.size;
        self.dragStartPoint = self.panel.frame.origin;
    }

    if (g.state == UIGestureRecognizerStateChanged) {
        CGFloat newW = MAX(200, self.dragStartSize.width + p.x);
        CGFloat newH = MAX(150, self.dragStartSize.height + p.y);
        self.panel.frame = CGRectMake(self.dragStartPoint.x, self.dragStartPoint.y, newW, newH);
        [self updateLayoutForPanelSize:CGSizeMake(newW, newH)];
    }

    if (g.state == UIGestureRecognizerStateEnded ||
        g.state == UIGestureRecognizerStateCancelled) {
        self.isResizing = NO;
    }
}

- (void)updateLayoutForPanelSize:(CGSize)panelSize {
    CGFloat panelW = panelSize.width;
    CGFloat panelH = panelSize.height;
    CGFloat railW = 60;

    self.titleBar.frame = CGRectMake(0, 0, panelW, 36);
    self.closeButton.frame = CGRectMake(panelW - 36, 4, 28, 28);
    self.subtitleLabel.frame = CGRectMake(100, 0, MAX(0, panelW - 160), 36);
    self.railView.frame = CGRectMake(0, 36, railW, panelH - 36);

    for (UIView *v in self.railView.subviews) {
        if (v != self.railStack) {
            v.frame = CGRectMake(railW - 1, 0, 1, panelH - 36);
        }
    }

    self.contentView.frame = CGRectMake(railW, 36, panelW - railW, panelH - 36);

    CGFloat handleSize = 28;
    self.resizeHandle.frame = CGRectMake(panelW - handleSize, panelH - handleSize, handleSize, handleSize);

    if (self.currentVC) {
        self.currentVC.view.frame = self.contentView.bounds;
    }
}

- (void)reload {
    @try { if (self.aiVC) [self.aiVC reload]; } @catch (NSException *e) {}
    @try { if (self.dumpVC) [self.dumpVC reload]; } @catch (NSException *e) {}
    @try { if (self.memoryVC) [self.memoryVC reload]; } @catch (NSException *e) {}
    @try { if (self.methodVC) [self.methodVC reload]; } @catch (NSException *e) {}
    @try { if (self.luaVC) [self.luaVC reload]; } @catch (NSException *e) {}
    @try { if (self.espVC) [self.espVC reload]; } @catch (NSException *e) {}
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)g
       shouldReceiveTouch:(UITouch *)touch {
    UIView *v = touch.view;
    while (v && v != self.panel) {
        if ([v isKindOfClass:[UITableView class]])  return NO;
        if ([v isKindOfClass:[UITextView class]])   return NO;
        if ([v isKindOfClass:[UITextField class]])  return NO;
        if ([v isKindOfClass:[UIScrollView class]]) return NO;
        v = v.superview;
    }
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)g
shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
    return YES;
}

@end
