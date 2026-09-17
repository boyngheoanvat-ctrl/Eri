#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#include <dlfcn.h>

// Substrate framework để hook hàm (tương thích Cydia Substrate / Logos)
extern "C" void MSHookFunction(void *symbol, void *replace, void **result);

// --- Định nghĩa Window và UI ---
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

// --- Trạng thái các Toggle ---
static BOOL autoDanceEnabled = NO;
static BOOL taikoEnabled = NO;
static BOOL fullMiniGameEnabled = NO;

// --- Định nghĩa hàm gốc (Original Function Pointers) ---
static int (*orig_GetJudgeLevel)(void *self, float now, float judge) = NULL;
static bool (*orig_CheckHit)(void *self, int direction, bool isRight) = NULL;

// --- Hàm tính base động của HotFix.dll tránh lỗi ASLR ---
uintptr_t get_hotfix_base() {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, "HotFix.dll")) {
            const struct mach_header_64 *header = (const struct mach_header_64 *)_dyld_get_image_header(i);
            intptr_t slide = _dyld_get_image_vmaddr_slide(i);
            // Tìm slide thực tế cộng với load address
            return (uintptr_t)header + slide; // Hoặc dùng trực tiếp slide tùy cấu trúc image
        }
    }
    // Fallback: nếu không tìm thấy HotFix.dll riêng lẻ, lấy Image 0 (Main binary)
    if (count > 0) {
        return (uintptr_t)_dyld_get_image_header(0) + _dyld_get_image_vmaddr_slide(0);
    }
    return 0;
}

// --- Hàm Hook: DanceTaikoController::GetJudgeLevel (RVA: 0x16AEDEC) ---
int hooked_GetJudgeLevel(void *self, float now, float judge) {
    if (autoDanceEnabled) {
        return 4; // 4 = Perfect (Miss=0, Bad=1, Cool=2, Great=3, Perfect=4)
    }
    return orig_GetJudgeLevel(self, now, judge);
}

// --- Hàm Hook: DanceTaikoController::CheckHit (RVA: 0x16D30B0) ---
bool hooked_CheckHit(void *self, int direction, bool isRight) {
    if (taikoEnabled) {
        return true; // Ép luôn luôn chuẩn xác
    }
    return orig_CheckHit(self, direction, isRight);
}

// --- Quản lý sự kiện nút nổi ---
@interface FloatButtonHandler : NSObject
+ (instancetype)sharedInstance;
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

// --- Giao diện Menu Controller ---
@interface ModMenuController : UIViewController
@end

@implementation ModMenuController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 15, 260, 30)];
    titleLabel.text = @"✨ HexControl v7.2 (Active) ✨";
    titleLabel.textColor = [UIColor cyanColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:14];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:titleLabel];
    
    // Toggle 1: Auto Dance / Perfect
    UISwitch *switch1 = [[UISwitch alloc] initWithFrame:CGRectMake(20, 65, 0, 0)];
    switch1.on = autoDanceEnabled;
    [switch1 addTarget:self action:@selector(toggleAutoDance:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:switch1];
    
    UILabel *label1 = [[UILabel alloc] initWithFrame:CGRectMake(80, 65, 200, 30)];
    label1.text = @"Auto Arrow / Perfect";
    label1.textColor = [UIColor whiteColor];
    label1.font = [UIFont systemFontOfSize:13];
    [self.view addSubview:label1];
    
    // Toggle 2: Taiko Mode
    UISwitch *switch2 = [[UISwitch alloc] initWithFrame:CGRectMake(20, 115, 0, 0)];
    switch2.on = taikoEnabled;
    [switch2 addTarget:self action:@selector(toggleTaiko:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:switch2];
    
    UILabel *label2 = [[UILabel alloc] initWithFrame:CGRectMake(80, 115, 200, 30)];
    label2.text = @"Taiko Mode CheckHit";
    label2.textColor = [UIColor whiteColor];
    label2.font = [UIFont systemFontOfSize:13];
    [self.view addSubview:label2];

    // Toggle 3: Full Mini Game
    UISwitch *switch3 = [[UISwitch alloc] initWithFrame:CGRectMake(20, 165, 0, 0)];
    switch3.on = fullMiniGameEnabled;
    [switch3 addTarget:self action:@selector(toggleMiniGame:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:switch3];
    
    UILabel *label3 = [[UILabel alloc] initWithFrame:CGRectMake(80, 165, 200, 30)];
    label3.text = @"Full Mini Game Fix";
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

- (void)toggleAutoDance:(UISwitch *)sender {
    autoDanceEnabled = sender.isOn;
    NSLog(@"[HexControl] AutoDance -> %@", autoDanceEnabled ? @"ON" : @"OFF");
}

- (void)toggleTaiko:(UISwitch *)sender {
    taikoEnabled = sender.isOn;
    NSLog(@"[HexControl] Taiko -> %@", taikoEnabled ? @"ON" : @"OFF");
}

- (void)toggleMiniGame:(UISwitch *)sender {
    fullMiniGameEnabled = sender.isOn;
    NSLog(@"[HexControl] MiniGame -> %@", fullMiniGameEnabled ? @"ON" : @"OFF");
}

- (void)closeMenu {
    [UIView animateWithDuration:0.25 animations:^{
        menuView.alpha = 0.0;
    } completion:^(BOOL finished) {
        menuView.hidden = YES;
        isMenuOpen = NO;
    }];
}
@end

// --- Khởi chạy Dylib & Thiết lập Hook thông minh ---
__attribute__((constructor)) static void entryPoint() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        @autoreleasepool {
            UIWindowScene *windowScene = nil;
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    windowScene = (UIWindowScene *)scene;
                    break;
                }
            }
            if (!windowScene) return;
            
            // 1. Dựng UI nổi không chặn cảm ứng game
            modWindow = [[PassthroughWindow alloc] initWithWindowScene:windowScene];
            modWindow.frame = windowScene.coordinateSpace.bounds;
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
            
            [floatingBtn addTarget:[FloatButtonHandler sharedInstance] action:@selector(onFloatingButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
            [rootVC.view.addSubview:floatingBtn];
            
            CGRect screenBounds = windowScene.coordinateSpace.bounds;
            menuView = [[UIView alloc] initWithFrame:CGRectMake((screenBounds.size.width - 300)/2, (screenBounds.size.height - 270)/2, 300, 270)];
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

            // 2. Thiết lập MSHookFunction dựa trên RVA và Base động (Chống ASLR)
            uintptr_t base = get_hotfix_base();
            if (base != 0) {
                NSLog(@"[HexControl] Resolved HotFix base address: 0x%lx", (unsigned long)base);
                
                // Hook GetJudgeLevel (RVA: 0x16AEDEC)
                void *addrGetJudge = (void *)(base + 0x16AEDEC);
                MSHookFunction(addrGetJudge, (void *)hooked_GetJudgeLevel, (void **)&orig_GetJudgeLevel);
                
                // Hook CheckHit (RVA: 0x16D30B0)
                void *addrCheckHit = (void *)(base + 0x16D30B0);
                MSHookFunction(addrCheckHit, (void *)hooked_CheckCheckHit_placeholder_fix ? : (void *)hooked_CheckHit, (void **)&orig_CheckHit);
                
                NSLog(@"[HexControl] MSHookFunction applied successfully via RVA offsets!");
            } else {
                NSLog(@"[HexControl] Error: Could not resolve base address!");
            }
        }
    });
}
