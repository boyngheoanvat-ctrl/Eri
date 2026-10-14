#import "ToolViewController.h"
#import "ToolTheme.h"
#import "ToolRailButton.h"
#import "AIChatVC.h"
#import "DumperVC.h"

@interface ToolViewController ()

@property (nonatomic, strong) UIView *panel;
@property (nonatomic, strong) UIView *titleBar;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UIView *railView;
@property (nonatomic, strong) UIStackView *railStack;
@property (nonatomic, strong) UIView *contentView;

@property (nonatomic, strong) ToolRailButton *aiButton;
@property (nonatomic, strong) ToolRailButton *dumpButton;

@property (nonatomic, strong) AIChatVC *aiVC;
@property (nonatomic, strong) DumperVC *dumpVC;
@property (nonatomic, strong) UIViewController *currentVC;

@property (nonatomic, assign) NSInteger currentTab;
@property (nonatomic, assign) CGRect panelFrame;

@end

@implementation ToolViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];

    [self buildUI];
    [self buildVCs];
    [self selectTab:0];
}

- (void)buildUI {
    CGRect screen = self.view.bounds;
    CGFloat panelW = MIN(720, screen.size.width - 40);
    CGFloat panelH = MIN(520, screen.size.height - 120);
    CGFloat panelX = (screen.size.width - panelW) / 2.0;
    CGFloat panelY = (screen.size.height - panelH) / 2.0;

    self.panelFrame = CGRectMake(panelX, panelY, panelW, panelH);

    // Panel chính
    self.panel = [[UIView alloc] initWithFrame:self.panelFrame];
    self.panel.backgroundColor = [ToolTheme shared].background;
    self.panel.layer.cornerRadius = 10;
    self.panel.layer.borderWidth = 1;
    self.panel.layer.borderColor = [ToolTheme shared].border.CGColor;
    self.panel.layer.masksToBounds = YES;
    [self.view addSubview:self.panel];

    // Cho phép kéo panel
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(handlePan:)];
    [self.panel addGestureRecognizer:pan];

    // Title bar (32px)
    self.titleBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, panelW, 32)];
    self.titleBar.backgroundColor = [ToolTheme shared].surfaceAlt;
    [self.panel addSubview:self.titleBar];

    // Title
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 0, panelW - 200, 32)];
    self.titleLabel.text = @"ToolKit";
    self.titleLabel.textColor = [ToolTheme shared].textPrimary;
    self.titleLabel.font = [[ToolTheme shared] monoBoldFont:12];
    [self.titleBar addSubview:self.titleLabel];

    // Subtitle
    self.subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(120, 0, panelW - 200, 32)];
    self.subtitleLabel.text = @"";
    self.subtitleLabel.textColor = [ToolTheme shared].textMuted;
    self.subtitleLabel.font = [[ToolTheme shared] monoFont:10];
    [self.titleBar addSubview:self.subtitleLabel];

    // Close button
    self.closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.closeButton.frame = CGRectMake(panelW - 32, 4, 24, 24);
    [self.closeButton setTitle:@"✕" forState:UIControlStateNormal];
    [self.closeButton setTitleColor:[ToolTheme shared].textPrimary forState:UIControlStateNormal];
    self.closeButton.backgroundColor = [ToolTheme shared].mutedFill;
    self.closeButton.layer.cornerRadius = 4;
    [self.closeButton addTarget:self action:@selector(closeTapped)
               forControlEvents:UIControlEventTouchUpInside];
    [self.titleBar addSubview:self.closeButton];

    // Rail view (bên trái, rộng 64px)
    CGFloat railW = 64;
    self.railView = [[UIView alloc] initWithFrame:CGRectMake(0, 32, railW, panelH - 32)];
    self.railView.backgroundColor = [ToolTheme shared].surface;
    [self.panel addSubview:self.railView];

    // Đường phân cách rail
    UIView *railDivider = [[UIView alloc] initWithFrame:CGRectMake(railW - 1, 0, 1, panelH - 32)];
    railDivider.backgroundColor = [ToolTheme shared].divider;
    [self.railView addSubview:railDivider];

    // Rail stack
    self.railStack = [[UIStackView alloc] initWithFrame:CGRectMake(0, 10, railW, panelH - 52)];
    self.railStack.axis = UILayoutConstraintAxisVertical;
    self.railStack.spacing = 4;
    self.railStack.alignment = UIStackViewAlignmentFill;
    [self.railView addSubview:self.railStack];

    // AI button
    self.aiButton = [[ToolRailButton alloc] initWithTitle:@"AI" symbol:@"ai"];
    self.aiButton.frame = CGRectMake(0, 0, railW, 56);
    [self.aiButton addTarget:self action:@selector(aiTapped)
             forControlEvents:UIControlEventTouchUpInside];
    [self.railStack addArrangedSubview:self.aiButton];

    // Dump button
    self.dumpButton = [[ToolRailButton alloc] initWithTitle:@"Dump" symbol:@"dump"];
    self.dumpButton.frame = CGRectMake(0, 0, railW, 56);
    [self.dumpButton addTarget:self action:@selector(dumpTapped)
             forControlEvents:UIControlEventTouchUpInside];
    [self.railStack addArrangedSubview:self.dumpButton];

    // Content view (bên phải rail)
    self.contentView = [[UIView alloc] initWithFrame:
        CGRectMake(railW, 32, panelW - railW, panelH - 32)];
    self.contentView.backgroundColor = [ToolTheme shared].background;
    [self.panel addSubview:self.contentView];
}

- (void)buildVCs {
    self.aiVC = [[AIChatVC alloc] init];
    self.dumpVC = [[DumperVC alloc] init];
}

#pragma mark - Tab switching

- (void)aiTapped {
    [self selectTab:0];
}

- (void)dumpTapped {
    [self selectTab:1];
}

- (void)selectTab:(NSInteger)index {
    // Remove current VC
    if (self.currentVC) {
        [self.currentVC.view removeFromSuperview];
        [self.currentVC removeFromParentViewController];
    }

    UIViewController *newVC = nil;
    if (index == 0) {
        newVC = self.aiVC;
        self.subtitleLabel.text = @"AI Agent";
    } else if (index == 1) {
        newVC = self.dumpVC;
        self.subtitleLabel.text = @"IL2CPP Dumper";
    }

    if (!newVC) return;

    [self addChildViewController:newVC];
    newVC.view.frame = self.contentView.bounds;
    newVC.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.contentView addSubview:newVC.view];
    [newVC didMoveToParentViewController:self];

    self.currentVC = newVC;
    self.currentTab = index;

    // Update rail buttons
    self.aiButton.active = (index == 0);
    self.dumpButton.active = (index == 1);
}

#pragma mark - Actions

- (void)closeTapped {
    [[ToolWindow shared] hide];
}

- (void)handlePan:(UIPanGestureRecognizer *)g {
    CGPoint p = [g translationInView:self.view];
    CGPoint center = self.panel.center;
    center.x += p.x;
    center.y += p.y;
    self.panel.center = center;
    [g setTranslation:CGPointZero inView:self.view];
}

#pragma mark - Reload

- (void)reload {
    [self.aiVC reload];
    [self.dumpVC reload];
}

@end
