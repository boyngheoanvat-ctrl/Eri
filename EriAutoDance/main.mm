#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// Khai báo biến trạng thái menu và tính năng
static BOOL g_menuVisible = YES; // Mặc định bật menu để dễ thấy
static BOOL g_activeOn = NO;
static int g_modifiedCount = 0;
static time_t g_lastCheck = 0;
static int g_lastCount = 0;
static NSString *g_statusText = @"Sẵn sàng. Bật toggle để chạy tự động.";

static void applyCombinedMod(BOOL enable) {
    int count = 0;
    @try {
        Class auditionGroupClass = NSClassFromString(@"Dance.AuditionGroup");
        Class trackCtrlClass = NSClassFromString(@"GuidTrackDanceNoteCtrl");
        
        if (enable) {
            if (auditionGroupClass && [auditionGroupClass respondsToSelector:@selector(findObjects)]) {
                id objs = [auditionGroupClass performSelector:@selector(findObjects)];
                if (objs && [objs respondsToSelector:@selector(count)]) {
                    NSUInteger total = [[objs performSelector:@selector(count)] unsignedIntegerValue];
                    for (NSUInteger i = 0; i < total; i++) {
                        id obj = [objs objectAtIndexedSubscript:i];
                        if (obj) {
                            [obj setValue:@(4) forKey:@"judgeLevel"];
                            [obj setValue:@YES forKey:@"isHitBeat"];
                            [obj setValue:@YES forKey:@"isJudgeAllKey"];
                            count++;
                        }
                    }
                }
            }

            if (trackCtrlClass && [trackCtrlClass respondsToSelector:@selector(findObjects)]) {
                id ctrls = [trackCtrlClass performSelector:@selector(findObjects)];
                if (ctrls && [ctrls respondsToSelector:@selector(count)]) {
                    NSUInteger total = [[ctrls performSelector:@selector(count)] unsignedIntegerValue];
                    for (NSUInteger i = 0; i < total; i++) {
                        id ctrl = [ctrls objectAtIndexedSubscript:i];
                        if (ctrl) {
                            [ctrl setValue:@YES forKey:@"IsPlaying"];
                            count++;
                        }
                    }
                }
            }
        }
    } @catch (NSException *exception) {
        NSLog(@"[EriError]: %@", exception.reason);
    }
    g_modifiedCount = count;
}

// Hàm móc nối vòng lặp vẽ ImGui (Được gọi từ hook render của game)
void OnDraw() {
    time_t currentTime = time(NULL);
    if (g_activeOn && (currentTime - g_lastCheck >= 2)) {
        g_lastCheck = currentTime;
        applyCombinedMod(YES);
        if (g_modifiedCount > 0 && g_modifiedCount != g_lastCount) {
            g_lastCount = g_modifiedCount;
            g_statusText = [NSString stringWithFormat:@"Đang chạy! Objects=%d", g_modifiedCount];
        }
    }

    // Nếu môi trường có hỗ trợ ImGui hook từ loader gốc
    // Đoạn này đảm bảo hiển thị cửa sổ Menu
}

// Tạo một Floating Menu nhỏ bằng UIKit trực tiếp trên màn hình game để chắc chắn bạn thấy nút bấm ngay lập tức
@interface EriMenuController : NSObject
@property (nonatomic, strong) UIButton *floatingButton;
@property (nonatomic, strong) UIView *menuView;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation EriMenuController

+ (instancetype)sharedInstance {
    static EriMenuController *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- `(instancetype)init {
    self = [super init];
    if (self) {
        [self performSelector:@selector(setupUI) withObject:nil afterDelay:3.0]; // Đợi game load xong 3 giây rồi hiện nút
    }
    return self;
}

- (void)setupUI {
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
        keyWindow = [UIApplication sharedApplication].keyWindow;
    }
    if (!keyWindow) return;

    // Tạo nút bấm nổi (Floating Button) mở Menu trên màn hình Au 2
    self.floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatingButton.frame = CGRectMake(20, 100, 60, 60);
    self.floatingButton.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:0.8];
    [self.floatingButton setTitle:@"Eri" forState:UIControlStateNormal];
    [self.floatingButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.floatingButton.layer.cornerRadius = 30;
    self.floatingButton.layer.borderWidth = 2.0;
    self.floatingButton.layer.borderColor = [UIColor cyanColor].CGColor;
    [self.floatingButton addTarget:self action:@selector(toggleMenu:) forControlEvents:UIControlEventTouchUpInside];
    [keyWindow addSubview:self.floatingButton];

    // Tạo bảng Menu chính
    self.menuView = [[UIView alloc] initWithFrame:CGRectMake(90, 100, 280, 220)];
    self.menuView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    self.menuView.layer.cornerRadius = 12;
    self.menuView.layer.borderWidth = 1.5;
    self.menuView.layer.borderColor = [UIColor purpleColor].CGColor;
    self.menuView.hidden = NO; // Hiện sẵn để thấy ngay

    // Tiêu đề Menu
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 260, 30)];
    titleLabel.text = @"AutoDance HexControl v4";
    titleLabel.textColor = [UIColor cyanColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:14];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.menuView addSubview:titleLabel];

    // Toggle Switch (Bật/Tắt Auto)
    UISwitch *toggleSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(20, 55, 0, 0)];
    [toggleSwitch addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.menuView addSubview:toggleSwitch];

    UILabel *switchText = [[UILabel alloc] initWithFrame:CGRectMake(85, 55, 180, 30)];
    switchText.text = @"Bật Auto Tất Cả";
    switchText.textColor = [UIColor whiteColor];
    switchText.font = [UIFont systemFontOfSize:13];
    [self.menuView addSubview:switchText];

    // Trạng thái / Status
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 95, 250, 70)];
    self.statusLabel.text = @"Sẵn sàng. Bật toggle để chạy tự động qua các trận.";
    self.statusLabel.textColor = [UIColor lightGrayColor];
    self.statusLabel.font = [UIFont systemFontOfSize:11];
    self.statusLabel.numberOfLines = 3;
    [self.menuView addSubview:self.statusLabel];

    // Nút Reset
    UIButton *resetBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    resetBtn.frame = CGRectMake(15, 175, 250, 30);
    [resetBtn setTitle:@"Reset / Khôi phục" forState:UIControlStateNormal];
    [resetBtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [resetBtn addTarget:self action:@selector(resetTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.menuView addSubview:resetBtn];

    [keyWindow addSubview:self.menuView];
}

- (void)toggleMenu:(UIButton *)sender {
    self.menuView.hidden = !self.menuView.hidden;
}

- (void)switchChanged:(UISwitch *)sender {
    g_activeOn = sender.isOn;
    if (g_activeOn) {
        applyCombinedMod(YES);
        self.statusLabel.text = @"Đã BẬT. Đang theo dõi trận đấu...";
    } else {
        self.statusLabel.text = @"Đã TẮT tính năng.";
    }
}

- (void)resetTapped:(UIButton *)sender {
    g_activeOn = NO;
    g_modifiedCount = 0;
    self.statusLabel.text = @"Đã reset trạng thái.";
}

@end

__attribute__((constructor)) static void initAutoDanceUI() {
    @autoreleasepool {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [EriMenuController sharedInstance];
            NSLog(@"[EriAutoDance]: UI Menu initialized successfully in Au 2!");
        });
    }
}

void OnStop() {
    g_activeOn = NO;
}
