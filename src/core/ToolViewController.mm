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

#pragma mark - BƯỚC 1: TEST tối thiểu

- (void)viewDidLoad {
    [super viewDidLoad];

    NSLog(@"[TEST-B1] viewDidLoad START");

    self.view.frame = [UIScreen mainScreen].bounds;
    self.view.backgroundColor = [UIColor redColor];

    NSLog(@"[TEST-B1] viewDidLoad DONE — chi hien man hinh do");

    // ===== TẤT CẢ COMMENT =====
    // [self buildUI];
    // [self buildVCs];
    // [self selectTab:0];
}

#pragma mark - Các hàm khác giữ nguyên nhưng KHÔNG được gọi

- (void)buildUI {
    // ... giữ nguyên nội dung cũ
}

- (void)buildVCs {
    // ... giữ nguyên nội dung cũ
}

- (void)selectTab:(NSInteger)index {
    // ... giữ nguyên nội dung cũ
}

- (void)reload {
    // ... giữ nguyên nội dung cũ
}

- (void)closeTapped { [[ToolWindow shared] hide]; }

- (void)handlePan:(UIPanGestureRecognizer *)g {
    // ... giữ nguyên nội dung cũ
}

- (void)handleResize:(UIPanGestureRecognizer *)g {
    // ... giữ nguyên nội dung cũ
}

- (void)updateLayoutForPanelSize:(CGSize)panelSize {
    // ... giữ nguyên nội dung cũ
}

- (ToolRailButton *)makeRailButton:(NSString *)title symbol:(NSString *)symbol tag:(NSInteger)tag {
    return nil;
}

- (void)railButtonTapped:(ToolRailButton *)sender {
    // ...
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)g
       shouldReceiveTouch:(UITouch *)touch {
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)g
shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
    return YES;
}

@end
