// main.mm — AutoDance HexControl v4.2 (Dynamic IL2CPP + Floating Menu)
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <pthread.h>
#include <dlfcn.h>
#include <stdint.h>
#include <string.h>
#include <substrate.h>

// ============================================================
// 1) Dynamic IL2CPP Function Pointers
// ============================================================
typedef const void* (*il2cpp_domain_get_t)(void);
typedef size_t (*il2cpp_domain_get_assembly_count_t)(const void *domain);
typedef void* (*il2cpp_domain_get_assembly_t)(const void *domain, size_t idx);
typedef const void* (*il2cpp_assembly_get_image_t)(void *assembly);
typedef void* (*il2cpp_class_from_name_t)(const void *image, const char *namespaze, const char *name);
typedef void* (*il2cpp_class_get_field_from_name_t)(void *klass, const char *name);
typedef ptrdiff_t (*il2cpp_field_get_offset_t)(void *field);
typedef void* (*il2cpp_class_get_method_from_name_t)(void *klass, const char *name, int argsCount);

static il2cpp_domain_get_t                 p_il2cpp_domain_get = nullptr;
static il2cpp_domain_get_assembly_count_t  p_il2cpp_domain_get_assembly_count = nullptr;
static il2cpp_domain_get_assembly_t        p_il2cpp_domain_get_assembly = nullptr;
static il2cpp_assembly_get_image_t         p_il2cpp_assembly_get_image = nullptr;
static il2cpp_class_from_name_t            p_il2cpp_class_from_name = nullptr;
static il2cpp_class_get_field_from_name_t  p_il2cpp_class_get_field_from_name = nullptr;
static il2cpp_field_get_offset_t           p_il2cpp_field_get_offset = nullptr;
static il2cpp_class_get_method_from_name_t p_il2cpp_class_get_method_from_name = nullptr;

static void InitIL2CPPAPIs() {
    void* handle = RTLD_DEFAULT; 
    p_il2cpp_domain_get = (il2cpp_domain_get_t)dlsym(handle, "il2cpp_domain_get");
    p_il2cpp_domain_get_assembly_count = (il2cpp_domain_get_assembly_count_t)dlsym(handle, "il2cpp_domain_get_assembly_count");
    p_il2cpp_domain_get_assembly = (il2cpp_domain_get_assembly_t)dlsym(handle, "il2cpp_domain_get_assembly");
    p_il2cpp_assembly_get_image = (il2cpp_assembly_get_image_t)dlsym(handle, "il2cpp_assembly_get_image");
    p_il2cpp_class_from_name = (il2cpp_class_from_name_t)dlsym(handle, "il2cpp_class_from_name");
    p_il2cpp_class_get_field_from_name = (il2cpp_class_get_field_from_name_t)dlsym(handle, "il2cpp_class_get_field_from_name");
    p_il2cpp_field_get_offset = (il2cpp_field_get_offset_t)dlsym(handle, "il2cpp_field_get_offset");
    p_il2cpp_class_get_method_from_name = (il2cpp_class_get_method_from_name_t)dlsym(handle, "il2cpp_class_get_method_from_name");
}

// ============================================================
// 2) Configuration & Offsets Mapping (tương đương Lua script)
// ============================================================
static const int    PERFECT_LEVEL   = 4;
static bool         g_AutoDanceOn   = true;

struct ModOffsets {
    ptrdiff_t judgeLevel;     // offset 64
    ptrdiff_t isHitBeat;      // offset 50
    ptrdiff_t isPlay;         // offset 408 (GuidTrackDanceNoteCtrl)
    bool ready;
};
static ModOffsets g_off = {0, 0, 0, false};

static void* FindClass(const char* ns, const char* name) {
    if (!p_il2cpp_domain_get || !p_il2cpp_domain_get_assembly_count) return nullptr;
    const void* domain = p_il2cpp_domain_get();
    size_t count = p_il2cpp_domain_get_assembly_count(domain);
    for (size_t i = 0; i < count; i++) {
        void* asm_ = p_il2cpp_domain_get_assembly(domain, i);
        if (!asm_) continue;
        const void* img = p_il2cpp_assembly_get_image(asm_);
        if (!img) continue;
        void* cls = p_il2cpp_class_from_name(img, ns, name);
        if (cls) return cls;
    }
    return nullptr;
}

static void ResolveOffsets() {
    if (g_off.ready) return;
    InitIL2CPPAPIs();

    // 1. Dance.AuditionGroup
    void* agCls = FindClass("Dance", "AuditionGroup");
    if (agCls && p_il2cpp_class_get_field_from_name && p_il2cpp_field_get_offset) {
        void* f1 = p_il2cpp_class_get_field_from_name(agCls, "judgeLevel");
        void* f2 = p_il2cpp_class_get_field_from_name(agCls, "isHitBeat");
        if (f1) g_off.judgeLevel = p_il2cpp_field_get_offset(f1);
        if (f2) g_off.isHitBeat  = p_il2cpp_field_get_offset(f2);
    }

    // 2. GuidTrackDanceNoteCtrl
    void* trCls = FindClass("", "GuidTrackDanceNoteCtrl");
    if (trCls && p_il2cpp_class_get_field_from_name && p_il2cpp_field_get_offset) {
        void* f3 = p_il2cpp_class_get_field_from_name(trCls, "isPlay");
        if (f3) g_off.isPlay = p_il2cpp_field_get_offset(f3);
    }

    g_off.ready = true;
    NSLog(@"[AutoDance v4.2] Offsets resolved -> judgeLevel: %td, isHitBeat: %td, isPlay: %td", 
          g_off.judgeLevel, g_off.isHitBeat, g_off.isPlay);
}

// ============================================================
// 3) Hook Implementation (AuditionGroup::Update)
// ============================================================
typedef void (*AuditionGroup_Update_t)(void* self, void* method);
static AuditionGroup_Update_t orig_AuditionGroup_Update = nullptr;

static void hk_AuditionGroup_Update(void* self, void* method) {
    if (g_AutoDanceOn && g_off.ready && self) {
        if (g_off.judgeLevel != 0) {
            int* judgePtr = (int*)((uintptr_t)self + g_off.judgeLevel);
            *judgePtr = PERFECT_LEVEL;
        }
        if (g_off.isHitBeat != 0) {
            bool* hitPtr = (bool*)((uintptr_t)self + g_off.isHitBeat);
            *hitPtr = true;
        }
    }

    if (orig_AuditionGroup_Update) {
        orig_AuditionGroup_Update(self, method);
    }
}

static void SetupHooks() {
    ResolveOffsets();
    void* agCls = FindClass("Dance", "AuditionGroup");
    if (!agCls || !p_il2cpp_class_get_method_from_name) return;

    void* updateMethod = p_il2cpp_class_get_method_from_name(agCls, "Update", 0);
    if (updateMethod) {
        void* funcAddress = *(void**)((uintptr_t)updateMethod);
        if (funcAddress) {
            MSHookFunction(funcAddress, (void*)&hk_AuditionGroup_Update, (void**)&orig_AuditionGroup_Update);
            NSLog(@"[AutoDance v4.2] Hooked AuditionGroup::Update successfully at %p", funcAddress);
        }
    }
}

// ============================================================
// 4) Floating Menu UI Implementation (Giao diện tùy chỉnh)
// ============================================================
@interface AutoDanceMenuController : NSObject
@property (nonatomic, strong) UIButton *floatingButton;
@property (nonatomic, strong) UIView *menuView;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation AutoDanceMenuController

+ (instancetype)sharedInstance {
    static AutoDanceMenuController *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[AutoDanceMenuController alloc] init];
    });
    return sharedInstance;
}

- (void)showMenu {
    __block UIWindow *keyWindow = nil;
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
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
#pragma clang diagnostic pop

    if (!keyWindow) return;

    // 1. Floating Button (Nút icon mở menu)
    self.floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatingButton.frame = CGRectMake(20, 120, 45, 45);
    self.floatingButton.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:0.85];
    [self.floatingButton setTitle:@"💃" forState:UIControlStateNormal];
    self.floatingButton.layer.cornerRadius = 22.5;
    self.floatingButton.layer.borderWidth = 1.5;
    self.floatingButton.layer.borderColor = [[UIColor cyanColor] CGColor];
    [self.floatingButton addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(buttonDragged:)];
    [self.floatingButton addGestureRecognizer:pan];
    [keyWindow addSubview:self.floatingButton];

    // 2. Menu View (Bảng điều khiển)
    self.menuView = [[UIView alloc] initWithFrame:CGRectMake(75, 120, 240, 180)];
    self.menuView.backgroundColor = [UIColor colorWithRed:0.06 green:0.06 blue:0.06 alpha:0.92];
    self.menuView.layer.cornerRadius = 12;
    self.menuView.layer.borderWidth = 1;
    self.menuView.layer.borderColor = [[UIColor cyanColor] CGColor];
    self.menuView.hidden = YES;

    // Title
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 8, 220, 25)];
    titleLabel.text = @"AutoDance HexControl v4.2";
    titleLabel.textColor = [UIColor cyanColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:13];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.menuView addSubview:titleLabel];

    // Switch Toggle Auto Perfect
    UILabel *switchLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 45, 140, 30)];
    switchLabel.text = @"Bật Auto (Perfect)";
    switchLabel.textColor = [UIColor whiteColor];
    switchLabel.font = [UIFont systemFontOfSize:13];
    [self.menuView addSubview:switchLabel];

    UISwitch *toggleSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(165, 45, 0, 0)];
    toggleSwitch.on = g_AutoDanceOn;
    [toggleSwitch addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.menuView addSubview:toggleSwitch];

    // Status Display
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 85, 210, 80)];
    self.statusLabel.text = @"Sẵn sàng. Bật toggle để chạy tự động qua các trận.";
    self.statusLabel.textColor = [UIColor lightGrayColor];
    self.statusLabel.font = [UIFont systemFontOfSize:11];
    self.statusLabel.numberOfLines = 0;
    [self.menuView addSubview:self.statusLabel];

    [keyWindow addSubview:self.menuView];
}

- (void)toggleMenu {
    self.menuView.hidden = !self.menuView.hidden;
}

- (void)switchChanged:(UISwitch *)sender {
    g_AutoDanceOn = sender.isOn;
    if (g_AutoDanceOn) {
        self.statusLabel.text = @"Đã BẬT tính năng Auto Dance.";
    } else {
        self.statusLabel.text = @"Đã TẮT tính năng Auto Dance.";
    }
}

- (void)buttonDragged:(UIPanGestureRecognizer *)gesture {
    UIWindow *window = self.floatingButton.window;
    CGPoint translation = [gesture translationInView:window];
    CGPoint center = self.floatingButton.center;
    self.floatingButton.center = CGPointMake(center.x + translation.x, center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:window];
}

@end

// ============================================================
// 5) Dylib Entry Point
// ============================================================
__attribute__((constructor))
static void InitDylib() {
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
            SetupHooks();
            [[AutoDanceMenuController sharedInstance] showMenu];
        }
    );
}
