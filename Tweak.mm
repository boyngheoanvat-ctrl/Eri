#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <dispatch/dispatch.h>
#import <objc/runtime.h>
#include <map>
#include <string>
#include <ctime>
#include <mach/mach.h>

#pragma mark - === SUBSTRATE ===
extern "C" {
    void MSHookFunction(void* symbol, void* replacement, void** storage);
    void* MSFindSymbol(const char* image, const char* name);
}

#pragma mark - === OFFSET — AU2 v23.4 ĐÃ KIỂM TRA ===
enum JudgeLv : int32_t { MISS = 0, PERFECT = 4 };
struct Off {
    // Arrow Mode
    static const uint32_t A_listGrp = 0x48;
    static const uint32_t A_curGrp  = 0x64;
    static const uint32_t G_judge   = 0x40;
    static const uint32_t G_isHit   = 0x32;
    
    // Taiko Mode
    static const uint32_t T_listNote= 0x80;
    static const uint32_t TN_isJL   = 0x30;
    static const uint32_t TN_JL     = 0x38;
    static const uint32_t TN_isHit  = 0x40;
    
    // Mini/Crazy Mode
    static const uint32_t D_base    = 0x60;
    static const uint32_t D_score   = 0x64;
    static const uint32_t D_combo   = 0xAC;
    static const uint32_t D_listGrp = 0x60;
    static const uint32_t DG_keys   = 0x18;
    static const uint32_t DG_allHit = 0x21;
    static const uint32_t DG_idx    = 0x24;
    static const uint32_t OB_arrows = 0x10;
    static const uint32_t OB_JL     = 0x20;
    static const uint32_t OB_curIdx = 0x24;
    static const uint32_t OB_ratio  = 0x34;
};

#define RD32(p,o,d) ((p)?*(int32_t*)((uint8_t*)(p)+(o)):(d))
#define RD64(p,o,d) ((p)?*(int64_t*)((uint8_t*)(p)+(o)):(d))
#define RDB(p,o,d)  ((p)?*(bool*)((uint8_t*)(p)+(o)):(d))
#define WR32(p,o,v) do{if(p)*(int32_t*)((uint8_t*)(p)+(o))=(v);}while(0)
#define WR64(p,o,v) do{if(p)*(int64_t*)((uint8_t*)(p)+(o))=(v);}while(0)
#define WRB(p,o,v)  do{if(p)*(bool*)((uint8_t*)(p)+(o))=(v);}while(0)

static inline int32_t cntList(void* p) { return p ? *(int32_t*)((uint8_t*)p+0x18) : 0; }
static inline void* getList(void* p, int32_t i) {
    if(!p||i<0)return nullptr; void** arr=*(void***)((uint8_t*)p+0x10);
    return arr && i < cntList(p) ? arr[i] : nullptr;
}
static inline int32_t cntArr(void* p) { return p ? (int32_t)*(int64_t*)((uint8_t*)p+0x18) : 0; }
static inline void* getArr(void* p, int32_t i) {
    if(!p||i<0)return nullptr; return i < cntArr(p) ? *(void**)((uint8_t*)p+0x20+(size_t)i*8) : nullptr;
}

#pragma mark - === STATE ===
struct Saved { std::map<int, int32_t> i32; std::map<int, bool> b; };
static struct Global {
    bool arrow, taiko, mini;
    void* pA; void* pT; void* pD;
    std::map<void*, bool> scored;
    std::map<void*, Saved> saved;
    Global() : arrow(false), taiko(false), mini(false), pA(nullptr), pT(nullptr), pD(nullptr) {}
} g;

static void saveI32(void* obj, int off) { if(!obj||g.saved.count(obj))return; g.saved[obj].i32[off] = RD32(obj,off,0); }
static void saveB(void* obj, int off) { if(!obj||g.saved.count(obj))return; g.saved[obj].b[off] = RDB(obj,off,false); }
static void restoreAll() {
    for(auto& kv : g.saved) {
        for(auto& x : kv.second.i32) WR32(kv.first, x.first, x.second);
        for(auto& x : kv.second.b)   WRB(kv.first, x.first, x.second);
    }
    g.saved.clear(); g.scored.clear();
}

#pragma mark - === LOGIC ===
static int doArrow() {
    if(!g.pA) return 0; int n=0;
    NSLog(@"[EriMod] ⚡ ArrowController: %p", g.pA);
    void* list = *(void**)((uint8_t*)g.pA + Off::A_listGrp);
    if(!list) { NSLog(@"[EriMod] ⚠️ listGrp = NULL"); return 0; }
    
    for(int i=0,N=cntList(list);i<N;i++){
        void* grp=getList(list,i); if(!grp)continue;
        saveI32(grp, Off::G_judge); saveB(grp, Off::G_isHit);
        WR32(grp, Off::G_judge, PERFECT); WRB(grp, Off::G_isHit, true); n++;
    }
    void* cur = *(void**)((uint8_t*)g.pA + Off::A_curGrp);
    if(cur){ saveI32(cur, Off::G_judge); saveB(cur, Off::G_isHit);
        WR32(cur, Off::G_judge, PERFECT); WRB(cur, Off::G_isHit, true); n++; }
    return n;
}
static int doTaiko() {
    if(!g.pT) return 0; int n=0;
    NSLog(@"[EriMod] 🥁 TaikoController: %p", g.pT);
    void* list = *(void**)((uint8_t*)g.pT + Off::T_listNote);
    if(!list) { NSLog(@"[EriMod] ⚠️ listNote = NULL"); return 0; }
    
    for(int i=0,N=cntList(list);i<N;i++){
        void* note=getList(list,i); if(!note)continue;
        saveB(note, Off::TN_isJL); saveI32(note, Off::TN_JL); saveB(note, Off::TN_isHit);
        WRB(note, Off::TN_isJL, true); WR32(note, Off::TN_JL, PERFECT); WRB(note, Off::TN_isHit, true); n++;
    }
    return n;
}
static int doMini() {
    if(!g.pD) return 0; int n=0;
    NSLog(@"[EriMod] 🔥 MiniController: %p", g.pD);
    void* list = *(void**)((uint8_t*)g.pD + Off::D_listGrp);
    if(!list) { NSLog(@"[EriMod] ⚠️ listGrp = NULL"); return 0; }
    
    for(int i=0,N=cntList(list);i<N;i++){
        void* grp=getList(list,i); if(!grp)continue;
        void* keys = *(void**)((uint8_t*)grp + Off::DG_keys);
        for(int k=0,K=cntArr(keys);k<K;k++){
            void* kb=getArr(keys,k); if(!kb)continue;
            WR32(kb, Off::OB_JL, PERFECT); WR32(kb, Off::OB_ratio, 100);
        } n++;
    }
    return n;
}
static int fixIdx() {
    if(!g.pD) return 0; int fix=0;
    void* list = *(void**)((uint8_t*)g.pD + Off::D_listGrp);
    for(int i=0,N=cntList(list);i<N;i++){
        void* grp=getList(list,i); if(!grp)continue;
        void* keys = *(void**)((uint8_t*)grp + Off::DG_keys);
        for(int k=0,K=cntArr(keys);k<K;k++){
            void* kb=getArr(keys,k); if(!kb)continue;
            int idx=RD32(kb, Off::OB_curIdx, -1);
            void* arr = *(void**)((uint8_t*)kb + Off::OB_arrows);
            if(idx<0||idx>=cntArr(arr)){ WR32(kb, Off::OB_curIdx, 0); fix++; }
        }
    }
    return fix;
}
static void doScore() {
    if(!g.pD) return;
    int64_t base=RD64(g.pD,Off::D_base,100);
    int combo=RD32(g.pD,Off::D_combo,1);
    int64_t score=RD64(g.pD,Off::D_score,0);
    double mul=1.0+std::max(combo-1,0)*0.05;
    void* list = *(void**)((uint8_t*)g.pD + Off::D_listGrp);
    for(int i=0,N=cntList(list);i<N;i++){
        void* grp=getList(list,i);
        if(!grp||g.scored[grp])continue;
        if(!RDB(grp,Off::DG_allHit,false))continue;
        int kcnt=RD32(grp,Off::DG_idx,1); if(kcnt<1)kcnt=1;
        score += (int64_t)std::floor((double)base*mul*kcnt);
        g.scored[grp]=true;
    }
    WR64(g.pD, Off::D_score, score);
}

#pragma mark - === UI ===
static UIButton* g_iconBtn = nil;
static UIView* g_menuPanel = nil;
static UIButton* g_btnArrow = nil;
static UIButton* g_btnTaiko = nil;
static UIButton* g_btnMini = nil;
static bool g_menuVisible = true;

static void updateUI() {
    dispatch_async(dispatch_get_main_queue(), ^{
        if(!g_btnArrow) return;
        [g_btnArrow setTitle:[NSString stringWithFormat:@"⚡ Auto Arrow: %s", g.arrow?"BẬT":"TẮT"] forState:UIControlStateNormal];
        g_btnArrow.backgroundColor = g.arrow ? [UIColor colorWithRed:0.15 green:0.7 blue:0.2 alpha:1] : [UIColor darkGrayColor];
        [g_btnTaiko setTitle:[NSString stringWithFormat:@"🥁 Auto Taiko: %s", g.taiko?"BẬT":"TẮT"] forState:UIControlStateNormal];
        g_btnTaiko.backgroundColor = g.taiko ? [UIColor colorWithRed:0.15 green:0.7 blue:0.2 alpha:1] : [UIColor darkGrayColor];
        [g_btnMini setTitle:[NSString stringWithFormat:@"🔥 Mini+Crazy: %s", g.mini?"BẬT":"TẮT"] forState:UIControlStateNormal];
        g_btnMini.backgroundColor = g.mini ? [UIColor colorWithRed:0.15 green:0.7 blue:0.2 alpha:1] : [UIColor darkGrayColor];
    });
}

static void toggleMenu() {
    dispatch_async(dispatch_get_main_queue(), ^{
        g_menuVisible = !g_menuVisible;
        if(g_menuPanel) g_menuPanel.hidden = !g_menuVisible;
    });
}

static void buildUI(UIView *rootView) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if(g_iconBtn) return;
        
        g_iconBtn = [[UIButton alloc] initWithFrame:CGRectMake(15, 150, 56, 56)];
        g_iconBtn.backgroundColor = [UIColor colorWithRed:0.15 green:0.1 blue:0.25 alpha:0.95];
        g_iconBtn.layer.cornerRadius = 28;
        g_iconBtn.layer.borderWidth = 3;
        g_iconBtn.layer.borderColor = [UIColor colorWithRed:1.0 green:0.25 blue:0.5 alpha:1].CGColor;
        g_iconBtn.layer.zPosition = 9999;
        [g_iconBtn setTitle:@"🎮" forState:UIControlStateNormal];
        g_iconBtn.titleLabel.font = [UIFont systemFontOfSize:28];
        [g_iconBtn addAction:[UIAction actionWithHandler:^(UIAction*){ toggleMenu(); }] forControlEvents:UIControlEventTouchUpInside];
        [rootView addSubview:g_iconBtn];
        
        g_menuPanel = [[UIView alloc] initWithFrame:CGRectMake(85, 70, 290, 340)];
        g_menuPanel.backgroundColor = [UIColor colorWithRed:0.08 green:0.06 blue:0.12 alpha:0.96];
        g_menuPanel.layer.cornerRadius = 20;
        g_menuPanel.layer.borderWidth = 2.5;
        g_menuPanel.layer.borderColor = [UIColor colorWithRed:1.0 green:0.2 blue:0.5 alpha:1].CGColor;
        g_menuPanel.layer.zPosition = 9998;
        
        UIButton* btnClose = [[UIButton alloc] initWithFrame:CGRectMake(240, 8, 40, 32)];
        [btnClose setTitle:@"✕" forState:UIControlStateNormal];
        [btnClose setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btnClose.titleLabel.font = [UIFont boldSystemFontOfSize:20];
        [btnClose addAction:[UIAction actionWithHandler:^(UIAction*){ toggleMenu(); }] forControlEvents:UIControlEventTouchUpInside];
        [g_menuPanel addSubview:btnClose];
        
        UILabel* title = [[UILabel alloc] initWithFrame:CGRectMake(15, 12, 220, 28)];
        title.text = @"✨ AutoDance AU2 ✨";
        title.textColor = [UIColor whiteColor];
        title.font = [UIFont boldSystemFontOfSize:17];
        [g_menuPanel addSubview:title];
        
        g_btnArrow = [[UIButton alloc] initWithFrame:CGRectMake(15, 55, 260, 52)];
        [g_btnArrow setTitle:@"⚡ Auto Arrow: TẮT" forState:UIControlStateNormal];
        [g_btnArrow setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        g_btnArrow.backgroundColor = [UIColor darkGrayColor];
        g_btnArrow.layer.cornerRadius = 14;
        [g_btnArrow addAction:[UIAction actionWithHandler:^(UIAction*){
            g.arrow = !g.arrow; if(!g.arrow) restoreAll(); updateUI();
        }] forControlEvents:UIControlEventTouchUpInside];
        [g_menuPanel addSubview:g_btnArrow];
        
        g_btnTaiko = [[UIButton alloc] initWithFrame:CGRectMake(15, 119, 260, 52)];
        [g_btnTaiko setTitle:@"🥁 Auto Taiko: TẮT" forState:UIControlStateNormal];
        [g_btnTaiko setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        g_btnTaiko.backgroundColor = [UIColor darkGrayColor];
        g_btnTaiko.layer.cornerRadius = 14;
        [g_btnTaiko addAction:[UIAction actionWithHandler:^(UIAction*){
            g.taiko = !g.taiko; if(!g.taiko) restoreAll(); updateUI();
        }] forControlEvents:UIControlEventTouchUpInside];
        [g_menuPanel addSubview:g_btnTaiko];
        
        g_btnMini = [[UIButton alloc] initWithFrame:CGRectMake(15, 183, 260, 52)];
        [g_btnMini setTitle:@"🔥 Mini+Crazy: TẮT" forState:UIControlStateNormal];
        [g_btnMini setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        g_btnMini.backgroundColor = [UIColor darkGrayColor];
        g_btnMini.layer.cornerRadius = 14;
        [g_btnMini addAction:[UIAction actionWithHandler:^(UIAction*){
            g.mini = !g.mini; if(!g.mini) { g.scored.clear(); restoreAll(); } updateUI();
        }] forControlEvents:UIControlEventTouchUpInside];
        [g_menuPanel addSubview:g_btnMini];
        
        UIButton* bReset = [[UIButton alloc] initWithFrame:CGRectMake(15, 247, 260, 46)];
        [bReset setTitle:@"🔄 Tắt hết & Khôi phục" forState:UIControlStateNormal];
        [bReset setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        bReset.backgroundColor = [UIColor colorWithRed:0.9 green:0.15 blue:0.2 alpha:1];
        bReset.layer.cornerRadius = 14;
        [bReset addAction:[UIAction actionWithHandler:^(UIAction*){
            g.arrow = g.taiko = g.mini = false; restoreAll(); updateUI();
        }] forControlEvents:UIControlEventTouchUpInside];
        [g_menuPanel addSubview:bReset];
        
        UILabel* hint = [[UILabel alloc] initWithFrame:CGRectMake(15, 300, 260, 35)];
        hint.text = @"🎮 ẩn/hiện Menu | Vào màn hình chơi → kích hoạt";
        hint.textColor = [UIColor lightGrayColor];
        hint.font = [UIFont systemFontOfSize:11.5];
        hint.textAlignment = NSTextAlignmentCenter;
        [g_menuPanel addSubview:hint];
        
        [rootView addSubview:g_menuPanel];
    });
}

#pragma mark - === GÁN CONTROLLER — HÀM ĐƯỢC GAME GỌI ===
extern "C" {
    void dance_set_ctrl_A(void* p) { 
        g.pA = p; 
        NSLog(@"[EriMod] ✅ GÁN ArrowController: %p", p);
    }
    void dance_set_ctrl_T(void* p) { 
        g.pT = p; 
        NSLog(@"[EriMod] ✅ GÁN TaikoController: %p", p);
    }
    void dance_set_ctrl_D(void* p) { 
        g.pD = p; 
        NSLog(@"[EriMod] ✅ GÁN DanceController: %p", p);
    }
}

#pragma mark - === LẤY WINDOW ĐÚNG CÁCH ===
static UIWindow* getKeyWindow() {
    UIWindow* win = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene* s in [UIApplication sharedApplication].connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]]) {
                for (UIWindow* w in [(UIWindowScene*)s windows]) {
                    if (w.isKeyWindow) return w;
                    if (!win) win = w;
                }
            }
        }
    }
    if (!win) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        win = [UIApplication sharedApplication].keyWindow;
#pragma clang diagnostic pop
    }
    return win;
}

#pragma mark - === VÒNG LẶP ===
static void runLoop() {
    static time_t lA=0,lT=0,lM=0,lC=0;
    static bool logged = false;
    time_t now = time(nullptr);
    
    if (!logged) {
        NSLog(@"[EriMod] === AU2 v23.4 ĐÃ TẢI ===");
        NSLog(@"[EriMod] pA: %p | pT: %p | pD: %p", g.pA, g.pT, g.pD);
        NSLog(@"[EriMod] AutoArrow: %s | AutoTaiko: %s | Mini: %s", 
              g.arrow?"BẬT":"TẮT", g.taiko?"BẬT":"TẮT", g.mini?"BẬT":"TẮT");
        logged = true;
    }
    
    if(g.arrow && g.pA && difftime(now,lA)>=1.5) { lA=now; 
        int n = doArrow();
        if(n>0) NSLog(@"[EriMod] ⚡ AutoArrow: HOÀN HẢO %d nốt!", n);
    }
    if(g.taiko && g.pT && difftime(now,lT)>=1.5) { lT=now; 
        int n = doTaiko();
        if(n>0) NSLog(@"[EriMod] 🥁 AutoTaiko: HOÀN HẢO %d nốt!", n);
    }
    if(g.mini  && g.pD && difftime(now,lM)>=1.5) { lM=now; 
        int n = doMini();
        if(n>0) NSLog(@"[EriMod] 🔥 AutoMini: HOÀN HẢO %d nốt!", n);
    }
    if(g.mini  && g.pD && difftime(now,lC)>=0.3) { lC=now; fixIdx(); doScore(); }
}

#pragma mark - === KHỞI TẠO ===
__attribute__((constructor))
static void init() {
    NSLog(@"[EriMod] ✅ Mod đã nạp — AU2 v23.4");
    
    // Tạo giao diện
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow* win = getKeyWindow();
        if (win && win.rootViewController) {
            buildUI(win.rootViewController.view);
            NSLog(@"[EriMod] ✅ Giao diện đã hiển thị");
        }
    });
    
    // Vòng lặp chính
    dispatch_source_t timer = dispatch_source_create(
        DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW,
                              250000000ULL, 100000000ULL);
    dispatch_source_set_event_handler(timer, ^{ runLoop(); });
    dispatch_resume(timer);
}
