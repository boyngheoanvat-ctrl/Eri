#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface PassthroughWindow : UIWindow
@end

@implementation PassthroughWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    if (hitView == self.rootViewController.view) {
        return nil;
    }
    return hitView;
}
@end

static PassthroughWindow *modWindow = nil;
static UIButton *floatingBtn = nil;
static UIView *menuView = nil;
static BOOL isMenuOpen = NO;

static BOOL autoDanceEnabled = NO;
static BOOL taikoEnabled = NO;
static BOOL fullMiniGameEnabled = NO;

// Khai báo một Helper class để nhận sự kiện click nút nổi chuẩn xác
@interface FloatButtonHandler : NSObject
+ (inst5ancetype)sharedInstance;
- (void)onFloatingButtonClicked:(UIButton *)sender;
@end

@implementation FloatButtonHandler
+ (instancetype)sharedInstance {
    static FloatButtonHandler *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[FloatButtonHandler alloc] init];
    });
    return instance;
}

- (void)onFloatingButtonClicked:(UIButton *)sender {
    isMenuOpen = !isMenuOpen;
    if (isMenuOpen) {
        menuView.hidden = NO;
        menuView.alpha = 0.0;
        [UIView animateWithDuration:0.25 animations:^{
            menuView.alpha = 1.0;
        }];
    } else {
        [UIView animateWithDuration:0.25 animations:^{
            menuView.alpha = 0.0;
        } completion:^(BOOL finished) {
            menuView.hidden = YES;
        }];
    }
}
@end

@interface ModMenuController : UIViewController
@end

@implementation ModMenuController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 15, 260, 30)];
    titleLabel.text = @"✨ HexControl v7.2 (Fixed) ✨";
    titleLabel.textColor = [UIColor cyanColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:14];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:titleLabel];
    
    UISwitch *switch1 = [[UISwitch alloc] initWithFrame:CGRectMake(20, 65, 0, 0)];
    switch1.on = autoDanceEnabled;
    [switch1 addTarget:self action:@selector(toggleAutoDance:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:switch1];
    
    UILabel *label1 = [[UILabel alloc] initWithFrame:CGRectMake(80, 65, 200, 30)];
    label1.text = @"Auto Arrow / Perfect";
    label1.textColor = [UIColor whiteColor];
    label1.font = [UIFont systemFontOfSize:13];
    [self.view addSubview:label1];
    
    UISwitch *switch2 = [[UISwitch alloc] initWithFrame:CGRectMake(20, 115, 0, 0)];
    switch2.on = taikoEnabled;
    [switch2 addTarget:self action:@selector(toggleTaiko:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:switch2];
    
    UILabel *label2 = [[UILabel alloc] initWithFrame:CGRectMake(80, 115, 200, 30)];
    label2.text = @"Taiko Mode";
    label2.textColor = [UIColor whiteColor];
    label2.font = [UIFont systemFontOfSize:13];
    [self.view addSubview:label2];

    UISwitch *switch3 = [[UISwitch alloc] initWithFrame:CGRectMake(20, 165, 0, 0)];
    switch3.on = fullMiniGameEnabled;
    [switch3 addTarget:self action:@selector(toggleMiniGame:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:switch3];
    
    UILabel *label3 = [[UILabel alloc] initWithFrame:CGRectMake(80, 165, 200, 30)];
    label3.text = @"Full Mini Game (Crazy Fix)";
    label3.textColor = [UIColor whiteColor];
    label3.font = [UIFont systemFontOfSize:13];
    [self.view addSubview:label3];
    
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(90, 220, 120, 35);
    [closeBtn setTitle:@"Đóng Menu" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeBtn.backgroundColor = [UIColor darkGrayColor];
    closeBtn.layer.cornerRadius = 8;
    [closeBtn addTarget:self action:@selector(closeMenu) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:closeBtn];
}

- (void)toggleAutoDance:(UISwitch *)sender { autoDanceEnabled = sender.isOn; }
- (void)toggleTaiko:(UISwitch *)sender { taikoEnabled = sender.isOn; }
- (void)toggleMiniGame:(UISwitch *)sender { fullMiniGameEnabled = sender.isOn; }

- (void)closeMenu {
    [UIView animateWithDuration:0.25 animations:^{
        menuView.alpha = 0.0;
    } completion:^(BOOL finished) {
        menuView.hidden = YES;
        isMenuOpen = NO;
    }];
}
@end

__attribute__((constructor)) static void entryPoint() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        @autoreleasepool {
            UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
            if (!keyWindow) return;
            
            modWindow = [[PassthroughWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
            modWindow.windowLevel = UIWindowLevelAlert + 1000;
            modWindow.hidden = NO;
            modWindow.backgroundColor = [UIColor clearColor];
            
            UIViewController *rootVC = [[UIViewController alloc] init];
            rootVC.view.backgroundColor = [UIColor clearColor];
            modWindow.rootViewController = rootVC;
            
            floatingBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            floatingBtn.frame = CGRectMake(30, 120, 48, 48);
            [floatingBtn setTitle:@"Eri" forState:UIControlStateNormal];
            [floatingBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            floatingBtn.backgroundColor = [UIColor systemIndigoColor];
            floatingBtn.layer.cornerRadius = 24;
            floatingBtn.layer.borderWidth = 2.0;
            floatingBtn.layer.borderColor = [UIColor cyanColor].CGColor;
            
            // Trỏ target chính xác vào FloatButtonHandler để nhận sự kiện bấm
            [floatingBtn addTarget:[FloatButtonHandler sharedInstance] action:@selector(onFloatingButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
            [rootVC.view addSubview:floatingBtn];
            
            CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
            CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
            menuView = [[UIView alloc] initWithFrame:CGRectMake((screenWidth - 300)/2, (screenHeight - 270)/2, 300, 270)];
            menuView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.9];
            menuView.layer.cornerRadius = 14;
            menuView.layer.borderWidth = 1.5;
            menuView.layer.borderColor = [UIColor systemIndigoColor].CGColor;
            menuView.hidden = YES;
            menuView.alpha = 0.0;
            
            ModMenuController *menuVC = [[ModMenuController alloc] init];
            menuVC.view.frame = menuView.bounds;
            [menuView addSubview:menuVC.view];
            [rootVC.view addSubview:menuView];
            
            NSLog(@"[EriOS] Floating button target fixed!");
        }
    });
}
