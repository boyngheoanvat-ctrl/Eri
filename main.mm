#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// Khai báo biến giao diện toàn cục
static UIWindow *modWindow = nil;
static UIButton *floatingBtn = nil;
static UIView *menuView = nil;
static BOOL isMenuOpen = NO;

// Các trạng thái tính năng mod
static BOOL autoDanceEnabled = NO;
static BOOL taikoEnabled = NO;
static BOOL fullMiniGameEnabled = NO;

@interface ModMenuController : UIViewController
@end

@implementation ModMenuController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.75];
    
    // Tiêu đề Menu
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, 260, 30)];
    titleLabel.text = @"✨ AutoDance HexControl v7.2 ✨";
    titleLabel.textColor = [UIColor cyanColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:14];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:titleLabel];
    
    // Toggle 1: Auto Dance
    UISwitch *switch1 = [[UISwitch alloc] initWithFrame:CGRectMake(20, 70, 0, 0)];
    switch1.on = autoDanceEnabled;
    [switch1 addTarget:self action:@selector(toggleAutoDance:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:switch1];
    
    UILabel *label1 = [[UILabel alloc] initWithFrame:CGRectMake(80, 70, 200, 30)];
    label1.text = @"Auto Arrow / Perfect";
    label1.textColor = [UIColor whiteColor];
    label1.font = [UIFont systemFontOfSize:13];
    [self.view addSubview:label1];
    
    // Toggle 2: Taiko Mode
    UISwitch *switch2 = [[UISwitch alloc] initWithFrame:CGRectMake(20, 120, 0, 0)];
    switch2.on = taikoEnabled;
    [switch2 addTarget:self action:@selector(toggleTaiko:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:switch2];
    
    UILabel *label2 = [[UILabel alloc] initWithFrame:CGRectMake(80, 120, 200, 30)];
    label2.text = @"Taiko Mode";
    label2.textColor = [UIColor whiteColor];
    label2.font = [UIFont systemFontOfSize:13];
    [self.view addSubview:label2];

    // Toggle 3: Full Mini Game
    UISwitch *switch3 = [[UISwitch alloc] initWithFrame:CGRectMake(20, 170, 0, 0)];
    switch3.on = fullMiniGameEnabled;
    [switch3 addTarget:self action:@selector(toggleMiniGame:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:switch3];
    
    UILabel *label3 = [[UILabel alloc] initWithFrame:CGRectMake(80, 170, 200, 30)];
    label3.text = @"Full Mini Game (Crazy Fix)";
    label3.textColor = [UIColor whiteColor];
    label3.font = [UIFont systemFontOfSize:13];
    [self.view addSubview:label3];
    
    // Nút Đóng Menu
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(90, 230, 120, 35);
    [closeBtn setTitle:@"Đóng Menu" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeBtn.backgroundColor = [UIColor darkGrayColor];
    closeBtn.layer.cornerRadius = 8;
    [closeBtn addTarget:self action:@selector(closeMenu) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:closeBtn];
}

- (void)toggleAutoDance:(UISwitch *)sender {
    autoDanceEnabled = sender.isOn;
    NSLog(@"[HexControl] AutoDance: %@", autoDanceEnabled ? @"ON" : @"OFF");
}

- (void)toggleTaiko:(UISwitch *)sender {
    taikoEnabled = sender.isOn;
    NSLog(@"[HexControl] Taiko: %@", taikoEnabled ? @"ON" : @"OFF");
}

- (void)toggleMiniGame:(UISwitch *)sender {
    fullMiniGameEnabled = sender.isOn;
    NSLog(@"[HexControl] MiniGame: %@", fullMiniGameEnabled ? @"ON" : @"OFF");
}

- (void)closeMenu {
    [UIView animateWithDuration:0.3 animations:^{
        menuView.alpha = 0.0;
    } completion:^(BOOL finished) {
        menuView.hidden = YES;
        isMenuOpen = NO;
    }];
}

@end

// Hàm xử lý khi bấm vào nút nổi trên màn hình
static void onFloatingButtonClicked(UIButton *sender) {
    isMenuOpen = !isMenuOpen;
    if (isMenuOpen) {
        menuView.hidden = NO;
        menuView.alpha = 0.0;
        [UIView animateWithDuration:0.3 animations:^{
            menuView.alpha = 1.0;
        }];
    } else {
        menuView.hidden = YES;
    }
}

// Khởi tạo giao diện khi dylib được load vào ứng dụng
__attribute__((constructor)) static void entryPoint() {
    @autoreleasepool {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // Tạo UIWindow nằm đè lên trên game
            UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
            modWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
            modWindow.windowLevel = UIWindowLevelAlert + 1000;
            modWindow.hidden = NO;
            modWindow.backgroundColor = [UIColor clearColor];
            
            UIViewController *rootVC = [[UIViewController alloc] init];
            rootVC.view.backgroundColor = [UIColor clearColor];
            modWindow.rootViewController = rootVC;
            
            // 1. Tạo Nút Nổi (Floating Button) có chữ "Eri" hoặc icon tùy ý
            floatingBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            floatingBtn.frame = CGRectMake(30, 100, 50, 50);
            [floatingBtn setTitle:@"Eri" forState:UIControlStateNormal];
            [floatingBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            floatingBtn.backgroundColor = [UIColor systemIndigoColor];
            floatingBtn.layer.cornerRadius = 25;
            floatingBtn.layer.borderWidth = 2.0;
            floatingBtn.layer.borderColor = [UIColor cyanColor].CGColor;
            [floatingBtn addTarget:nil action:@selector(onFloatingButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
            
            // Cho phép kéo thả nút nổi (tùy chọn đơn giản)
            [rootVC.view addSubview:floatingBtn];
            
            // 2. Tạo Khung Menu chính (Ẩn ban đầu)
            CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
            CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
            menuView = [[UIView alloc] initWithFrame:CGRectMake((screenWidth - 300)/2, (screenHeight - 280)/2, 300, 280)];
            menuView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.9];
            menuView.layer.cornerRadius = 12;
            menuView.layer.borderWidth = 1.5;
            menuView.layer.borderColor = [UIColor systemIndigoColor].CGColor;
            menuView.hidden = YES;
            
            ModMenuController *menuVC = [[ModMenuController alloc] init];
            menuVC.view.frame = menuView.bounds;
            [menuView addSubview:menuVC.view];
            
            [rootVC.view addSubview:menuView];
            
            NSLog(@"[EriOS] Mod Menu UI initialized successfully!");
        });
    }
}
