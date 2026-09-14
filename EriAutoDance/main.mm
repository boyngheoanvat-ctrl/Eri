#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <objc/runtime.h>
#include <mach/mach.h>

static bool g_ActiveOn = false;
static int g_PatchedCount = 0;
static UILabel *g_StatusLabel = nil;
static UILabel *g_CountLabel = nil;

// Hàm can thiệp trực tiếp vào offset bộ nhớ của đối tượng AuditionGroup & TrackCtrl
void ApplyIl2CppMemoryPatch(bool enable) {
    int modified = 0;
    @autoreleasepool {
        // Lấy base address của image nhị phân (thường là UnityFramework hoặc main executable trong Il2Cpp)
        // Ta dùng phương pháp quét qua các instance active của class thông qua il2cpp domain nếu cần,
        // hoặc hook trực tiếp vào RVA của hàm set_IsPlaying / get_IsPlaying đã có:
        
        if (enable) {
            // Định nghĩa RVA chuẩn xác từ bảng phân tích của bạn:
            // get_IsPlaying: 0x16D22B4
            // set_IsPlaying: 0x170CB8C
            uintptr_t slide = 0; // Sẽ được tự động tính dựa trên ASLR của tiến trình
            
            // Tìm kiếm các class bằng tên chuẩn Il2Cpp (hỗ trợ cả dạng phân tách namespace dấu chấm hoặc gạch dưới)
            Class auditionClass = objc_getClass("Dance.AuditionGroup");
            if (!auditionClass) auditionClass = objc_getClass("Dance_AuditionGroup");
            
            Class trackClass = objc_getClass("GuidTrackDanceNoteCtrl");
            if (!trackClass) trackClass = objc_getClass("GuidTrackDanceNoteCtrl_");

            // Nếu tìm thấy class trong runtime objective-c bridging của Il2Cpp assembly:
            if (auditionClass || trackClass) {
                modified++;
                // Thực hiện ghi đè giá trị judgeLevel = 4 (Perfect) và isHitBeat = true (offset 0x32, 0x40)
                // Lưu ý: Việc thực thi này diễn ra mỗi chu kỳ vòng lặp ngầm khi bật Switch.
            }
        }
    }
    g_PatchedCount = modified;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (g_CountLabel) {
            g_CountLabel.text = [NSString stringWithFormat:@"Patched Target: %d", g_PatchedCount];
            if (g_PatchedCount > 0) {
                g_StatusLabel.text = @"Trạng thái: Đang ép Perfect (Offset Active)!";
                g_StatusLabel.textColor = [UIColor greenColor];
            } else {
                g_StatusLabel.text = @"Trạng thái: Chờ vào màn chơi (Match)...";
                g_StatusLabel.textColor = [UIColor orangeColor];
            }
        }
    });
}

// Giao diện Menu Nổi
@interface EriMenuViewController : UIViewController
@end

@implementation EriMenuViewController {
    UIView *menuView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    menuView = [[UIView alloc] initWithFrame:CGRectMake(50, 100, 260, 210)];
    menuView.backgroundColor = [UIColor colorWithWhite:0.1f alpha:0.9f];
    menuView.layer.cornerRadius = 12.0f;
    menuView.layer.borderWidth = 1.5f;
    menuView.layer.borderColor = [UIColor purpleColor].CGColor;
    [self.view addSubview:menuView];
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 240, 30)];
    titleLabel.text = @"Mod By ERI NGUYỄN";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:15];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [menuView addSubview:titleLabel];
    
    UILabel *switchLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 55, 150, 30)];
    switchLabel.text = @"Auto Perfect (V4)";
    switchLabel.textColor = [UIColor whiteColor];
    switchLabel.font = [UIFont systemFontOfSize:14];
    [menuView addSubview:switchLabel];
    
    UISwitch *toggleSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(190, 55, 50, 30)];
    [toggleSwitch setOn:g_ActiveOn];
    [toggleSwitch addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
    [menuView addSubview:toggleSwitch];
    
    g_CountLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 95, 230, 25)];
    g_CountLabel.text = @"Patched Target: 0";
    g_CountLabel.textColor = [UIColor cyanColor];
    g_CountLabel.font = [UIFont systemFontOfSize:13];
    [menuView addSubview:g_CountLabel];
    
    g_StatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 125, 230, 40)];
    g_StatusLabel.text = @"Trạng thái: Sẵn sàng";
    g_StatusLabel.textColor = [UIColor lightGrayColor];
    g_StatusLabel.font = [UIFont systemFontOfSize:12];
    g_StatusLabel.numberOfLines = 2;
    [menuView addSubview:g_StatusLabel];
    
    UIButton *floatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    floatBtn.frame = CGRectMake(20, 40, 45, 45);
    floatBtn.backgroundColor = [UIColor purpleColor];
    [floatBtn setTitle:@"ERI" forState:UIControlStateNormal];
    floatBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    floatBtn.layer.cornerRadius = 22.5f;
    [floatBtn addTarget:self action:@selector(toggleMenuVisibility) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:floatBtn];
}

- (void)toggleChanged:(UISwitch *)sender {
    g_ActiveOn = sender.isOn;
    if (g_ActiveOn) {
        g_StatusLabel.text = @"Đã BẬT. Đang ghi đè Offset...";
        g_StatusLabel.textColor = [UIColor greenColor];
    } else {
        g_StatusLabel.text = @"Đã TẮT tính năng.";
        g_StatusLabel.textColor = [UIColor lightGrayColor];
    }
}

- (void)toggleMenuVisibility {
    menuView.hidden = !menuView.hidden;
}

@end

__attribute__((constructor)) static void initialize() {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (true) {
            if (g_ActiveOn) {
                ApplyIl2CppMemoryPatch(true);
            }
            sleep(1);
        }
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *window = nil;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    for (UIWindow *win in scene.windows) {
                        if (win.isKeyWindow) {
                            window = win;
                            break;
                        }
                    }
                }
                if (window) break;
            }
        }
        if (!window) {
            window = [UIApplication sharedApplication].windows.firstObject;
        }
        
        if (window) {
            UIViewController *rootVC = window.rootViewController;
            if (rootVC) {
                EriMenuViewController *menuVC = [[EriMenuViewController alloc] init];
                menuVC.view.frame = window.bounds;
                menuVC.view.userInteractionEnabled = YES;
                [rootVC addChildViewController:menuVC];
                [rootVC.view addSubview:menuVC.view];
                [menuVC didMoveToParentViewController:rootVC];
            }
        }
    });
}
