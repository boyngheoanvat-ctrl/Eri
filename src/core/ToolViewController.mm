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

    self.panel = [[UIView alloc] initWithFrame:CGRectMake(0, 0, panelW, panelH)];
    self.panel.backgroundColor = [ToolTheme shared].background;
    self.panel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.panel];

    // Title bar
    self.titleBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, panelW, 44)];
    self.titleBar.backgroundColor = [ToolTheme shared].surfaceAlt;
    self.titleBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.panel addSubview:self.titleBar];

    UIView *titleLine = [[UIView alloc] initWithFrame:CGRectMake(0, 43, panelW, 1)];
    titleLine.backgroundColor = [ToolTheme shared].divider;
    titleLine.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.titleBar addSubview:titleLine];

    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, 0, 100, 44)];
    self.titleLabel.text = @"ToolKit";
    self.titleLabel.textColor = [ToolTheme shared].textPrimary;
    self.titleLabel.font = [[ToolTheme shared] monoBoldFont:14];
    [self.titleBar addSubview:self.titleLabel];

    self.subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(110, 0, panelW - 180, 44)];
    self.subtitleLabel.text = @"";
    self.subtitleLabel.textColor = [ToolTheme shared].textMuted;
    self.subtitleLabel.font = [[ToolTheme shared] monoFont:11];
    self.subtitleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.titleBar addSubview:self.subtitleLabel];

    self.closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.closeButton.frame = CGRectMake(panelW - 44, 8, 32, 28);
    self.closeButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.closeButton setTitle:@"✕" forState:UIControlStateNormal];
    [self.closeButton setTitleColor:[ToolTheme shared].textPrimary forState:UIControlStateNormal];
    self.closeButton.backgroundColor = [ToolTheme shared].mutedFill;
    self.closeButton.layer.cornerRadius = 6;
    [self.closeButton addTarget:self action:@selector(closeTapped)
               forControlEvents:UIControlEventTouchUpInside];
    [self.titleBar addSubview:self.closeButton];

    // Rail
    CGFloat railW = 64;
    self.railView = [[UIView alloc] initWithFrame:CGRectMake(0, 44, railW, panelH - 44)];
    self.railView.backgroundColor = [ToolTheme shared].surface;
    self.railView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    [self.panel addSubview:self.railView];

    UIView *railDivider = [[UIView alloc] initWithFrame:CGRectMake(railW - 1, 0, 1, panelH - 44)];
    railDivider.backgroundColor = [ToolTheme shared].divider;
    railDivider.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    [self.railView addSubview:railDivider];

    self.railStack = [[UIStackView alloc] initWithFrame:CGRectMake(0, 10, railW, panelH - 64)];
    self.railStack.axis = UILayoutConstraintAxisVertical;
    self.railStack.spacing = 4;
    self.railStack.alignment = UIStackViewAlignmentFill;
    self.railStack.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    [self.railView addSubview:self.railStack];

    // AI
    self.aiButton = [[ToolRailButton alloc] initWithTitle:@"AI" symbol:@"ai"];
    self.aiButton.frame = CGRectMake(0, 0, railW, 56);
    [self.aiButton addTarget:self action:@selector(aiTapped)
             forControlEvents:UIControlEventTouchUpInside];
    [self.railStack addArrangedSubview:self.aiButton];

    // Dump
    self.dumpButton = [[ToolRailButton alloc] initWithTitle:@"Dump" symbol:@"dump"];
    self.dumpButton.frame = CGRectMake(0, 0, railW, 56);
    [self.dumpButton addTarget:self action:@selector(dumpTapped)
             forControlEvents:UIControlEventTouchUpInside];
    [self.railStack addArrangedSubview:self.dumpButton];

    // Memory
    self.memoryButton = [[ToolRailButton alloc] initWithTitle:@"Mem" symbol:@"mem"];
    self.memoryButton.frame = CGRectMake(0, 0, railW, 56);
    [self.memoryButton addTarget:self action:@selector(memoryTapped)
             forControlEvents:UIControlEventTouchUpInside];
    [self.railStack addArrangedSubview:self.memoryButton];

    // Method
    self.methodButton = [[ToolRailButton alloc] initWithTitle:@"Call" symbol:@"call"];
    self.methodButton.frame = CGRectMake(0, 0, railW, 56);
    [self.methodButton addTarget:self action:@selector(methodTapped)
             forControlEvents:UIControlEventTouchUpInside];
    [self.railStack addArrangedSubview:self.methodButton];

    // Content
    self.contentView = [[UIView alloc] initWithFrame:
        CGRectMake(railW, 44, panelW - railW, panelH - 44)];
    self.contentView.backgroundColor = [ToolTheme shared].background;
    self.contentView.clipsToBounds = YES;
    self.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.panel addSubview:self.contentView];
}

- (void)buildVCs {
    self.aiVC = [[AIChatVC alloc] init];
    self.dumpVC = [[DumperVC alloc] init];
    self.memoryVC = [[MemoryVC alloc] init];
    self.methodVC = [[MethodCallerVC alloc] init];
}

#pragma mark - Tab

- (void)aiTapped { [self selectTab:0]; }
- (void)dumpTapped { [self selectTab:1]; }
- (void)memoryTapped { [self selectTab:2]; }
- (void)methodTapped { [self selectTab:3]; }

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
