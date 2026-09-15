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

// Thử dịch chuyển hoặc kiểm tra lại offset chuẩn của bản game hiện tại
static const uint32_t OFF_JUDGE_LEVEL = 0x44;   // Đã dịch chuyển nhẹ để tránh đè sai biến logic
static const uint32_t OFF_IS_HIT_BEAT  = 0x36;  
static const int32_t  PERFECT          = 4;     

static std::atomic<bool> g_isHackActive{false};
static int g_modifiedObjectsCount = 0;

static std::vector<void*> g_cachedAuditionGroups;
static Il2CppClass* g_targetAuditionClass = nullptr;

static void HeapObjectCallback(Il2CppObject* obj, void* user_data) {
    if (!obj) return;
    Il2CppClass* klass = *(Il2CppClass**)(obj);
    if (klass == g_targetAuditionClass) {
        g_cachedAuditionGroups.push_back((void*)obj);
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
    titleLabel.text = @"Eri AutoDance Menu v4.3";
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
    self.statusLabel.text = @"Trạng thái: Đang Tắt\n- Sẵn sàng quét...\n- Bấm công tắc để bắt đầu.";
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
        self.statusLabel.text = [NSString stringWithFormat:@"Trạng thái: ĐÃ BẬT 🟢\n- Đang quét AuditionGroup...\n- Đã tác động: %d objects", g_modifiedObjectsCount];
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

void* HackLoopThread(void* arg) {
    InitIl2CppSymbols();
    while (true) {
        if (g_isHackActive.load() && f_il2cpp_domain_get) {
            int currentModified = 0;
            @try {
                Il2CppDomain* domain = f_il2cpp_domain_get();
                if (domain && f_il2cpp_domain_get_assemblies) {
                    size_t assemblyCount = 0;
                    Il2CppImage** assemblies = f_il2cpp_domain_get_assemblies(domain, &assemblyCount);
                    
                    if (!g_targetAuditionClass && f_il2cpp_class_from_name) {
                        for (size_t i = 0; i < assemblyCount; i++) {
                            g_targetAuditionClass = f_il2cpp_class_from_name(assemblies[i], "Dance", "AuditionGroup");
                            if (g_targetAuditionClass) break;
                        }
                    }

                    if (g_targetAuditionClass && f_il2cpp_gc_foreach_heap_object) {
                        g_cachedAuditionGroups.clear();
                        f_il2cpp_gc_foreach_heap_object(HeapObjectCallback, nullptr);

                        for (void* obj : g_cachedAuditionGroups) {
                            if (obj) {
                                // Chỉ ghi đè mức phán định khi object còn sống và hợp lệ
                                *(int32_t*)((uint8_t*)obj + OFF_JUDGE_LEVEL) = PERFECT;
                                *(bool*)((uint8_t*)obj + OFF_IS_HIT_BEAT) = true;
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
        usleep(200000); // Tần suất quét nhanh hơn mượt hơn (0.2s)
    }
    return NULL;
}

__attribute__((constructor)) static void initEriDylib() {
    @autoreleasepool {
        [EriMenuController sharedInstance];
        pthread_t t;
        pthread_create(&t, NULL, HackLoopThread, NULL);
    }
}
