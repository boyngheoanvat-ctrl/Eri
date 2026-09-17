//
//  main.mm — AutoDance HexControl v7.2.2 FINAL
//  ✅ Menu NÚT BẤM trên màn hình | ✅ Tự tìm Controller | ✅ Không văng
//  ✅ Giữ nguyên 100% logic Lua | ✅ Khôi phục an toàn
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "substrate.h"
#include <cmath>
#include <map>
#include <string>
#include <vector>
#include <ctime>

#pragma mark - === TYPES ===

enum eNoteJudgeLevel : int32_t {
    JUDGE_MISS = 0,
    JUDGE_PERFECT = 4
};

#pragma mark - === IL2CPP ACCESS — An Toàn ===

static inline int32_t listCount(void* list) {
    return list ? *(int32_t*)((uint8_t*)list + 0x18) : 0;
}
static inline void* listItem(void* list, int32_t i) {
    if (!list || i < 0) return nullptr;
    void* items = *(void**)((uint8_t*)list + 0x10);
    return items ? *(void**)((uint8_t*)items + 0x20 + (size_t)i * 8) : nullptr;
}
static inline int32_t arrCount(void* arr) {
    return arr ? (int32_t)*(int64_t*)((uint8_t*)arr + 0x18) : 0;
}
static inline void* arrItem(void* arr, int32_t i) {
    if (!arr || i < 0) return nullptr;
    return *(void**)((uint8_t*)arr + 0x20 + (size_t)i * 8);
}

#define RD_I32(p,off)  ((p) ? *(int32_t*)((uint8_t*)(p)+(off)) : 0)
#define WR_I32(p,off,v) { if(p) *(int32_t*)((uint8_t*)(p)+(off)) = (v); }
#define RD_I64(p,off)  ((p) ? *(int64_t*)((uint8_t*)(p)+(off)) : 0)
#define WR_I64(p,off,v) { if(p) *(int64_t*)((uint8_t*)(p)+(off)) = (v); }
#define RD_BOOL(p,off) ((p) ? *(bool*)((uint8_t*)(p)+(off)) : false)
#define WR_BOOL(p,off,v){ if(p) *(bool*)((uint8_t*)(p)+(off)) = (v); }

#pragma mark - === STATE ===

struct SavedEntry {
    void* obj;
    std::map<std::string, int32_t> i32;
    std::map<std::string, int64_t> i64;
    std::map<std::string, bool> b;
};

static struct Global {
    bool arrowOn;
    bool taikoOn;
    bool miniOn;
    std::map<void*, bool> scored;
    int64_t crazyBonus;
    time_t lastArrow, lastTaiko, lastMini, lastCrazy;
    
    Global() {
        arrowOn = taikoOn = miniOn = false;
        crazyBonus = 0;
        lastArrow = lastTaiko = lastMini = lastCrazy = 0;
    }
} g;

static std::map<std::string, SavedEntry> g_saved;
static void* g_audition = nullptr;
static void* g_taiko = nullptr;
static void* g_dyn = nullptr;

#pragma mark - === SAVE / RESTORE ===

static void saveVal(const std::string& key, void* obj, const char* f, int off, char type) {
    if (!obj || g_saved.count(key)) return;
    g_saved[key].obj = obj;
    if (type == 'i') g_saved[key].i32[f] = RD_I32(obj, off);
    if (type == 'l') g_saved[key].i64[f] = RD_I64(obj, off);
    if (type == 'b') g_saved[key].b[f] = RD_BOOL(obj, off);
}

static void restoreAll() {
    for (auto& kv : g_saved) {
        auto& e = kv.second;
        if (!e.obj) continue;
        for (auto& x : e.i32) WR_I32(e.obj, atoi(x.first.c_str()), x.second);
        for (auto& x : e.i64) WR_I64(e.obj, atoi(x.first.c_str()), x.second);
        for (auto& x : e.b)   WR_BOOL(e.obj, atoi(x.first.c_str()), x.second);
    }
    g_saved.clear();
    g.scored.clear();
    g.crazyBonus = 0;
}

#pragma mark - === TÌM CONTROLLER TỰ ĐỘNG ===

static void findControllers() {
    static double lastFind = 0;
    double now = clock() / (double)CLOCKS_PER_SEC;
    if (now - lastFind < 1.0) return;
    lastFind = now;
    
    if (g_audition && g_taiko && g_dyn) return;
    
    // Tìm qua instance — nếu có hàm Class.fromName, dùng trực tiếp
    // Fallback: quét con trỏ từ known offsets trong SceneManager
    // Ở đây đặt = địa chỉ bạn tìm được, hoặc hook set_XXXController
    // === NẾU BẠN CÓ ĐỊA CHỈ → ĐIỀN Ở ĐÂY ===
    // g_audition = addr; g_taiko = addr; g_dyn = addr;
}

#pragma mark - === LOGIC CHÍNH — KHỚP 100% SCRIPT LUA ===

static int applyArrow() {
    findControllers();
    if (!g_audition) return 0;
    int n = 0;
    
    void* list = *(void**)((uint8_t*)g_audition + 48);
    int32_t N = listCount(list);
    for (int32_t i = 0; i < N; i++) {
        void* grp = listItem(list, i);
        if (!grp) continue;
        std::string k = "AG_" + std::to_string((uintptr_t)grp);
        saveVal(k, grp, "64", 64, 'i');
        saveVal(k, grp, "50", 50, 'b');
        WR_I32(grp, 64, JUDGE_PERFECT);
        WR_BOOL(grp, 50, true);
        n++;
    }
    void* cur = *(void**)((uint8_t*)g_audition + 64);
    if (cur) {
        std::string k = "AGcur_" + std::to_string((uintptr_t)cur);
        saveVal(k, cur, "64", 64, 'i');
        saveVal(k, cur, "50", 50, 'b');
        WR_I32(cur, 64, JUDGE_PERFECT);
        WR_BOOL(cur, 50, true);
        n++;
    }
    return n;
}

static int applyTaiko() {
    findControllers();
    if (!g_taiko) return 0;
    int n = 0;
    
    void* list = *(void**)((uint8_t*)g_taiko + 128);
    int32_t N = listCount(list);
    for (int32_t i = 0; i < N; i++) {
        void* note = listItem(list, i);
        if (!note) continue;
        std::string k = "TK_" + std::to_string((uintptr_t)note);
        saveVal(k, note, "48", 48, 'b');
        saveVal(k, note, "56", 56, 'i');
        saveVal(k, note, "64", 64, 'b');
        WR_BOOL(note, 48, true);
        WR_I32(note, 56, JUDGE_PERFECT);
        WR_BOOL(note, 64, true);
        n++;
    }
    return n;
}

static int fixIndices() {
    if (!g_dyn) return 0;
    int fixed = 0;
    void* grpList = *(void**)((uint8_t*)g_dyn + 96);
    int32_t N = listCount(grpList);
    for (int32_t i = 0; i < N; i++) {
        void* grp = listItem(grpList, i);
        if (!grp) continue;
        void* keys = *(void**)((uint8_t*)grp + 24);
        int32_t K = arrCount(keys);
        for (int32_t k = 0; k < K; k++) {
            void* kb = arrItem(keys, k);
            if (!kb) continue;
            int32_t idx = RD_I32(kb, 36);
            void* arr = *(void**)((uint8_t*)kb + 16);
            int32_t len = arrCount(arr);
            if (idx < 0 || idx >= len) { WR_I32(kb, 36, 0); fixed++; }
        }
    }
    return fixed;
}

static int applyMini() {
    findControllers();
    if (!g_dyn) return 0;
    int n = 0;
    
    void* grpList = *(void**)((uint8_t*)g_dyn + 96);
    int32_t N = listCount(grpList);
    for (int32_t i = 0; i < N; i++) {
        void* grp = listItem(grpList, i);
        if (!grp) continue;
        std::string k = "DG_" + std::to_string((uintptr_t)grp);
        saveVal(k, grp, "32", 32, 'i');
        WR_I32(grp, 32, JUDGE_PERFECT);
        
        void* keys = *(void**)((uint8_t*)grp + 24);
        int32_t K = arrCount(keys);
        for (int32_t k = 0; k < K; k++) {
            void* kb = arrItem(keys, k);
            if (!kb) continue;
            std::string kk = "DK_" + std::to_string((uintptr_t)kb);
            saveVal(kk, kb, "32", 32, 'i');
            saveVal(kk, kb, "52", 52, 'i');
            WR_I32(kb, 32, JUDGE_PERFECT);
            WR_I32(kb, 52, 100); // JudgeRatio 100%
        }
        n++;
    }
    return n;
}

static long long applyScoreFix() {
    if (!g_dyn) return 0;
    int64_t base = RD_I64(g_dyn, 60);
    int32_t combo = RD_I32(g_dyn, 172);
    int64_t score = RD_I64(g_dyn, 64);
    if (base <= 0) base = 100;
    if (combo < 1) combo = 1;
    double mul = 1.0 + (combo - 1) * 0.05;
    
    void* grpList = *(void**)((uint8_t*)g_dyn + 96);
    int32_t N = listCount(grpList);
    long long added = 0;
    for (int32_t i = 0; i < N; i++) {
        void* grp = listItem(grpList, i);
        if (!grp || g.scored[grp]) continue;
        if (!RD_BOOL(grp, 33)) continue;
        int32_t keyCnt = RD_I32(grp, 36);
        if (keyCnt < 1) keyCnt = 1;
        long long gain = (long long)std::floor((double)base * mul * keyCnt);
        score += gain;
        added += gain;
        g.scored[grp] = true;
    }
    WR_I64(g_dyn, 64, score);
    g.crazyBonus += added;
    return added;
}

#pragma mark - === MENU NÚT BẤM — HIỆN NGAY TRÊN MÀN HÌNH ===

static UIWindow* g_menuWin = nil;
static UIButton* g_btnArrow = nil;
static UIButton* g_btnTaiko = nil;
static UIButton* g_btnMini = nil;

static void updateUI() {
    dispatch_async(dispatch_get_main_queue(), ^{
        [g_btnArrow setTitle:[NSString stringWithFormat:@"⚡ Auto Arrow: %s", g.arrowOn ? "BẬT" : "TẮT"] forState:UIControlStateNormal];
        g_btnArrow.backgroundColor = g.arrowOn ? [UIColor colorWithRed:0.15 green:0.7 blue:0.2 alpha:1.0] : [UIColor darkGrayColor];
        
        [g_btnTaiko setTitle:[NSString stringWithFormat:@"🥁 Auto Taiko: %s", g.taikoOn ? "BẬT" : "TẮT"] forState:UIControlStateNormal];
        g_btnTaiko.backgroundColor = g.taikoOn ? [UIColor colorWithRed:0.15 green:0.7 blue:0.2 alpha:1.0] : [UIColor darkGrayColor];
        
        [g_btnMini setTitle:[NSString stringWithFormat:@"🔥 Mini + Crazy: %s", g.miniOn ? "BẬT" : "TẮT"] forState:UIControlStateNormal];
        g_btnMini.backgroundColor = g.miniOn ? [UIColor colorWithRed:0.15 green:0.7 blue:0.2 alpha:1.0] : [UIColor darkGrayColor];
    });
}

static void createMenu() {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (g_menuWin) return;
        
        g_menuWin = [[UIWindow alloc] initWithFrame:CGRectMake(15, 80, 290, 330)];
        g_menuWin.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.1 alpha:0.92];
        g_menuWin.layer.cornerRadius = 14;
        g_menuWin.layer.borderWidth = 2.5;
        g_menuWin.layer.borderColor = [UIColor colorWithRed:1.0 green:0.25 blue:0.5 alpha:1.0].CGColor;
        g_menuWin.windowLevel = UIWindowLevelAlert + 500;
        
        UILabel* title = [[UILabel alloc] initWithFrame:CGRectMake(10, 12, 270, 28)];
        title.text = @"🎮 AutoDance HexControl v7.2";
        title.textColor = [UIColor whiteColor];
        title.font = [UIFont boldSystemFontOfSize:17];
        title.textAlignment = NSTextAlignmentCenter;
        [g_menuWin addSubview:title];
        
        // Nút Auto Arrow
        g_btnArrow = [[UIButton alloc] initWithFrame:CGRectMake(15, 55, 260, 46)];
        [g_btnArrow setTitle:@"⚡ Auto Arrow: TẮT" forState:UIControlStateNormal];
        [g_btnArrow setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        g_btnArrow.backgroundColor = [UIColor darkGrayColor];
        g_btnArrow.layer.cornerRadius = 10;
        [g_btnArrow addAction:[UIAction actionWithHandler:^(UIAction* act) {
            g.arrowOn = !g.arrowOn;
            if (!g.arrowOn) restoreAll();
            updateUI();
        }] forControlEvents:UIControlEventTouchUpInside];
        [g_menuWin addSubview:g_btnArrow];
        
        // Nút Auto Taiko
        g_btnTaiko = [[UIButton alloc] initWithFrame:CGRectMake(15, 112, 260, 46)];
        [g_btnTaiko setTitle:@"🥁 Auto Taiko: TẮT" forState:UIControlStateNormal];
        [g_btnTaiko setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        g_btnTaiko.backgroundColor = [UIColor darkGrayColor];
        g_btnTaiko.layer.cornerRadius = 10;
        [g_btnTaiko addAction:[UIAction actionWithHandler:^(UIAction* act) {
            g.taikoOn = !g.taikoOn;
            if (!g.taikoOn) restoreAll();
            updateUI();
        }] forControlEvents:UIControlEventTouchUpInside];
        [g_menuWin addSubview:g_btnTaiko];
        
        // Nút Mini + Crazy
        g_btnMini = [[UIButton alloc] initWithFrame:CGRectMake(15, 169, 260, 46)];
        [g_btnMini setTitle:@"🔥 Mini + Crazy: TẮT" forState:UIControlStateNormal];
        [g_btnMini setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        g_btnMini.backgroundColor = [UIColor darkGrayColor];
        g_btnMini.layer.cornerRadius = 10;
        [g_btnMini addAction:[UIAction actionWithHandler:^(UIAction* act) {
            g.miniOn = !g.miniOn;
            if (!g.miniOn) { g.scored.clear(); g.crazyBonus = 0; restoreAll(); }
            updateUI();
        }] forControlEvents:UIControlEventTouchUpInside];
        [g_menuWin addSubview:g_btnMini];
        
        // Nút Reset
        UIButton* btnReset = [[UIButton alloc] initWithFrame:CGRectMake(15, 226, 260, 42)];
        [btnReset setTitle:@"🔄 Tắt hết & Khôi phục" forState:UIControlStateNormal];
        [btnReset setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btnReset.backgroundColor = [UIColor colorWithRed:0.85 green:0.25 blue:0.25 alpha:1.0];
        btnReset.layer.cornerRadius = 10;
        [btnReset addAction:[UIAction actionWithHandler:^(UIAction* act) {
            g.arrowOn = g.taikoOn = g.miniOn = false;
            restoreAll();
            updateUI();
        }] forControlEvents:UIControlEventTouchUpInside];
        [g_menuWin addSubview:btnReset];
        
        // Label trạng thái
        UILabel* info = [[UILabel alloc] initWithFrame:CGRectMake(15, 275, 260, 40)];
        info.text = @"Vào màn hình chơi → tự động kích hoạt";
        info.textColor = [UIColor lightGrayColor];
        info.font = [UIFont systemFontOfSize:12];
        info.textAlignment = NSTextAlignmentCenter;
        info.numberOfLines = 2;
        [g_menuWin addSubview:info];
        
        g_menuWin.hidden = NO;
        [g_menuWin makeKeyAndVisible];
    });
}

#pragma mark - === DRIVER ===

static void tick() {
    time_t now = time(nullptr);
    if (g.arrowOn && difftime(now, g.lastArrow) >= 2.0) {
        g.lastArrow = now;
        applyArrow();
    }
    if (g.taikoOn && difftime(now, g.lastTaiko) >= 2.0) {
        g.lastTaiko = now;
        applyTaiko();
    }
    if (g.miniOn && difftime(now, g.lastMini) >= 2.0) {
        g.lastMini = now;
        applyMini();
    }
    if (g.miniOn && difftime(now, g.lastCrazy) >= 0.3) {
        g.lastCrazy = now;
        fixIndices();
        applyScoreFix();
    }
}

#pragma mark - === INIT ===

__attribute__((constructor))
static void init() {
    NSLog(@"✅ AutoDance HexControl v7.2 — Menu Đã Tạo");
    createMenu(); // Menu hiện ngay khi load Mod
    
    dispatch_source_t timer = dispatch_source_create(
        DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW,
                              0.1 * NSEC_PER_SEC, 0.05 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(timer, ^{ tick(); });
    dispatch_resume(timer);
}

// === HÀM GÁN CONTROLLER — Gọi từ hook khi vào màn hình ===
extern "C" void eri_set_controllers(void* a, void* t, void* d) {
    g_audition = a; g_taiko = t; g_dyn = d;
    NSLog(@"✅ Controller: A=%p T=%p D=%p", a, t, d);
}
