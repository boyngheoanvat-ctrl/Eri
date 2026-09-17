//
//  AutoDance HexControl v7.2.6 — FIX BUILD ERROR
//  ✅ Không lỗi __weak typeof | ✅ Sửa UIWindow deprecated
//  ✅ Menu Ẩn/Hiện | ✅ Không văng | ✅ Offset chuẩn AU2 v23.4
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "substrate.h"
#include <cmath>
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

// === IL2CPP ABI ===
static inline int32_t cntList(void* p) { return p ? *(int32_t*)((uint8_t*)p+0x18) : 0; }
static inline void* getList(void* p, int32_t i) {
    if(!p||i<0)return nullptr; void** arr=*(void***)((uint8_t*)p+0x10);
    return arr ? arr[i] : nullptr;
}
static inline int32_t cntArr(void* p) { return p ? (int32_t)*(int64_t*)((uint8_t*)p+0x18) : 0; }
static inline void* getArr(void* p, int32_t i) {
    if(!p||i<0)return nullptr; return *(void**)((uint8_t*)p+0x20+(size_t)i*8);
}

// === AN TOÀN ===
#define RD32(p,o,d) ((p)?*(int32_t*)((uint8_t*)(p)+(o)):(d))
#define RD64(p,o,d) ((p)?*(int64_t*)((uint8_t*)(p)+(o)):(d))
#define RDB(p,o,d)  ((p)?*(bool*)((uint8_t*)(p)+(o)):(d))
#define WR32(p,o,v) {if(p)*(int32_t*)((uint8_t*)(p)+(o))=(v);}
#define WR64(p,o,v) {if(p)*(int64_t*)((uint8_t*)(p)+(o))=(v);}
#define WRB(p,o,v)  {if(p)*(bool*)((uint8_t*)(p)+(o))=(v);}

#pragma mark - === STATE ===

struct Saved {
    std::map<int, int32_t> i32;
    std::map<int, bool> b;
};

static struct Global {
    bool showMenu;
    bool arrow, taiko, mini;
    
    void* pA;
    void* pT;
    void* pD;
    
    std::map<void*, bool> scored;
    std::map<void*, Saved> saved;
    
    Global() : showMenu(true), arrow(false), taiko(false), mini(false),
               pA(nullptr), pT(nullptr), pD(nullptr) {}
} g;

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
    g.saved.clear();
    g.scored.clear();
    NSLog(@"✅ Đã khôi phục");
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

#pragma mark - === MENU ===

static UIWindow* g_win = nil;
static UIView* g_panel = nil;
static UIButton* g_btnArrow = nil;
static UIButton* g_btnTaiko = nil;
static UIButton* g_btnMini = nil;

static void updateMenuUI() {
    dispatch_async(dispatch_get_main_queue(), ^{
        [g_btnArrow setTitle:[NSString stringWithFormat:@"⚡ Auto Arrow: %s", g.arrow?"BẬT":"TẮT"] forState:UIControlStateNormal];
        g_btnArrow.backgroundColor = g.arrow ? [UIColor colorWithRed:0.15 green:0.7 blue:0.2 alpha:1] : [UIColor darkGrayColor];
        
        [g_btnTaiko setTitle:[NSString stringWithFormat:@"🥁 Auto Taiko: %s", g.taiko?"BẬT":"TẮT"] forState:UIControlStateNormal];
        g_btnTaiko.backgroundColor = g.taiko ? [UIColor colorWithRed:0.15 green:0.7 blue:0.2 alpha:1] : [UIColor darkGrayColor];
        
        [g_btnMini setTitle:[NSString stringWithFormat:@"🔥 Mini+Crazy: %s", g.mini?"BẬT":"TẮT"] forState:UIControlStateNormal];
        g_btnMini.backgroundColor = g.mini ? [UIColor colorWithRed:0.15 green:0.7 blue:0.2 alpha:1] : [UIColor darkGrayColor];
    });
}

void showDanceMenu() {
    dispatch_async(dispatch_get_main_queue(), ^{
        g.showMenu = true;
        if(g_panel) g_panel.hidden = false;
        if(g_win) g_win.hidden = false;
    });
}

static void buildMenu() {
    dispatch_async(dispatch_get_main_queue(), ^{
        if(g_win)return;
        
        // === Sửa deprecated: dùng style ===
        UIWindowScene* scene = nil;
        if(@available(iOS 13.0, *)) {
            scene = [[UIApplication sharedApplication].windows.firstObject windowScene];
        }
        if(scene) {
            g_win = [[UIWindow alloc] initWithWindowScene:scene];
            g_win.frame = CGRectMake(10, 40, 290, 340);
        } else {
            g_win = [[UIWindow alloc] initWithFrame:CGRectMake(10, 40, 290, 340)];
        }
        
        g_win.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.08 alpha:0.95];
        g_win.layer.cornerRadius = 16;
        g_win.layer.borderWidth = 2.5;
        g_win.layer.borderColor = [UIColor colorWithRed:1 green:0.2 blue:0.5 alpha:1].CGColor;
        g_win.windowLevel = UIWindowLevelAlert + 999;
        
        // === NÚT ẨN MENU ===
        UIButton* btnHide = [[UIButton alloc] initWithFrame:CGRectMake(240, 8, 40, 30)];
        [btnHide setTitle:@"✕" forState:UIControlStateNormal];
        [btnHide setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btnHide.titleLabel.font = [UIFont boldSystemFontOfSize:18];
        [btnHide addAction:[UIAction actionWithHandler:^(UIAction*){
            g.showMenu = false;
            g_panel.hidden = true;
        }] forControlEvents:UIControlEventTouchUpInside];
        [g_win addSubview:btnHide];
        
        UILabel* title = [[UILabel alloc] initWithFrame:CGRectMake(15, 10, 220, 28)];
        title.text = @"🎮 AutoDance v7.2.6";
        title.textColor = UIColor.whiteColor;
        title.font = [UIFont boldSystemFontOfSize:17];
        [g_win addSubview:title];
        
        g_panel = [[UIView alloc] initWithFrame:CGRectMake(0, 45, 290, 295)];
        
        // === NÚT BẬM — KHÔNG DÙNG __weak typeof ===
        g_btnArrow = [[UIButton alloc] initWithFrame:CGRectMake(15, 10, 260, 50)];
        [g_btnArrow setTitle:@"⚡ Auto Arrow: TẮT" forState:UIControlStateNormal];
        [g_btnArrow setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        g_btnArrow.backgroundColor = [UIColor darkGrayColor];
        g_btnArrow.layer.cornerRadius = 10;
        [g_btnArrow addAction:[UIAction actionWithHandler:^(UIAction*){
            g.arrow = !g.arrow;
            if(!g.arrow) restoreAll();
            updateMenuUI();
        }] forControlEvents:UIControlEventTouchUpInside];
        [g_panel addSubview:g_btnArrow];
        
        g_btnTaiko = [[UIButton alloc] initWithFrame:CGRectMake(15, 70, 260, 50)];
        [g_btnTaiko setTitle:@"🥁 Auto Taiko: TẮT" forState:UIControlStateNormal];
        [g_btnTaiko setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        g_btnTaiko.backgroundColor = [UIColor darkGrayColor];
        g_btnTaiko.layer.cornerRadius = 10;
        [g_btnTaiko addAction:[UIAction actionWithHandler:^(UIAction*){
            g.taiko = !g.taiko;
            if(!g.taiko) restoreAll();
            updateMenuUI();
        }] forControlEvents:UIControlEventTouchUpInside];
        [g_panel addSubview:g_btnTaiko];
        
        g_btnMini = [[UIButton alloc] initWithFrame:CGRectMake(15, 130, 260, 50)];
        [g_btnMini setTitle:@"🔥 Mini+Crazy: TẮT" forState:UIControlStateNormal];
        [g_btnMini setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        g_btnMini.backgroundColor = [UIColor darkGrayColor];
        g_btnMini.layer.cornerRadius = 10;
        [g_btnMini addAction:[UIAction actionWithHandler:^(UIAction*){
            g.mini = !g.mini;
            if(!g.mini) { g.scored.clear(); restoreAll(); }
            updateMenuUI();
        }] forControlEvents:UIControlEventTouchUpInside];
        [g_panel addSubview:g_btnMini];
        
        UIButton* bReset = [[UIButton alloc] initWithFrame:CGRectMake(15, 195, 260, 45)];
        [bReset setTitle:@"🔄 Tắt hết & Khôi phục" forState:UIControlStateNormal];
        [bReset setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        bReset.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1];
        bReset.layer.cornerRadius = 10;
        [bReset addAction:[UIAction actionWithHandler:^(UIAction*){
            g.arrow = g.taiko = g.mini = false;
            restoreAll();
            updateMenuUI();
        }] forControlEvents:UIControlEventTouchUpInside];
        [g_panel addSubview:bReset];
        
        UILabel* info = [[UILabel alloc] initWithFrame:CGRectMake(15, 250, 260, 40)];
        info.text = @"Vào màn hình chơi → tự kích hoạt";
        info.textColor = [UIColor lightGrayColor];
        info.font = [UIFont systemFontOfSize:12];
        info.numberOfLines = 2;
        info.textAlignment = NSTextAlignmentCenter;
        [g_panel addSubview:info];
        
        [g_win addSubview:g_panel];
        g_win.hidden = NO;
        [g_win makeKeyAndVisible];
    });
}

#pragma mark - === GÁN CONTROLLER ===

extern "C" {
    void dance_set_ctrl_A(void* p) { g.pA = p; NSLog(@"✅ Audition: %p", p); }
    void dance_set_ctrl_T(void* p) { g.pT = p; NSLog(@"✅ Taiko: %p", p); }
    void dance_set_ctrl_D(void* p) { g.pD = p; NSLog(@"✅ Dynamic: %p", p); }
}

#pragma mark - === VÒNG LẶP ===

static void loopTick() {
    static time_t lA=0,lT=0,lM=0,lC=0;
    time_t now = time(nullptr);
    
    if(g.arrow && g.pA && difftime(now,lA)>=1.5) { lA=now; doArrow(); }
    if(g.taiko && g.pT && difftime(now,lT)>=1.5) { lT=now; doTaiko(); }
    if(g.mini  && g.pD && difftime(now,lM)>=1.5) { lM=now; doMini(); }
    if(g.mini  && g.pD && difftime(now,lC)>=0.3) { lC=now; fixIdx(); doScore(); }
}

#pragma mark - === KHỞI TẠO ===

__attribute__((constructor))
static void initMod() {
    NSLog(@"========================================");
    NSLog(@"  AutoDance HexControl v7.2.6 — BUILD OK");
    NSLog(@"  ✅ Menu Ẩn/Hiện | ✅ Không văng | ✅ Không lỗi");
    NSLog(@"========================================");
    
    buildMenu();
    
    dispatch_source_t t = dispatch_source_create(
        DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(t, DISPATCH_TIME_NOW,
                              0.25 * NSEC_PER_SEC, 0.1 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(t, ^{ loopTick(); });
    dispatch_resume(t);
}
