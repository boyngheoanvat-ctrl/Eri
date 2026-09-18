#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "substrate.h"
#import <mach/mach.h>

#pragma mark - === HẰNG SỐ ===
enum JudgeLv : int32_t { MISS = 0, PERFECT = 4 };

#pragma mark - === OFFSET TRƯỜNG DỮ LIỆU ===
#define JUDGE_LEVEL     0x40   // judgeLevel
#define IS_HIT_BEAT     0x32   // isHitBeat
#define LIST_GROUPS     0x48   // m_ListGroups
#define CURRENT_GROUP   0x64   // m_CurrentGroup

#define TN_IS_JUDGE     0x30   // isJudgeLevel
#define TN_JUDGE_VAL    0x38   // JudgeLevel
#define TN_IS_HIT       0x40   // isHit
#define TN_LIST_NOTES   0x80   // m_Notes

#define DYN_LIST_GROUPS 0x60   // m_Groups
#define GROUP_KEYS      0x18   // m_Keys
#define KEY_JUDGE       0x20   // judgeLevel
#define KEY_RATIO       0x34   // JudgeRatio

// Cấu trúc danh sách IL2CPP — chuẩn
#define LIST_COUNT      0x18
#define LIST_ITEMS      0x10
#define ARRAY_ITEMS     0x20
#define ARRAY_COUNT     0x18

#define WR32(o,f,v)  do{if(o)*(int32_t*)((uint8_t*)(o)+(f))=(v);}while(0)
#define WRB(o,f,v)   do{if(o)*(bool*) ((uint8_t*)(o)+(f))=(v);}while(0)

static inline int32_t cntList(void* p) { return p ? *(int32_t*)((uint8_t*)p + LIST_COUNT) : 0; }
static inline void* getList(void* p, int32_t i) {
    if(!p || i < 0) return nullptr;
    void** arr = *(void***)((uint8_t*)p + LIST_ITEMS);
    return (arr && i < cntList(p)) ? arr[i] : nullptr;
}
static inline int32_t cntArr(void* p) { return p ? (int32_t)*(int64_t*)((uint8_t*)p + ARRAY_COUNT) : 0; }
static inline void* getArr(void* p, int32_t i) {
    if(!p || i < 0) return nullptr;
    return (i < cntArr(p)) ? *(void**)((uint8_t*)p + ARRAY_ITEMS + (size_t)i * 8) : nullptr;
}

#pragma mark - === TRẠNG THÁI ===
static bool g_autoArrow = false;
static bool g_autoTaiko = false;
static bool g_autoMini   = false;

static void* g_instArrow = nullptr;
static void* g_instTaiko = nullptr;
static void* g_instMini  = nullptr;

#pragma mark - === LOGIC AUTO ===
static int xuLyArrow() {
    if(!g_instArrow) return 0;
    int n = 0;
    void* list = *(void**)((uint8_t*)g_instArrow + LIST_GROUPS);
    if(!list) return 0;
    
    for(int i = 0, N = cntList(list); i < N; i++) {
        void* grp = getList(list, i);
        if(!grp) continue;
        WR32(grp, JUDGE_LEVEL, PERFECT);
        WRB(grp, IS_HIT_BEAT, true);
        n++;
    }
    void* cur = *(void**)((uint8_t*)g_instArrow + CURRENT_GROUP);
    if(cur) {
        WR32(cur, JUDGE_LEVEL, PERFECT);
        WRB(cur, IS_HIT_BEAT, true);
        n++;
    }
    return n;
}

static int xuLyTaiko() {
    if(!g_instTaiko) return 0;
    int n = 0;
    void* list = *(void**)((uint8_t*)g_instTaiko + TN_LIST_NOTES);
    if(!list) return 0;
    
    for(int i = 0, N = cntList(list); i < N; i++) {
        void* note = getList(list, i);
        if(!note) continue;
        WRB(note, TN_IS_JUDGE, true);
        WR32(note, TN_JUDGE_VAL, PERFECT);
        WRB(note, TN_IS_HIT, true);
        n++;
    }
    return n;
}

static int xuLyMini() {
    if(!g_instMini) return 0;
    int n = 0;
    void* list = *(void**)((uint8_t*)g_instMini + DYN_LIST_GROUPS);
    if(!list) return 0;
    
    for(int i = 0, N = cntList(list); i < N; i++) {
        void* grp = getList(list, i);
        if(!grp) continue;
        void* keys = *(void**)((uint8_t*)grp + GROUP_KEYS);
        for(int k = 0, K = cntArr(keys); k < K; k++) {
            void* key = getArr(keys, k);
            if(!key) continue;
            WR32(key, KEY_JUDGE, PERFECT);
            WR32(key, KEY_RATIO, 100);
        }
        n++;
    }
    return n;
}

#pragma mark - === HOOK HÀM AWAKE — ĐÃ ĐIỀN SỐ CHÍNH XÁC ===
typedef void (*HamAwake)(void* self);

// ✅ Dance.AuditionGroup
static HamAwake g_origAwakeArrow = nullptr;
static void HookedAwakeArrow(void* self) {
    if(g_origAwakeArrow) g_origAwakeArrow(self);
    g_instArrow = self;
    NSLog(@"[EriMod] ✅ AuditionGroup kết nối: %p", self);
}
#define ADDR_AWAKE_ARROW   0x3e0dc5c

// ✅ DanceTaikoController
static HamAwake g_origAwakeTaiko = nullptr;
static void HookedAwakeTaiko(void* self) {
    if(g_origAwakeTaiko) g_origAwakeTaiko(self);
    g_instTaiko = self;
    NSLog(@"[EriMod] ✅ TaikoController kết nối: %p", self);
}
#define ADDR_AWAKE_TAIKO   0x3e0dc5c

// ✅ DynamicArrowsController
static HamAwake g_origAwakeMini = nullptr;
static void HookedAwakeMini(void* self) {
    if(g_origAwakeMini) g_origAwakeMini(self);
    g_instMini = self;
    NSLog(@"[EriMod] ✅ DynamicArrows kết nối: %p", self);
}
#define ADDR_AWAKE_MINI    0x3e0dc5c

#pragma mark - === GIAO DIỆN ===
static UIButton* g_btn = nil;
static UIView* g_panel = nil;
static bool g_show = true;

static void updateDisplay() {
    dispatch_async(dispatch_get_main_queue(), ^{
        if(!g_panel) return;
        UILabel* l1 = [g_panel viewWithTag:101];
        UILabel* l2 = [g_panel viewWithTag:102];
        UILabel* l3 = [g_panel viewWithTag:103];
        UILabel* addr = [g_panel viewWithTag:999];
        
        l1.text = [NSString stringWithFormat:@"⚡ Auto Arrow: %@", g_autoArrow ? @"BẬT ✅" : @"TẮT ❌"];
        l1.textColor = g_autoArrow ? [UIColor systemGreenColor] : [UIColor lightGrayColor];
        l2.text = [NSString stringWithFormat:@"🥁 Auto Taiko: %@", g_autoTaiko ? @"BẬT ✅" : @"TẮT ❌"];
        l2.textColor = g_autoTaiko ? [UIColor systemGreenColor] : [UIColor lightGrayColor];
        l3.text = [NSString stringWithFormat:@"🔥 Mini+Crazy: %@", g_autoMini ? @"BẬT ✅" : @"TẮT ❌"];
        l3.textColor = g_autoMini ? [UIColor systemGreenColor] : [UIColor lightGrayColor];
        addr.text = [NSString stringWithFormat:@"A:%p T:%p M:%p", g_instArrow, g_instTaiko, g_instMini];
    });
}

static void buildUI() {
    dispatch_async(dispatch_get_main_queue(), ^{
        if(g_btn) return;
        
        UIWindow* win = nil;
        if (@available(iOS 13.0, *)) {
            for(UIScene* s in [UIApplication sharedApplication].connectedScenes) {
                if([s isKindOfClass:[UIWindowScene class]])
                    for(UIWindow* w in [(UIWindowScene*)s windows])
                        if(w.isKeyWindow) { win = w; break; }
            }
        }
        if(!win) win = [UIApplication sharedApplication].keyWindow;
        if(!win || !win.rootViewController) return;
        
        // Nút mở menu
        g_btn = [UIButton buttonWithType:UIButtonTypeCustom];
        g_btn.frame = CGRectMake(15, 150, 56, 56);
        g_btn.backgroundColor = [UIColor colorWithRed:0.15 green:0.1 blue:0.25 alpha:0.95];
        g_btn.layer.cornerRadius = 28;
        g_btn.layer.borderWidth = 2.5;
        g_btn.layer.borderColor = [UIColor colorWithRed:1 green:0.3 blue:0.5 alpha:1].CGColor;
        [g_btn setTitle:@"🎮" forState:UIControlStateNormal];
        g_btn.titleLabel.font = [UIFont systemFontOfSize:28];
        [g_btn addAction:[UIAction actionWithHandler:^(UIAction*){
            g_show = !g_show; g_panel.hidden = !g_show;
        }] forControlEvents:UIControlEventTouchUpInside];
        [win.rootViewController.view addSubview:g_btn];
        
        // Bảng điều khiển
        g_panel = [[UIView alloc] initWithFrame:CGRectMake(85, 70, 290, 300)];
        g_panel.backgroundColor = [UIColor colorWithRed:0.07 green:0.05 blue:0.12 alpha:0.96];
        g_panel.layer.cornerRadius = 18;
        g_panel.layer.borderWidth = 2;
        g_panel.layer.borderColor = [UIColor colorWithRed:1 green:0.25 blue:0.5 alpha:1].CGColor;
        
        UILabel* title = [[UILabel alloc] initWithFrame:CGRectMake(15, 12, 260, 28)];
        title.text = @"✨ AutoDance AU2 v23.4";
        title.textColor = [UIColor whiteColor];
        title.font = [UIFont boldSystemFontOfSize:17];
        [g_panel addSubview:title];
        
        // Nút Arrow
        UIButton* b1 = [[UIButton alloc] initWithFrame:CGRectMake(15, 50, 260, 48)];
        b1.backgroundColor = [UIColor darkGrayColor];
        b1.layer.cornerRadius = 12;
        [b1 addAction:[UIAction actionWithHandler:^(UIAction*){
            g_autoArrow = !g_autoArrow; updateDisplay();
        }] forControlEvents:UIControlEventTouchUpInside];
        [g_panel addSubview:b1];
        UILabel* l1 = [[UILabel alloc] initWithFrame:CGRectMake(20, 52, 250, 44)];
        l1.tag = 101; l1.text = @"⚡ Auto Arrow: TẮT";
        l1.font = [UIFont systemFontOfSize:15];
        [g_panel addSubview:l1];
        
        // Nút Taiko
        UIButton* b2 = [[UIButton alloc] initWithFrame:CGRectMake(15, 108, 260, 48)];
        b2.backgroundColor = [UIColor darkGrayColor];
        b2.layer.cornerRadius = 12;
        [b2 addAction:[UIAction actionWithHandler:^(UIAction*){
            g_autoTaiko = !g_autoTaiko; updateDisplay();
        }] forControlEvents:UIControlEventTouchUpInside];
        [g_panel addSubview:b2];
        UILabel* l2 = [[UILabel alloc] initWithFrame:CGRectMake(20, 110, 250, 44)];
        l2.tag = 102; l2.text = @"🥁 Auto Taiko: TẮT";
        l2.font = [UIFont systemFontOfSize:15];
        [g_panel addSubview:l2];
        
        // Nút Mini
        UIButton* b3 = [[UIButton alloc] initWithFrame:CGRectMake(15, 166, 260, 48)];
        b3.backgroundColor = [UIColor darkGrayColor];
        b3.layer.cornerRadius = 12;
        [b3 addAction:[UIAction actionWithHandler:^(UIAction*){
            g_autoMini = !g_autoMini; updateDisplay();
        }] forControlEvents:UIControlEventTouchUpInside];
        [g_panel addSubview:b3];
        UILabel* l3 = [[UILabel alloc] initWithFrame:CGRectMake(20, 168, 250, 44)];
        l3.tag = 103; l3.text = @"🔥 Mini+Crazy: TẮT";
        l3.font = [UIFont systemFontOfSize:15];
        [g_panel addSubview:l3];
        
        // Địa chỉ kết nối
        UILabel* addr = [[UILabel alloc] initWithFrame:CGRectMake(15, 225, 260, 22)];
        addr.tag = 999;
        addr.text = @"A:0x0 | T:0x0 | M:0x0";
        addr.textColor = [UIColor lightGrayColor];
        addr.font = [UIFont fontWithName:@"Menlo" size:10];
        [g_panel addSubview:addr];
        
        UILabel* note = [[UILabel alloc] initWithFrame:CGRectMake(15, 250, 260, 20)];
        note.text = @"💡 Vào màn hình chơi → tự kết nối";
        note.textColor = [UIColor grayColor];
        note.font = [UIFont systemFontOfSize:11];
        [g_panel addSubview:note];
        
        [win.rootViewController.view addSubview:g_panel];
    });
}

#pragma mark - === VÒNG LẶP CHÍNH ===
static void mainLoop() {
    static double lastRun = 0;
    double now = CFAbsoluteTimeGetCurrent();
    if(now - lastRun < 0.5) return;
    lastRun = now;
    
    if(g_autoArrow && g_instArrow) {
        int n = xuLyArrow();
        if(n > 0) NSLog(@"[EriMod] ⚡ HOÀN HẢO %d nốt Arrow", n);
    }
    if(g_autoTaiko && g_instTaiko) {
        int n = xuLyTaiko();
        if(n > 0) NSLog(@"[EriMod] 🥁 HOÀN HẢO %d nốt Taiko", n);
    }
    if(g_autoMini && g_instMini) {
        int n = xuLyMini();
        if(n > 0) NSLog(@"[EriMod] 🔥 HOÀN HẢO %d nhóm Mini", n);
    }
    
    updateDisplay();
}

#pragma mark - === KHỞI TẠO ===
__attribute__((constructor))
static void init() {
    NSLog(@"[EriMod] === AutoDance AU2 v23.4 ===");
    NSLog(@"[EriMod] Offset Awake: 0x3e0dc5c ✅");
    
    // Hook hàm Awake
    MSHookFunction((void*)ADDR_AWAKE_ARROW, (void*)HookedAwakeArrow, (void**)&g_origAwakeArrow);
    NSLog(@"[EriMod] ✅ Hook: AuditionGroup");
    
    MSHookFunction((void*)ADDR_AWAKE_TAIKO, (void*)HookedAwakeTaiko, (void**)&g_origAwakeTaiko);
    NSLog(@"[EriMod] ✅ Hook: TaikoController");
    
    MSHookFunction((void*)ADDR_AWAKE_MINI, (void*)HookedAwakeMini, (void**)&g_origAwakeMini);
    NSLog(@"[EriMod] ✅ Hook: DynamicArrows");
    
    // Tạo giao diện
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        buildUI();
    });
    
    // Chạy vòng lặp
    dispatch_source_t timer = dispatch_source_create(
        DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW,
                              500000000ULL, 200000000ULL);
    dispatch_source_set_event_handler(timer, ^{ mainLoop(); });
    dispatch_resume(timer);
}
