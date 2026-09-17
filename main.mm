//
//  AutoDance AU2 — FIXED BUILD ERRORS
//  ✅ Đầy đủ import | ✅ Khai báo đúng biến toàn cục
//  ✅ Biên dịch trên GitHub Actions không lỗi
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <dispatch/dispatch.h>   // ⬅️ THIẾU DÒNG NÀY GÂY LỖI
#import "substrate.h"
#include <map>
#include <string>
#include <ctime>

#pragma mark - === OFFSET CHUẨN v23.4 ===

enum JudgeLv : int32_t {
    MISS = 0, PERFECT = 4
};

struct Off {
    static const uint32_t A_listGrp = 0x48;
    static const uint32_t A_curGrp  = 0x64;
    static const uint32_t G_judge   = 0x40;
    static const uint32_t G_isHit   = 0x32;
    static const uint32_t T_listNote= 0x80;
    static const uint32_t TN_isJL   = 0x30;
    static const uint32_t TN_JL     = 0x38;
    static const uint32_t TN_isHit  = 0x40;
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

// === AN TOÀN ===
static inline int32_t cntList(void* p) { return p ? *(int32_t*)((uint8_t*)p+0x18) : 0; }
static inline void* getList(void* p, int32_t i) {
    if(!p||i<0)return nullptr; void** arr=*(void***)((uint8_t*)p+0x10);
    return arr && i < cntList(p) ? arr[i] : nullptr;
}
static inline int32_t cntArr(void* p) { return p ? (int32_t)*(int64_t*)((uint8_t*)p+0x18) : 0; }
static inline void* getArr(void* p, int32_t i) {
    if(!p||i<0)return nullptr; return i < cntArr(p) ? *(void**)((uint8_t*)p+0x20+(size_t)i*8) : nullptr;
}

#define RD32(p,o,d) ((p)?*(int32_t*)((uint8_t*)(p)+(o)):(d))
#define RD64(p,o,d) ((p)?*(int64_t*)((uint8_t*)(p)+(o)):(d))
#define RDB(p,o,d)  ((p)?*(bool*)((uint8_t*)(p)+(o)):(d))
#define WR32(p,o,v) do{if(p)*(int32_t*)((uint8_t*)(p)+(o))=(v);}while(0)
#define WR64(p,o,v) do{if(p)*(int64_t*)((uint8_t*)(p)+(o))=(v);}while(0)
#define WRB(p,o,v)  do{if(p)*(bool*)((uint8_t*)(p)+(o))=(v);}while(0)

#pragma mark - === STATE ===

struct Saved {
    std::map<int, int32_t> i32;
    std::map<int, bool> b;
};

static struct Global {
    bool didInitUI;
    bool menuVisible;
    bool arrow, taiko, mini;
    
    void* pA;
    void* pT;
    void* pD;
    
    std::map<void*, bool> scored;
    std::map<void*, Saved> saved;
    
    Global() : didInitUI(false), menuVisible(true),
               arrow(false), taiko(false), mini(false),
               pA(nullptr), pT(nullptr), pD(nullptr) {}
} g;

// === KHAI BÁO BIẾN TOÀN CỤC UI ===
static UIWindow* g_topWindow = nil;
static UIButton* g_iconBtn = nil;
static UIView* g_menuPanel = nil;
static UIButton* g_btnArrow = nil;
static UIButton* g_btnTaiko = nil;
static UIButton* g_btnMini = nil;

#pragma mark - === LƯU / KHÔI PHỤC ===

static void saveI32(void* obj, int off) {
    if(!obj||g.saved.count(obj))return;
    g.saved[obj].i32[off] = RD32(obj,off,0);
}
static void saveB(void* obj, int off) {
    if(!obj||g.saved.count(obj))return;
    g.saved[obj].b[off] = RDB(obj,off,false);
}

static void restoreAll() {
    for(auto& kv : g.saved) {
        for(auto& x : kv.second.i32) WR32(kv.first, x.first, x.second);
        for(auto& x : kv.second.b)   WRB(kv.first, x.first, x.second);
    }
    g.saved.clear(); g.scored.clear();
}

#pragma mark - === LOGIC CHÍNH ===

static int doArrow() {
    if(!g.pA) return 0;
    int n=0;
    void* list = *(void**)((uint8_t*)g.pA + Off::A_listGrp);
    for(int i=0,N=cntList(list);i<N;i++){
        void* grp=getList(list,i); if(!grp)continue;
        saveI32(grp, Off::G_judge); saveB(grp, Off::G_isHit);
        WR32(grp, Off::G_judge, PERFECT); WRB(grp, Off::G_isHit, true);
        n++;
    }
    void* cur = *(void**)((uint8_t*)g.pA + Off::A_curGrp);
    if(cur){
        saveI32(cur, Off::G_judge); saveB(cur, Off::G_isHit);
        WR32(cur, Off::G_judge, PERFECT); WRB(cur, Off::G_isHit, true);
        n++;
    }
    return n;
}

static int doTaiko() {
    if(!g.pT) return 0;
    int n=0;
    void* list = *(void**)((uint8_t*)g.pT + Off::T_listNote);
    for(int i=0,N=cntList(list);i<N;i++){
        void* note=getList(list,i); if(!note)continue;
        saveB(note, Off::TN_isJL); saveI32(note, Off::TN_JL); saveB(note, Off::TN_isHit);
        WRB(note, Off::TN_isJL, true); WR32(note, Off::TN_JL, PERFECT); WRB(note, Off::TN_isHit, true);
        n++;
    }
    return n;
}

static int fixIdx() {
    if(!g.pD) return 0;
    int fix=0;
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

static long long doScore() {
    if(!g.pD) return 0;
    int64_t base=RD64(g.pD,Off::D_base,100);
    int combo=RD32(g.pD,Off::D_combo,1);
    int64_t score=RD64(g.pD,Off::D_score,0);
    double mul=1.0+std::max(combo-1,0)*0.05;
    void* list = *(void**)((uint8_t*)g.pD + Off::D_listGrp);
    long long add=0;
    for(int i=0,N=cntList(list);i<N;i++){
        void* grp=getList(list,i);
        if(!grp||g.scored[grp])continue;
        if(!RDB(grp,Off::DG_allHit,false))continue;
        int kcnt=RD32(grp,Off::DG_idx,1); if(kcnt<1)kcnt=1;
        long long gain=(long long)std::floor((double)base*mul*kcnt);
        score+=gain; add+=gain; g.scored[grp]=true;
    }
    WR64(g.pD, Off::D_score, score);
    return add;
}

static int doMini() {
    if(!g.pD) return 0;
    int n=0;
    void* list = *(void**)((uint8_t*)g.pD + Off::D_listGrp);
    for(int i=0,N=cntList(list);i<N;i++){
        void* grp=getList(list,i); if(!grp)continue;
        void* keys = *(void**)((uint8_t*)grp + Off::DG_keys);
        for(int k=0,K=cntArr(keys);k<K;k++){
            void* kb=getArr(keys,k); if(!kb)continue;
            WR32(kb, Off::OB_JL, PERFECT);
            WR32(kb, Off::OB_ratio, 100);
        }
        n++;
    }
    return n;
}

#pragma mark - === UI HELPERS ===

static void updateMenuUI() {
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
        g.menuVisible = !g.menuVisible;
        if(g_menuPanel) g_menuPanel.hidden = !g.menuVisible;
    });
}

static void buildUI() {
    dispatch_async(dispatch_get_main_queue(), ^{
        if(g.didInitUI) return;
        
        CGRect scr = [UIScreen mainScreen].bounds;
        
        // Tạo Window cao nhất
        g_topWindow = [[UIWindow alloc] initWithFrame:scr];
        g_topWindow.windowLevel = UIWindowLevelStatusBar + 5000;
        g_topWindow.backgroundColor = [UIColor clearColor];
        
        UIViewController* vc = [[UIViewController alloc] init];
        vc.view.backgroundColor = [UIColor clearColor];
        g_topWindow.rootViewController = vc;
        
        [g_topWindow makeKeyAndVisible];
        [g_topWindow layoutIfNeeded];
        
        g.didInitUI = true;
        
        // === ICON ===
        g_iconBtn = [[UIButton alloc] initWithFrame:CGRectMake(15, 200, 56, 56)];
        g_iconBtn.backgroundColor = [UIColor colorWithRed:0.15 green:0.1 blue:0.25 alpha:0.95];
        g_iconBtn.layer.cornerRadius = 28;
        g_iconBtn.layer.borderWidth = 3;
        g_iconBtn.layer.borderColor = [UIColor colorWithRed:1.0 green:0.25 blue:0.5 alpha:1].CGColor;
        g_iconBtn.layer.zPosition = MAXFLOAT;
        [g_iconBtn setTitle:@"🎮" forState:UIControlStateNormal];
        g_iconBtn.titleLabel.font = [UIFont systemFontOfSize:28];
        [g_iconBtn addAction:[UIAction actionWithHandler:^(UIAction*){ toggleMenu(); }] forControlEvents:UIControlEventTouchUpInside];
        [vc.view addSubview:g_iconBtn];
        
        // === MENU ===
        g_menuPanel = [[UIView alloc] initWithFrame:CGRectMake(85, 120, 290, 340)];
        g_menuPanel.backgroundColor = [UIColor colorWithRed:0.08 green:0.06 blue:0.12 alpha:0.96];
        g_menuPanel.layer.cornerRadius = 20;
        g_menuPanel.layer.borderWidth = 2.5;
        g_menuPanel.layer.borderColor = [UIColor colorWithRed:1.0 green:0.2 blue:0.5 alpha:1].CGColor;
        g_menuPanel.layer.zPosition = MAXFLOAT - 1;
        
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
            g.arrow = !g.arrow; if(!g.arrow) restoreAll(); updateMenuUI();
        }] forControlEvents:UIControlEventTouchUpInside];
        [g_menuPanel addSubview:g_btnArrow];
        
        g_btnTaiko = [[UIButton alloc] initWithFrame:CGRectMake(15, 119, 260, 52)];
        [g_btnTaiko setTitle:@"🥁 Auto Taiko: TẮT" forState:UIControlStateNormal];
        [g_btnTaiko setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        g_btnTaiko.backgroundColor = [UIColor darkGrayColor];
        g_btnTaiko.layer.cornerRadius = 14;
        [g_btnTaiko addAction:[UIAction actionWithHandler:^(UIAction*){
            g.taiko = !g.taiko; if(!g.taiko) restoreAll(); updateMenuUI();
        }] forControlEvents:UIControlEventTouchUpInside];
        [g_menuPanel addSubview:g_btnTaiko];
        
        g_btnMini = [[UIButton alloc] initWithFrame:CGRectMake(15, 183, 260, 52)];
        [g_btnMini setTitle:@"🔥 Mini+Crazy: TẮT" forState:UIControlStateNormal];
        [g_btnMini setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        g_btnMini.backgroundColor = [UIColor darkGrayColor];
        g_btnMini.layer.cornerRadius = 14;
        [g_btnMini addAction:[UIAction actionWithHandler:^(UIAction*){
            g.mini = !g.mini; if(!g.mini) { g.scored.clear(); restoreAll(); } updateMenuUI();
        }] forControlEvents:UIControlEventTouchUpInside];
        [g_menuPanel addSubview:g_btnMini];
        
        UIButton* bReset = [[UIButton alloc] initWithFrame:CGRectMake(15, 247, 260, 46)];
        [bReset setTitle:@"🔄 Tắt hết & Khôi phục" forState:UIControlStateNormal];
        [bReset setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        bReset.backgroundColor = [UIColor colorWithRed:0.9 green:0.15 blue:0.2 alpha:1];
        bReset.layer.cornerRadius = 14;
        [bReset addAction:[UIAction actionWithHandler:^(UIAction*){
            g.arrow = g.taiko = g.mini = false; restoreAll(); updateMenuUI();
        }] forControlEvents:UIControlEventTouchUpInside];
        [g_menuPanel addSubview:bReset];
        
        UILabel* hint = [[UILabel alloc] initWithFrame:CGRectMake(15, 300, 260, 35)];
        hint.text = @"🎮 ẩn/hiện Menu | Vào màn hình chơi → kích hoạt";
        hint.textColor = [UIColor lightGrayColor];
        hint.font = [UIFont systemFontOfSize:11.5];
        hint.textAlignment = NSTextAlignmentCenter;
        [g_menuPanel addSubview:hint];
        
        [vc.view addSubview:g_menuPanel];
    });
}

#pragma mark - === GÁN CONTROLLER ===

extern "C" {
    void dance_set_ctrl_A(void* p) { g.pA = p; }
    void dance_set_ctrl_T(void* p) { g.pT = p; }
    void dance_set_ctrl_D(void* p) { g.pD = p; }
}

#pragma mark - === VÒNG LẶP ===

static void loopTick() {
    static time_t lA=0,lT=0,lM=0,lC=0;
    time_t now = time(nullptr);
    
    if(!g.didInitUI) { buildUI(); return; }
    
    if(g.arrow && g.pA && difftime(now,lA)>=1.5) { lA=now; doArrow(); }
    if(g.taiko && g.pT && difftime(now,lT)>=1.5) { lT=now; doTaiko(); }
    if(g.mini  && g.pD && difftime(now,lM)>=1.5) { lM=now; doMini(); }
    if(g.mini  && g.pD && difftime(now,lC)>=0.3) { lC=now; fixIdx(); doScore(); }
}

#pragma mark - === KHỞI TẠO ===

__attribute__((constructor))
static void initMod() {
    dispatch_source_t timer = dispatch_source_create(
        DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW,
                              0.25 * NSEC_PER_SEC, 0.25 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(timer, ^{ loopTick(); });
    dispatch_resume(timer);
}
