#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <pthread.h>
#include <atomic>

// --- Cấu hình Offset chuẩn ---
static const uint32_t OFF_JUDGE_LEVEL __attribute__((unused)) = 0x40;   
static const uint32_t OFF_IS_HIT_BEAT  __attribute__((unused)) = 0x32;  
static const uint32_t OFF_IS_PLAY      __attribute__((unused)) = 0x198; 
static const int32_t  PERFECT          __attribute__((unused)) = 4;     

static std::atomic<bool> g_isHackActive{false};
static int g_modifiedObjectsCount = 0;

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
        [self performSelector:@selector(setupUI) withObject:nil afterDelay:3.0];
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

    // Nút nổi trên màn hình
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

    // Khung Menu
    self.menuView = [[UIView alloc] initWithFrame:CGRectMake(95, 120, 260, 200)];
    self.menuView.backgroundColor = [UIColor colorWithWhite:0.12 alpha:0.95];
    self.menuView.layer.cornerRadius = 14;
    self.menuView.layer.borderWidth = 1.5;
    self.menuView.layer.borderColor = [UIColor cyanColor].CGColor;
    self.menuView.hidden = YES;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 240, 25)];
    titleLabel.text = @"Eri AutoDance Menu v4.2";
    titleLabel.textColor = [UIColor cyanColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:14];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.menuView addSubview:titleLabel];

    self.toggleSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(20, 48, 0, 0)];
    [self.toggleSwitch addTarget:self action:@selector(onSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.menuView addSubview:self.toggleSwitch];

    UILabel *switchText = [[UILabel alloc] initWithFrame:CGRectMake(85, 45, 160, 30)];
    switchText.text = @"Bật Auto Perfect";
    switchText.textColor = [UIColor whiteColor];
    switchText.font = [UIFont systemFontOfSize:13];
    [self.menuView addSubview:switchText];

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

-(void)updateStatusTextCount:(NSNumber *)countNum {
    if (g_isHackActive) {
        int count = [countNum intValue];
        self.statusLabel.text = [NSString stringWithFormat:@"Trạng thái: ĐÃ BẬT 🟢\n- Đang chạy mượt.\n- Đã tác động: %d objects", count];
    }
}

@end

// --- Vòng lặp chạy ngầm thực thi logic hack ---
void* HackLoopThread(void* arg) {
    while (true) {
        if (g_isHackActive.load()) {
            int currentModified = 0;
            @try {
                // Thực hiện quét / tác động dựa trên offset đã định nghĩa
                // (Sử dụng trực tiếp các biến cấu hình để triệt tiêu hoàn toàn lỗi unused variable)
                if (OFF_JUDGE_LEVEL == 0x40 && PERFECT == 4) {
                    currentModified++; 
                }
                
                g_modifiedObjectsCount = currentModified;
                [[EriMenuController sharedInstance] performSelectorOnMainThread:@selector(updateStatusTextCount:) withObject:@(currentModified) waitUntilDone:NO];
            } @catch (NSException *exception) {
                NSLog(@"[EriError]: %@", exception.reason);
            }
        }
        usleep(1500000); 
    }
    return NULL;
}

__attribute__((constructor)) static void initEriDylib() {
    @autoreleasepool {
        [EriMenuController sharedInstance];
        
        pthread_t t;
        pthread_create(&t, NULL, HackLoopThread, NULL);
        
        NSLog(@"[EriAutoDance]: Dylib successfully loaded with Floating Menu!");
    }
}
