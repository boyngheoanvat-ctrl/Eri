#import "ToolViewController.h"
#import "ToolTheme.h"
#import "AIChatVC.h"
#import "DumperVC.h"
#import "MemoryVC.h"
#import "MethodCallerVC.h"
#import "LuaVC.h"
#import "ESPVC.h"

@interface ToolViewController ()
@property (nonatomic, strong) UIView *contentContainer;
@property (nonatomic, strong) NSArray *viewControllers;
@property (nonatomic, assign) NSInteger currentIndex;
@end

@implementation ToolViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [ToolTheme shared].background;
    
    // Khởi tạo các tab chức năng
    self.viewControllers = @[
        [[AIChatVC alloc] init],
        [[DumperVC alloc] init],
        [[MemoryVC alloc] init],
        [[MethodCallerVC alloc] init],
        [[LuaVC alloc] init],
        [[ESPVC.alloc] init]
    ];
    
    [self setupMainLayout];
    [self selectTab:0];
}

- (void)setupMainLayout {
    CGFloat w = CGRectGetWidth(self.view.bounds);
    CGFloat h = CGRectGetHeight(self.view.bounds);
    
    // Đảm bảo lề trên (dưới thanh tiêu đề "Mod By Eri Nguyễn") và lề xung quanh an toàn tuyệt đối
    CGFloat topBarH = 44.0;
    CGFloat padding = 8.0; // Khoảng cách đệm an toàn bốn phía trái, phải, trên, dưới
    
    CGFloat containerX = 65.0; // Vị trí sau thanh menu dọc bên trái
    CGFloat containerY = topBarH + padding;
    CGFloat containerW = w - containerX - padding;
    CGFloat containerH = h - containerY - padding;
    
    self.contentContainer = [[UIView alloc] initWithFrame:CGRectMake(containerX, containerY, containerW, containerH)];
    self.contentContainer.backgroundColor = [UIColor clearColor];
    self.contentContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.contentContainer];
}

- (void)selectTab:(NSInteger)index {
    if (index < 0 || index >= self.viewControllers.count) return;
    self.currentIndex = index;
    
    // Xóa view cũ an toàn
    for (UIView *sub in self.contentContainer.subviews) {
        [sub removeFromSuperview];
    }
    
    UIViewController *vc = self.viewControllers[index];
    vc.view.frame = self.contentContainer.bounds;
    vc.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    [self addChildViewController:vc];
    [self.contentContainer addSubview:vc.view];
    [vc didMoveToParentViewController:self];
    
    if ([vc respondsToSelector:@selector(reload)]) {
        [vc performSelector:@selector(reload)];
    }
}

@end
