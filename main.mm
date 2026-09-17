//
//  main.mm
//  Eri Mod v7.2 — AU2! v23.4 FULL RELEASE
//  ✅ IL2CPP Verified Offsets | ✅ Menu Nút Bấm Màn Hình
//  ✅ Driver Timer An Toàn | ✅ Auto Khôi Phục Khi Tắt
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "substrate.h"
#include <cmath>
#include <map>
#include <string>
#include <vector>
#include <ctime>

#pragma mark - === IL2CPP TYPES ===

enum eNoteJudgeLevel : int32_t {
    JUDGE_MISS = 0,
    JUDGE_PERFECT = 4
};

#pragma mark - === ABI HELPER — Đúng chuẩn List<T> / Array IL2CPP ===

static inline int32_t il2cppListCount(void* listObj) {
    return listObj ? *(int32_t*)((uint8_t*)listObj + 0x18) : 0;
}
static inline void* il2cppListItem(void* listObj, int32_t i) {
    if (!listObj) return NULL;
    void* items = *(void**)((uint8_t*)listObj + 0x10);
    return items ? *(void**)((uint8_t*)items + 0x20 + i * 8) : NULL;
}

static inline int32_t il2cppArrayCount(void* arr) {
    return arr ? (int32_t)*(int64_t*)((uint8_t*)arr + 0x18) : 0;
}
static inline void* il2cppArrayItem(void* arr, int32_t i) {
    return arr ? *(void**)((uint8_t*)arr + 0x20 + i * 8) : NULL;
}

#pragma mark - === STATE ===

struct SavedField {
    int32_t i32;
    int64_t i64;
    bool b;
    bool isInt;
    bool isBool;
};
struct SavedEntry {
    void* ptr;
    std::map<std::string, SavedField> fields;
};

static struct Global {
    bool uiVisible;
    bool arrowEnabled;
    bool taikoEnabled;
    bool miniCrazyEnabled;
    
    struct Counts {
        int arrow;
        int taiko;
        long long crazyBonus;
    } counts;
    
    time_t lastArrowTick;
    time_t lastTaikoTick;
    time_t lastCrazyTick;
    
    std::map<void*, bool> scoredGroups;
    long long lastKnownScore;
    
    Global()
    : uiVisible(true), arrowEnabled(false), taikoEnabled(false), miniCrazyEnabled(false),
      lastArrowTick(0), lastTaikoTick(0), lastCrazyTick(0), lastKnownScore(0) {
        counts.arrow = counts.taiko = 0;
        counts.crazyBonus = 0;
    }
} g;

static void* g_auditionCtrl = NULL;
static void* g_taikoCtrl    = NULL;
static void* g_dynCtrl      = NULL;
static std::map<std::string, SavedEntry> saved;

#pragma mark - === LƯU / KHÔI PHỤC ===

static void saveAuditionGroup(void* grp, const std::string& key) {
    if (saved.count(key)) return;
    SavedEntry e; e.ptr = grp;
    e.fields["judgeLevel"].i32 = *(int32_t*)((uint8_t*)grp + 64);
    e.fields["judgeLevel"].isInt = true;
    e.fields["isHitBeat"].b = *(bool*)((uint8_t*)grp + 50);
    e.fields["isHitBeat"].isBool = true;
    saved[key] = e;
}
static void saveTaikoNote(void* note, const std::string& key) {
    if (saved.count(key)) return;
    SavedEntry e; e.ptr = note;
    e.fields["isJudgeLevel"].b = *(bool*)((uint8_t*)note + 48);
    e.fields["isJudgeLevel"].isBool = true;
    e.fields["JudgeLevel"].i32 = *(int32_t*)((uint8_t*)note + 56);
    e.fields["JudgeLevel"].isInt = true;
    e.fields["IsHit"].b = *(bool*)((uint8_t*)note + 64);
    e.fields["IsHit"].isBool = true;
    saved[key] = e;
}

static void restoreAll() {
    for (auto& kv : saved) {
        auto& e = kv.second;
        if (!e.ptr) continue;
        for (auto& fv : e.fields) {
            auto& fn = fv.first;
            auto& fd = fv.second;
            if (fn == "judgeLevel" && fd.isInt) *(int32_t*)((uint8_t*)e.ptr + 64) = fd.i32;
            else if (fn == "isHitBeat" && fd.isBool) *(bool*)((uint8_t*)e.ptr + 50) = fd.b;
            else if (fn == "isJudgeLevel" && fd.isBool) *(bool*)((uint8_t*)e.ptr + 48) = fd.b;
            else if (fn == "JudgeLevel" && fd.isInt) *(int32_t*)((uint8_t*)e.ptr + 56) = fd.i32;
            else if (fn == "IsHit" && fd.isBool) *(bool*)((uint8_t*)e.ptr + 64) = fd.b;
        }
    }
    saved.clear();
    g.scoredGroups.clear();
    g.counts.arrow = g.counts.taiko = 0;
    g.counts.crazyBonus = 0;
    NSLog(@"[Eri Mod] ✅ Đã khôi phục tất cả giá trị gốc");
}

#pragma mark - === LOGIC CHÍNH ===

static int applyArrow() {
    if (!g_auditionCtrl) return 0;
    int n = 0;
    void* totalGroup = *(void**)((uint8_t*)g_auditionCtrl + 48);
    int32_t cnt = il2cppListCount(totalGroup);
    for (int32_t i = 0; i < cnt; i++) {
        void* grp = il2cppListItem(totalGroup, i);
        if (!grp) continue;
        auto key = "AG_" + std::to_string((uintptr_t)grp);
        saveAuditionGroup(grp, key);
        *(int32_t*)((uint8_t*)grp + 64) = JUDGE_PERFECT;
        *(bool*)((uint8_t*)grp + 50) = true;
        n++;
    }
    void* cur = *(void**)((uint8_t*)g_auditionCtrl + 64);
    if (cur) {
        auto key = "AG_" + std::to_string((uintptr_t)cur);
        saveAuditionGroup(cur, key);
        *(int32_t*)((uint8_t*)cur + 64) = JUDGE_PERFECT;
        *(bool*)((uint8_t*)cur + 50) = true;
        n++;
    }
    return n;
}

static int applyTaiko() {
    if (!g_taikoCtrl) return 0;
    int n = 0;
    void* noteUIList = *(void**)((uint8_t*)g_taikoCtrl + 128);
    int32_t cnt = il2cppListCount(noteUIList);
    for (int32_t i = 0; i < cnt; i++) {
        void* note = il2cppListItem(noteUIList, i);
        if (!note) continue;
        auto key = "TK_" + std::to_string((uintptr_t)note);
        saveTaikoNote(note, key);
        *(bool*)((uint8_t*)note + 48) = true;
        *(int32_t*)((uint8_t*)note + 56) = JUDGE_PERFECT;
        *(bool*)((uint8_t*)note + 64) = true;
        n++;
    }
    void* queues[3] = {
        *(void**)((uint8_t*)g_taikoCtrl + 256),
        *(void**)((uint8_t*)g_taikoCtrl + 264),
        *(void**)((uint8_t*)g_taikoCtrl + 272)
    };
    for (int q = 0; q < 3; q++) {
        int32_t qc = il2cppListCount(queues[q]);
        for (int32_t i = 0; i < qc; i++) {
            void* note = il2cppListItem(queues[q], i);
            if (!note) continue;
            auto key = "TK_" + std::to_string((uintptr_t)note);
            saveTaikoNote(note, key);
            *(bool*)((uint8_t*)note + 48) = true;
            *(int32_t*)((uint8_t*)note + 56) = JUDGE_PERFECT;
            *(bool*)((uint8_t*)note + 64) = true;
            n++;
        }
    }
    return n;
}

static int fixArrowIndex(void* beatKeys) {
    if (!beatKeys) return 0;
    int32_t idx = *(int32_t*)((uint8_t*)beatKeys + 36);
    void* arrows = *(void**)((uint8_t*)beatKeys + 16);
    int32_t len = il2cppArrayCount(arrows);
    if (idx < 0 || idx >= len) {
        *(int32_t*)((uint8_t*)beatKeys + 36) = 0;
        return 1;
    }
    return 0;
}

static long long updateCrazyScore(void* ctrl) {
    if (!ctrl) return 0;
    int64_t baseScore  = *(int32_t*)((uint8_t*)ctrl + 60);
    int32_t comboLevel = *(int32_t*)((uint8_t*)ctrl + 172);
    int64_t nowScore   = *(int32_t*)((uint8_t*)ctrl + 64);
    g.lastKnownScore = nowScore;
    double mul = 1.0 + (comboLevel - 1) * 0.05;
    void* totalGroup = *(void**)((uint8_t*)ctrl + 96);
    int32_t cnt = il2cppListCount(totalGroup);
    long long added = 0;
    for (int32_t i = 0; i < cnt; i++) {
        void* grp = il2cppListItem(totalGroup, i);
        if (!grp) continue;
        if (g.scoredGroups[grp]) continue;
        if (!*(bool*)((uint8_t*)grp + 33)) continue;
        void* beatKeys = *(void**)((uint8_t*)grp + 24);
        int32_t keyCount = il2cppArrayCount(beatKeys);
        long long gain = (long long)floor(baseScore * mul * std::max(keyCount, 1));
        nowScore += gain;
        added += gain;
        g.scoredGroups[grp] = true;
    }
    *(int32_t*)((uint8_t*)ctrl + 64) = (int32_t)nowScore;
    return added;
}

static long long applyCrazyFix() {
    if (!g_dynCtrl) return 0;
    long long bonus = updateCrazyScore(g_dynCtrl);
    g.counts.crazyBonus += bonus;
    void* totalGroup = *(void**)((uint8_t*)g_dynCtrl + 96);
    int32_t cnt = il2cppListCount(totalGroup);
    for (int32_t i = 0; i < cnt; i++) {
        void* grp = il2cppListItem(totalGroup, i);
        if (!grp) continue;
        void* beatKeys = *(void**)((uint8_t*)grp + 24);
        int32_t kc = il2cppArrayCount(beatKeys);
        for (int32_t k = 0; k < kc; k++) {
            fixArrowIndex(il2cppArrayItem(beatKeys, k));
        }
    }
    return bonus;
}

#pragma mark - === EXTERNAL API ===

extern "C" {
    void eri_toggle_arrow(bool enable) {
        if (g.arrowEnabled == enable) return;
        g.arrowEnabled = enable;
        if (!enable) restoreAll();
        NSLog(@"[Eri Mod] Auto Arrow → %s", enable ? "BẬT ✅" : "TẮT ⭕");
    }
    void eri_toggle_taiko(bool enable) {
        g.taikoEnabled = enable;
        if (!enable) restoreAll();
        NSLog(@"[Eri Mod] Auto Taiko → %s", enable ? "BẬT ✅" : "TẮT ⭕");
    }
    void eri_toggle_mini(bool enable) {
        g.miniCrazyEnabled = enable;
        if (!enable) restoreAll();
        else g.scoredGroups.clear();
        NSLog(@"[Eri Mod] Crazy Fix → %s", enable ? "BẬT ✅" : "TẮT ⭕");
    }
    void eri_set_controllers(void* audition, void* taiko, void* dyn) {
        g_auditionCtrl = audition;
        g_taikoCtrl = taiko;
        g_dynCtrl = dyn;
        NSLog(@"[Eri Mod] Controllers gán ✅: Arrow=%p Taiko=%p Dyn=%p", audition, taiko, dyn);
    }
    void eri_reset_all() {
        restoreAll();
        g.arrowEnabled = g.taikoEnabled = g.miniCrazyEnabled = false;
        NSLog(@"[Eri Mod] Tất cả TẮT & Khôi phục ✅");
    }
}

#pragma mark - === DRIVER TIMER ===

static void eri_driverTick() {
    time_t now = time(NULL);
    if (g.arrowEnabled && difftime(now, g.lastArrowTick) >= 0.15) {
        g.lastArrowTick = now;
        g.counts.arrow = applyArrow();
    }
    if (g.taikoEnabled && difftime(now, g.lastTaikoTick) >= 0.15) {
        g.lastTaikoTick = now;
        g.counts.taiko = applyTaiko();
    }
    if (g.miniCrazyEnabled && difftime(now, g.lastCrazyTick) >= 0.25) {
        g.lastCrazyTick = now;
        applyCrazyFix();
    }
}

#pragma mark - === MENU UI — NÚT BẤM TRÊN MÀN HÌNH ===

static UIWindow* g_menuWindow = nil;
static UIButton* g_btnArrow = nil;
static UIButton* g_btnTaiko = nil;
static UIButton* g_btnCrazy = nil;

static void updateButtonStates() {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (g_btnArrow) {
            [g_btnArrow setTitle:[NSString stringWithFormat:@"⚡ Auto Arrow: %s", g.arrowEnabled ? "BẬT" : "TẮT"] forState:UIControlStateNormal];
            g_btnArrow.backgroundColor = g.arrowEnabled ? [UIColor colorWithRed:0.15 green:0.75 blue:0.2 alpha:1.0] : [UIColor darkGrayColor];
        }
        if (g_btnTaiko) {
            [g_btnTaiko setTitle:[NSString stringWithFormat:@"🥁 Auto Taiko: %s", g.taikoEnabled ? "BẬT" : "TẮT"] forState:UIControlStateNormal];
            g_btnTaiko.backgroundColor = g.taikoEnabled ? [UIColor colorWithRed:0.15 green:0.75 blue:0.2 alpha:1.0] : [UIColor darkGrayColor];
        }
        if (g_btnCrazy) {
            [g_btnCrazy setTitle:[NSString stringWithFormat:@"🔥 Crazy Fix: %s", g.miniCrazyEnabled ? "BẬT" : "TẮT"] forState:UIControlStateNormal];
            g_btnCrazy.backgroundColor = g.miniCrazyEnabled ? [UIColor colorWithRed:0.15 green:0.75 blue:0.2 alpha:1.0] : [UIColor darkGrayColor];
        }
    });
}

static void createMenuUI() {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (g_menuWindow) return;
        
        g_menuWindow = [[UIWindow alloc] initWithFrame:CGRectMake(15, 80, 290, 320)];
        g_menuWindow.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.1 alpha:0.92];
        g_menuWindow.layer.cornerRadius = 14;
        g_menuWindow.layer.borderWidth = 2.5;
        g_menuWindow.layer.borderColor = [UIColor colorWithRed:1.0 green:0.25 blue:0.5 alpha:1.0].CGColor;
        g_menuWindow.windowLevel = UIWindowLevelAlert + 500;
        g_menuWindow.clipsToBounds = YES;
        
        UILabel* title = [[UILabel alloc] initWithFrame:CGRectMake(10, 12, 270, 28)];
        title.text = @"🎮 ERI MOD v7.2 — AU2!";
        title.textColor = [UIColor whiteColor];
        title.font = [UIFont boldSystemFontOfSize:17];
        title.textAlignment = NSTextAlignmentCenter;
        [g_menuWindow addSubview:title];
        
        // Nút Auto Arrow
        g_btnArrow = [[UIButton alloc] initWithFrame:CGRectMake(15, 55, 260, 46)];
        [g_btnArrow setTitle:@"⚡ Auto Arrow: TẮT" forState:UIControlStateNormal];
        [g_btnArrow setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        g_btnArrow.backgroundColor = [UIColor darkGrayColor];
        g_btnArrow.layer.cornerRadius = 10;
        [g_btnArrow addTarget:[NSBlockOperation blockOperationWithBlock:^{
            eri_toggle_arrow(!g.arrowEnabled);
            updateButtonStates();
        }] action:@selector(start) forControlEvents:UIControlEventTouchUpInside];
        [g_menuWindow addSubview:g_btnArrow];
        
        // Nút Auto Taiko
        g_btnTaiko = [[UIButton alloc] initWithFrame:CGRectMake(15, 112, 260, 46)];
        [g_btnTaiko setTitle:@"🥁 Auto Taiko: TẮT" forState:UIControlStateNormal];
        [g_btnTaiko setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        g_btnTaiko.backgroundColor = [UIColor darkGrayColor];
        g_btnTaiko.layer.cornerRadius = 10;
        [g_btnTaiko addTarget:[NSBlockOperation blockOperationWithBlock:^{
            eri_toggle_taiko(!g.taikoEnabled);
            updateButtonStates();
        }] action:@selector(start) forControlEvents:UIControlEventTouchUpInside];
        [g_menuWindow addSubview:g_btnTaiko];
        
        // Nút Crazy Fix
        g_btnCrazy = [[UIButton alloc] initWithFrame:CGRectMake(15, 169, 260, 46)];
        [g_btnCrazy setTitle:@"🔥 Crazy Score Fix: TẮT" forState:UIControlStateNormal];
        [g_btnCrazy setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        g_btnCrazy.backgroundColor = [UIColor darkGrayColor];
        g_btnCrazy.layer.cornerRadius = 10;
        [g_btnCrazy addTarget:[NSBlockOperation blockOperationWithBlock:^{
            eri_toggle_mini(!g.miniCrazyEnabled);
            updateButtonStates();
        }] action:@selector(start) forControlEvents:UIControlEventTouchUpInside];
        [g_menuWindow addSubview:g_btnCrazy];
        
        // Nút Reset Tất Cả
        UIButton* btnReset = [[UIButton alloc] initWithFrame:CGRectMake(15, 226, 260, 42)];
        [btnReset setTitle:@"🔄 Tắt & Khôi phục Tất Cả" forState:UIControlStateNormal];
        [btnReset setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btnReset.backgroundColor = [UIColor colorWithRed:0.85 green:0.25 blue:0.25 alpha:1.0];
        btnReset.layer.cornerRadius = 10;
        [btnReset addTarget:[NSBlockOperation blockOperationWithBlock:^{
            eri_reset_all();
            updateButtonStates();
        }] action:@selector(start) forControlEvents:UIControlEventTouchUpInside];
        [g_menuWindow addSubview:btnReset];
        
        g_menuWindow.hidden = NO;
        [g_menuWindow makeKeyAndVisible];
    });
}

#pragma mark - === INIT ===

__attribute__((constructor))
static void init() {
    NSLog(@"========================================");
    NSLog(@"  🎮 ERI MOD v7.2 — FULL RELEASE");
    NSLog(@"  AU2! v23.4 | IL2CPP Verified");
    NSLog(@"  Menu UI + Driver Timer ✅");
    NSLog(@"========================================");
    
    // Tạo Menu NÚT BẤM ngay khi Mod tải
    createMenuUI();
    
    // Khởi động Driver — không hook trampoline
    dispatch_source_t timer = dispatch_source_create(
        DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW,
                              0.1 * NSEC_PER_SEC, 0.01 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(timer, ^{
        eri_driverTick();
    });
    dispatch_resume(timer);
}
