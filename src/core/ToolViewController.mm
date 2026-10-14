#import "ToolViewController.h"
#import "ToolWindow.h"
#import "ToolTheme.h"
#import "ToolRailButton.h"
#import "AIChatVC.h"
#import "DumperVC.h"
#import "MemoryVC.h"
#import "MethodCallerVC.h"

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
@property (nonatomic, strong) ToolRailButton *memoryButton;
@property (nonatomic, strong) ToolRailButton *methodButton;

@property (nonatomic, strong) AIChatVC *aiVC;
@property (nonatomic, strong) DumperVC *dumpVC;
@property (nonatomic, strong) MemoryVC *memoryVC;
@property (nonatomic, strong) MethodCallerVC *methodVC;
@property (nonatomic, strong) UIViewController *currentVC;
@property (nonatomic, assign) NSInteger currentTab;
@end

@implementation ToolViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    [self buildUI];
    [self buildVCs];
    [self selectTab:0];
}

- (void)buildUI {
    CGRect screen = self.view.bounds;
    CGFloat panelW = screen.size.width;
    CGFloat panelH = screen.size.height;

    // Panel full màn hình
    self.panel = [[UIView alloc] initWithFrame:CGRectMake(0, 0, panelW, panelH)];
    self.panel.backgroundColor = [ToolTheme shared].background;
    self.panel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.panel];

    // ===== TITLE BAR (44px) =====
    self.titleBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, panelW, 44)];
    self.titleBar.backgroundColor = [ToolTheme shared].surfaceAlt;
    self.titleBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.panel addSubview:self.titleBar];

    // Border dưới title
    UIView *titleLine = [[UIView alloc] initWithFrame:CGRectMake(0, 43, panelW, 1)];
    titleLine.backgroundColor = [ToolTheme shared].divider;
    titleLine.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.titleBar addSubview:titleLine];

    // Title "ToolKit" (bên trái)
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, 0, 90, 44)];
    self.titleLabel.text = @"ToolKit";
    self.titleLabel.textColor = [ToolTheme shared].textPrimary;
    self.titleLabel.font = [[ToolTheme shared] monoBoldFont:14];
    self.titleLabel.textAlignment = NSTextAlignmentLeft;
    [self.titleBar addSubview:self.titleLabel];

    // Subtitle (bên phải title, cách 10px)
    self.subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(110, 0, panelW - 200, 44)];
    self.subtitleLabel.text = @"";
    self.subtitleLabel.textColor = [ToolTheme shared].textMuted;
    self.subtitleLabel.font = [[ToolTheme shared] monoFont:11];
    self.subtitleLabel.textAlignment = NSTextAlignmentLeft;
    self.subtitleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.titleBar addSubview:self.subtitleLabel];

    // Close button (bên phải cùng)
    self.closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.closeButton.frame = CGRectMake(panelW - 46, 8, 34, 28);
    self.closeButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.closeButton setTitle:@"✕" forState:UIControlStateNormal];
    [self.closeButton setTitleColor:[ToolTheme shared].textPrimary forState:UIControlStateNormal];
    self.closeButton.backgroundColor = [ToolTheme shared].mutedFill;
    self.closeButton.layer.cornerRadius = 6;
    self.closeButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [self.closeButton addTarget:self action:@selector(closeTapped)
               forControlEvents:UIControlEventTouchUpInside];
    [self.titleBar addSubview:self.closeButton];

    // ===== RAIL (64px, bên trái) =====
    CGFloat railW = 70;
    CGFloat railH = panelH - 44;
    self.railView = [[UIView alloc] initWithFrame:CGRectMake(0, 44, railW, railH)];
    self.railView.backgroundColor = [ToolTheme shared].surface;
    self.railView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    [self.panel addSubview:self.railView];

    // Border phải rail
    UIView *railDivider = [[UIView alloc] initWithFrame:CGRectMake(railW - 1, 0, 1, railH)];
    railDivider.backgroundColor = [ToolTheme shared].divider;
    railDivider.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    [self.railView addSubview:railDivider];

    // ===== RAIL STACK (4 nút chia đều) =====
    CGFloat btnH = 64;
    CGFloat spacing = 8;
    CGFloat totalStackH = (btnH * 4) + (spacing * 3);
    CGFloat stackY = 12;

    self.railStack = [[UIStackView alloc] initWithFrame:
        CGRectMake(0, stackY, railW, totalStackH)];
    self.railStack.axis = UILayoutConstraintAxisVertical;
    self.railStack.spacing = spacing;
    self.railStack.distribution = UIStackViewDistributionFillEqually;
    self.railStack.alignment = UIStackViewAlignmentFill;
    [self.railView addSubview:self.railStack];

    // Nút AI
    self.aiButton = [self makeRailButton:@"AI" symbol:@"AI" tag:0];
    [self.railStack addArrangedSubview:self.aiButton];

    // Nút Dump
    self.dumpButton = [self makeRailButton:@"Dump" symbol:@"▼" tag:1];
    [self.railStack addArrangedSubview:self.dumpButton];

    // Nút Mem
    self.memoryButton = [self makeRailButton:@"Mem" symbol:@"⚡" tag:2];
    [self.railStack addArrangedSubview:self.memoryButton];

    // Nút Call
    self.methodButton = [self makeRailButton:@"Call" symbol:@"▶" tag:3];
    [self.railStack addArrangedSubview:self.methodButton];

    // ===== CONTENT (bên phải rail) =====
    self.contentView = [[UIView alloc] initWithFrame:
        CGRectMake(railW, 44, panelW - railW, panelH - 44)];
    self.contentView.backgroundColor = [ToolTheme shared].background;
    self.contentView.clipsToBounds = YES;
    self.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.panel addSubview:self.contentView];
}

- (ToolRailButton *)makeRailButton:(NSString *)title symbol:(NSString *)symbol tag:(NSInteger)tag {
    ToolRailButton *btn = [[ToolRailButton alloc] initWithTitle:title symbol:symbol];
    btn.tag = tag;
    [btn addTarget:self action:@selector(railButtonTapped:)
  forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

- (void)railButtonTapped:(ToolRailButton *)sender {
    [self selectTab:sender.tag];
}

- (void)buildVCs {
    self.aiVC = [[AIChatVC alloc] init];
    self.dumpVC = [[DumperVC alloc] init];
    self.memoryVC = [[MemoryVC alloc] init];
    self.methodVC = [[MethodCallerVC alloc] init];
}

#pragma mark - Tab switching

- (void)selectTab:(NSInteger)index {
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
    } else if (index == 2) {
        newVC = self.memoryVC;
        self.subtitleLabel.text = @"Memory Editor";
    } else if (index == 3) {
        newVC = self.methodVC;
        self.subtitleLabel.text = @"Method Caller";
    }

    if (!newVC) return;

    [self addChildViewController:newVC];
    newVC.view.frame = self.contentView.bounds;
    newVC.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.contentView addSubview:newVC.view];
    [newVC didMoveToParentViewController:self];

    self.currentVC = newVC;
    self.currentTab = index;

    // Update active state
    self.aiButton.active = (index == 0);
    self.dumpButton.active = (index == 1);
    self.memoryButton.active = (index == 2);
    self.methodButton.active = (index == 3);
}

#pragma mark - Actions

- (void)closeTapped {
    [[ToolWindow shared] hide];
}

- (void)reload {
    [self.aiVC reload];
    [self.dumpVC reload];
    [self.memoryVC reload];
    [self.methodVC reload];
}

@end
