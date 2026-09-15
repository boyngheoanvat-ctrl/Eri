#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <pthread.h>
#include <vector>
#include <atomic>

// --- Cấu hình Offset và State ---
static const uint32_t OFF_JUDGE_LEVEL = 0x40;   // int32
static const uint32_t OFF_IS_HIT_BEAT  = 0x32;  // bool
static const uint32_t OFF_IS_PLAY      = 0x198; // bool
static const int32_t  PERFECT          = 4;     

static std::atomic<bool> g_isHackActive{false};
static int g_modifiedObjectsCount = 0;

// --- Giao diện Menu Nổi (UI Controller) ---
@interface EriMenuController : NSObject
@property (nonatomic, strong) UIButton *floatingButton;
@property (nonatomic, strong) UIView *menuView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UISwitch *toggleSwitch;
@end

@implementation EriMenuController

+ (instancetype)sharedInstance {
    static EriMenuController *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[EriMenuController alloc] initPrivate];
    });
    return sharedInstance;
}

-(instancetype)initPrivate {
    self = [super init];
    if (self) {
        [self performSelector:@selector(setupUI) withObject:nil afterDelay:4.0];
    }
    return self;
}

-(void)setupUI {
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                for (UIWindow *window in scene.windows) {
                    if (window.isKeyWindow) {
                        keyWindow = window;
                        break;
                    }
                }
            }
        }
    }
    if (!keyWindow) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        keyWindow = [UIApplication sharedApplication].keyWindow;
#pragma clang diagnostic pop
    }
    if (!keyWindow) return;

    // Nút tròn nổi trên màn hình (Floating Button)
    self.floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatingButton.frame = CGRectMake(30, 120, 55, 55);
    self.floatingButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.6 blue:0.9 alpha:0.9];
    [self.floatingButton setTitle:@"Eri" forState:UIControlStateNormal];
    [self.floatingButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.floatingButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    self.floatingButton.layer.cornerRadius = 27.5;
    self.floatingButton.layer.borderWidth = 2.0;
    self.floatingButton.layer.borderColor = [UIColor whiteColor].CGColor;
    [self.floatingButton addTarget:self action:@selector(toggleMenuVisibility:) forControlEvents:UIControlEventTouchUpInside];
    [keyWindow addSubview:self.floatingButton];

    // Khung Menu chính
    self.menuView = [[UIView alloc] initWithFrame:CGRectMake(95, 120, 260, 200)];
    self.menuView.backgroundColor = [UIColor colorWithWhite:0.12 alpha:0.95];
    self.menuView.layer.cornerRadius = 14;
    self.menuView.layer.borderWidth = 1.5;
    self.menuView.layer.borderColor = [UIColor cyanColor].CGColor;
    self.menuView.hidden = YES; // Mặc định ẩn, bấm nút Eri để mở

    // Tiêu đề Menu
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 240, 25)];
    titleLabel.text = @"Eri AutoDance Menu v4.2";
    titleLabel.textColor = [UIColor cyanColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:14];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.menuView addSubview:titleLabel];

    // Công tắc Bật/Tắt Hack (Switch)
    self.toggleSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(20, 48, 0, 0)];
    [self.toggleSwitch addTarget:self action:@selector(onSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.menuView addSubview:self.toggleSwitch];

    UILabel *switchText = [[UILabel alloc] initWithFrame:CGRectMake(85, 45, 160, 30)];
    switchText.text = @"Bật Auto Perfect";
    switchText.textColor = [UIColor whiteColor];
    switchText.font = [UIFont systemFontOfSize:13];
    [self.menuView addSubview:switchText];

    // Nhãn hiển thị trạng thái / số lượng object đang bắt
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 85, 230, 95)];
    self.statusLabel.text = @"Trạng thái: Đang Tắt\n- Chưa kích hoạt trong trận.\n- Bấm công tắc để bắt đầu chạy.";
    self.statusLabel.textColor = [UIColor lightGrayColor];
    self.statusLabel.font = [UIFont systemFontOfSize:11];
    self.statusLabel.numberOfLines = 4;
    [self.menuView addSubview:self.statusLabel];

    [keyWindow addSubview:self.menuView];
}

-(void)toggleMenuVisibility:(UIButton *)sender {
    self.menuView.hidden = !self.menuView.hidden;
}

-(void)onSwitchChanged:(UISwitch *)sender {
    g_isHackActive = sender.isOn;
    if (sender.isOn) {
        self.statusLabel.text = [NSString stringWithFormat:@"Trạng thái: ĐÃ BẬT 🟢\n- Đang quét và ép giá trị...\n- Đã tác động: %d objects", g_modifiedObjectsCount];
    } else {
        self.statusLabel.text = @"Trạng thái: ĐÃ TẮT 🔴\n- Đã dừng can thiệp.";
    }
}

-(void)updateStatusTextCount:(int)count {
    if (g_isHackActive) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.statusLabel.text = [NSString stringWithFormat:@"Trạng thái: ĐÃ BẬT 🟢\n- Đang chạy mượt.\n- Đã tác động: %d objects", count];
        });
    }
}

@end

// --- Vòng lặp chạy ngầm thực thi logic hack định kỳ ---
void* HackLoopThread(void* arg) {
    while (true) {
        if (g_isHackActive.load()) {
            int currentModified = 0;
            @try {
                // Thêm logic quét và ép giá trị trực tiếp tại đây tương tự code C++ IL2CPP
                // Ví dụ quét và thay đổi offset bộ nhớ của object đang active trong game:
                // ...
                g_modifiedObjectsCount = currentModified;
                
                // Cập nhật lên UI nếu cần
                [[EriMenuController sharedInstance] performSelectorOnMainThread:@selector(updateStatusTextCount:) withObject:@(currentModified) waitUntilDone:NO];
            } @catch (NSException *exception) {
                NSLog(@"[EriError]: %@", exception.reason);
            }
        }
        usleep(1500000); // Nghỉ 1.5 giây mỗi vòng quét để tối ưu CPU không bị giật lag game
    }
    return NULL;
}

// --- Khởi chạy khi dylib được inject thành công vào game ---
__attribute__((constructor)) static void initEriDylib() {
    @autoreleasepool {
        // Khởi tạo Menu UI
        [EriMenuController sharedInstance];
        
        // Tạo một luồng riêng chạy ngầm xử lý hack
        pthread_t t;
        pthread_create(&t, NULL, HackLoopThread, NULL);
        
        NSLog(@"[EriAutoDance]: Dylib successfully loaded with Floating Menu!");
    }
}
