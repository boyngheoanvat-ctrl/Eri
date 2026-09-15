#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <pthread.h>
#include <atomic>
#include <vector>
#include <dlfcn.h>

struct Il2CppObject;
struct Il2CppClass;
struct Il2CppDomain;
struct Il2CppImage;

typedef Il2CppDomain* (*t_il2cpp_domain_get)(void);
typedef Il2CppImage** (*t_il2cpp_domain_get_assemblies)(const Il2CppDomain* domain, size_t* size);
typedef Il2CppClass* (*t_il2cpp_class_from_name)(const Il2CppImage* image, const char* namespaze, const char* name);
typedef void (*t_il2cpp_gc_foreach_heap_object)(void(*callback)(Il2CppObject*, void*), void* user_data);

static t_il2cpp_domain_get f_il2cpp_domain_get = nullptr;
static t_il2cpp_domain_get_assemblies f_il2cpp_domain_get_assemblies = nullptr;
static t_il2cpp_class_from_name f_il2cpp_class_from_name = nullptr;
static t_il2cpp_gc_foreach_heap_object f_il2cpp_gc_foreach_heap_object = nullptr;

static void InitIl2CppSymbols() {
    if (f_il2cpp_domain_get) return;
    void* handle = RTLD_DEFAULT;
    f_il2cpp_domain_get = (t_il2cpp_domain_get)dlsym(handle, "il2cpp_domain_get");
    f_il2cpp_domain_get_assemblies = (t_il2cpp_domain_get_assemblies)dlsym(handle, "il2cpp_domain_get_assemblies");
    f_il2cpp_class_from_name = (t_il2cpp_class_from_name)dlsym(handle, "il2cpp_class_from_name");
    f_il2cpp_gc_foreach_heap_object = (t_il2cpp_gc_foreach_heap_object)dlsym(handle, "il2cpp_gc_foreach_heap_object");
}

// Khớp chính xác các offset theo Lua script (HexControl v4)
// Lưu ý: Các field trong C# thông thường qua il2cpp được biên dịch thành offset field thực tế bên trong struct instance.
// Dựa theo script Lua: judgeLevel, isHitBeat, isJudgeAllKey, IsPlaying
static const uint32_t OFF_JUDGE_LEVEL      = 0x40; // judgeLevel
static const uint32_t OFF_IS_HIT_BEAT       = 0x34; // isHitBeat
static const uint32_t OFF_IS_JUDGE_ALL_KEY  = 0x35; // isJudgeAllKey
static const uint32_t OFF_IS_PLAYING        = 0x198;// IsPlaying

static const int32_t  PERFECT               = 4;     

static std::atomic<bool> g_isHackActive{false};
static int g_modifiedObjectsCount = 0;

static std::vector<void*> g_cachedAuditionGroups;
static std::vector<void*> g_cachedTrackCtrls;

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

    self.menuView = [[UIView alloc] initWithFrame:CGRectMake(95, 120, 260, 210)];
    self.menuView.backgroundColor = [UIColor colorWithWhite:0.12 alpha:0.95];
    self.menuView.layer.cornerRadius = 14;
    self.menuView.layer.borderWidth = 1.5;
    self.menuView.layer.borderColor = [UIColor cyanColor].CGColor;
    self.menuView.hidden = YES;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 240, 25)];
    titleLabel.text = @"HexControl v4 (Auto-Match)";
    titleLabel.textColor = [UIColor cyanColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:14];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.menuView addSubview:titleLabel];

    self.toggleSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(20, 48, 0, 0)];
    [self.toggleSwitch addTarget:self action:@selector(onSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.menuView addSubview:self.toggleSwitch];

    UILabel *switchText = [[UILabel alloc] initWithFrame:CGRectMake(85, 45, 160, 30)];
    switchText.text = @"Bật Auto Tất Cả";
    switchText.textColor = [UIColor whiteColor];
    switchText.font = [UIFont systemFontOfSize:13];
    [self.menuView addSubview:switchText];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 85, 230, 110)];
    self.statusLabel.text = @"Trạng thái: Sẵn sàng.\n- Bật toggle để chạy tự động qua các trận.\n- Objects: 0";
    self.statusLabel.textColor = [UIColor lightGrayColor];
    self.statusLabel.font = [UIFont systemFontOfSize:11];
    self.statusLabel.numberOfLines = 5;
    [self.menuView addSubview:self.statusLabel];

    [keyWindow addSubview:self.menuView];
}

-(void)toggleMenuVisibility:(UIButton *)sender {
    self.menuView.hidden = !self.menuView.hidden;
}

-(void)onSwitchChanged:(UISwitch *)sender {
    g_isHackActive = sender.isOn;
    if (sender.isOn) {
        self.statusLabel.text = [NSString stringWithFormat:@"Trạng thái: ĐÃ BẬT (Auto) 🟢\n- Đang theo dõi trận đấu...\n- Objects: %d", g_modifiedObjectsCount];
    } else {
        self.statusLabel.text = @"Trạng thái: ĐÃ TẮT 🔴\n- Đã dừng tính năng.";
    }
}

-(void)updateStatusTextCount:(NSNumber *)countNum {
    if (g_isHackActive) {
        int count = [countNum intValue];
        self.statusLabel.text = [NSString stringWithFormat:@"Trạng thái: ĐÃ BẬT (Auto) 🟢\n- Đã tự động áp dụng trận mới!\n- Objects: %d", count];
    }
}

@end

void* HackLoopThread(void* arg) {
    InitIl2CppSymbols();
    time_t lastCheckTime = 0;
    
    while (true) {
        time_t currentTime = time(NULL);
        // Cơ chế thông minh định kỳ mỗi 2 giây nhận trận mới y như script Lua
        if (g_isHackActive.load() && f_il2cpp_domain_get && (currentTime - lastCheckTime >= 2)) {
            lastCheckTime = currentTime;
            int count = 0;
            @try {
                Il2CppDomain* domain = f_il2cpp_domain_get();
                if (domain && f_il2cpp_domain_get_assemblies) {
                    size_t assemblyCount = 0;
                    Il2CppImage** assemblies = f_il2cpp_domain_get_assemblies(domain, &assemblyCount);
                    
                    if ((!g_targetAuditionClass || !g_targetTrackCtrlClass) && f_il2cpp_class_from_name) {
                        for (size_t i = 0; i < assemblyCount; i++) {
                            if (!g_targetAuditionClass) {
                                g_targetAuditionClass = f_il2cpp_class_from_name(assemblies[i], "Dance", "AuditionGroup");
                            }
                            if (!g_targetTrackCtrlClass) {
                                g_targetTrackCtrlClass = f_il2cpp_class_from_name(assemblies[i], "", "GuidTrackDanceNoteCtrl");
                            }
                        }
                    }

                    if ((g_targetAuditionClass || g_targetTrackCtrlClass) && f_il2cpp_gc_foreach_heap_object) {
                        g_cachedAuditionGroups.clear();
                        g_cachedTrackCtrls.clear();
                        
                        f_il2cpp_gc_foreach_heap_object(HeapObjectCallback, nullptr);

                        for (void* obj : g_cachedAuditionGroups) {
                            if (obj) {
                                *(int32_t*)((uint8_t*)obj + OFF_JUDGE_LEVEL) = PERFECT;
                                *(bool*)((uint8_t*)obj + OFF_IS_HIT_BEAT) = true;
                                *(bool*)((uint8_t*)obj + OFF_IS_JUDGE_ALL_KEY) = true;
                                count++;
                            }
                        }

                        for (void* obj : g_cachedTrackCtrls) {
                            if (obj) {
                                *(bool*)((uint8_t*)obj + OFF_IS_PLAYING) = true;
                                count++;
                            }
                        }
                    }
                }
                
                g_modifiedObjectsCount = count;
                if (count > 0) {
                    [[EriMenuController sharedInstance] performSelectorOnMainThread:@selector(updateStatusTextCount:) withObject:@(count) waitUntilDone:NO];
                }
            } @catch (NSException *exception) {
                NSLog(@"[HexControlError]: %@", exception.reason);
            }
        }
        usleep(500000); // Ngủ ngắn để không chiếm dụng CPU
    }
    return NULL;
}

__attribute__((constructor)) static void initEriDylib() {
    @autoreleasepool {
        [EriMenuController sharedInstance];
        pthread_t t;
        pthread_create(&t, NULL, HackLoopThread, NULL);
        NSLog(@"[HexControl v4]: Initialized successfully.");
    }
}
