#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <pthread.h>
#include <atomic>
#include <vector>

// --- Định nghĩa cấu trúc IL2CPP tối thiểu để quét heap ---
struct Il2CppObject;
struct Il2CppClass;

typedef struct Il2CppDomain {
    void* domain;
    void* setup;
} Il2CppDomain;

typedef struct Il2CppImage {
    const char* name;
    const char* nameWithoutExtension;
    void* assembly;
} Il2CppImage;

// Khai báo hàm API từ runtime IL2CPP của game
extern "C" {
    Il2CppDomain* il2cpp_domain_get(void);
    size_t il2cpp_domain_get_assemblies(const Il2CppDomain* domain, size_t* size);
    Il2CppClass* il2cpp_class_from_name(const Il2CppImage* image, const char* namespaze, const char* name);
    void il2cpp_gc_foreach_heap_object(void(*callback)(Il2CppObject*, void*), void* user_data);
}

// --- Cấu hình Offset chuẩn ---
static const uint32_t OFF_JUDGE_LEVEL = 0x40;   // int32
static const uint32_t OFF_IS_HIT_BEAT  = 0x32;  // bool
static const uint32_t OFF_IS_PLAY      = 0x198; // bool
static const int32_t  PERFECT          = 4;     

static std::atomic<bool> g_isHackActive{false};
static int g_modifiedObjectsCount = 0;

// Lưu trữ danh sách object tìm thấy để ép giá trị liên tục mỗi vòng lặp
static std::vector<void*> g_cachedAuditionGroups;
static std::vector<void*> g_cachedTrackCtrls;

// Callback quét heap bộ nhớ tìm instance của class
static Il2CppClass* g_targetAuditionClass = nullptr;
static Il2CppClass* g_targetTrackCtrlClass = nullptr;

static void HeapObjectCallback(Il2CppObject* obj, void* user_data) {
    if (!obj) return;
    Il2CppClass* klass = *(Il2CppClass**)(obj);
    if (klass == g_targetAuditionClass) {
        g_cachedAuditionGroups.push_back((void*)obj);
    } else if (klass == g_targetTrackCtrlClass) {
        g_cachedTrackCtrls.push_back((void*)obj);
    }
}

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

// --- Vòng lặp chạy ngầm thực thi logic hack trực tiếp vào bộ nhớ ---
void* HackLoopThread(void* arg) {
    while (true) {
        if (g_isHackActive.load()) {
            int currentModified = 0;
            @try {
                Il2CppDomain* domain = il2cpp_domain_get();
                if (domain) {
                    size_t assemblyCount = 0;
                    Il2CppImage** assemblies = (Il2CppImage**)il2cpp_domain_get_assemblies(domain, &assemblyCount);
                    
                    // Tìm class nếu chưa tìm được
                    if (!g_targetAuditionClass || !g_targetTrackCtrlClass) {
                        for (size_t i = 0; i < assemblyCount; i++) {
                            if (!g_targetAuditionClass) {
                                g_targetAuditionClass = il2cpp_class_from_name(assemblies[i], "Dance", "AuditionGroup");
                            }
                            if (!g_targetTrackCtrlClass) {
                                g_targetTrackCtrlClass = il2cpp_class_from_name(assemblies[i], "", "GuidTrackDanceNoteCtrl");
                            }
                        }
                    }

                    // Nếu tìm thấy class, tiến hành quét heap và ghi đè offset
                    if (g_targetAuditionClass || g_targetTrackCtrlClass) {
                        g_cachedAuditionGroups.clear();
                        g_cachedTrackCtrls.clear();
                        
                        if (il2cpp_gc_foreach_heap_object) {
                            il2cpp_gc_foreach_heap_object(HeapObjectCallback, nullptr);
                        }

                        // Ghi đè AuditionGroup (JudgeLevel = PERFECT (4), IsHitBeat = true)
                        for (void* obj : g_cachedAuditionGroups) {
                            if (obj) {
                                *(int32_t*)((uint8_t*)obj + OFF_JUDGE_LEVEL) = PERFECT;
                                *(bool*)((uint8_t*)obj + OFF_IS_HIT_BEAT) = true;
                                currentModified++;
                            }
                        }

                        // Ghi đè TrackCtrl (IsPlaying = true)
                        for (void* obj : g_cachedTrackCtrls) {
                            if (obj) {
                                *(bool*)((uint8_t*)obj + OFF_IS_PLAY) = true;
                                currentModified++;
                            }
                        }
                    }
                }
                
                g_modifiedObjectsCount = currentModified;
                [[EriMenuController sharedInstance] performSelectorOnMainThread:@selector(updateStatusTextCount:) withObject:@(currentModified) waitUntilDone:NO];
            } @catch (NSException *exception) {
                NSLog(@"[EriError]: %@", exception.reason);
            }
        }
        usleep(500000); // Quét liên tục mỗi 0.5 giây để đảm bảo bắt trọn các nốt nhạc trong trận
    }
    return NULL;
}

__attribute__((constructor)) static void initEriDylib() {
    @autoreleasepool {
        [EriMenuController sharedInstance];
        
        pthread_t t;
        pthread_create(&t, NULL, HackLoopThread, NULL);
        
        NSLog(@"[EriAutoDance]: Dylib successfully loaded with active memory injection!");
    }
}
