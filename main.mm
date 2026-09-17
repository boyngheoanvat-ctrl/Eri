//
//  main.mm
//  Eri Mod v7.2 — AU2! v23.4 IL2CPP Verified
//  Offsets từ metadata runtime HotFix.dll ✅
//  Không hook shared trampoline → Dùng NSTimer driver
//

#import <Foundation/Foundation.h>
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

// List<T>: _items @0x10, _size @0x18
static inline int32_t il2cppListCount(void* listObj) {
    return listObj ? *(int32_t*)((uint8_t*)listObj + 0x18) : 0;
}
static inline void* il2cppListItem(void* listObj, int32_t i) {
    if (!listObj) return NULL;
    void* items = *(void**)((uint8_t*)listObj + 0x10);
    return items ? *(void**)((uint8_t*)items + 0x20 + i * 8) : NULL;
}

// Array: max_length @0x18, items @0x20
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

// Con trỏ Controller — gán khi vào màn hình
static void* g_auditionCtrl = NULL;   // Dance.AuditionArrowsController
static void* g_taikoCtrl    = NULL;   // DanceTaikoController
static void* g_dynCtrl      = NULL;   // Dance.DynamicArrowsController

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

#pragma mark - === LOGIC CHÍNH — Offset chuẩn từ metadata ===

static int applyArrow() {
    if (!g_auditionCtrl) return 0;
    int n = 0;
    
    // List<AuditionGroup> totalGroup @48
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
    // currGroup @64
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
    
    // List<UI_TaikoNoteBase> noteUIList @128
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
    // Queue nốt đang chờ @256 / 264 / 272
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
    int32_t idx = *(int32_t*)((uint8_t*)beatKeys + 36);   // curArrowsIndex
    void* arrows = *(void**)((uint8_t*)beatKeys + 16);     // DynamicArrows[]
    int32_t len = il2cppArrayCount(arrows);
    if (idx < 0 || idx >= len) {
        *(int32_t*)((uint8_t*)beatKeys + 36) = 0;
        return 1;
    }
    return 0;
}

static long long updateCrazyScore(void* ctrl) {
    if (!ctrl) return 0;
    
    int64_t baseScore  = *(int32_t*)((uint8_t*)ctrl + 60);   // noteBaseScore
    int32_t comboLevel = *(int32_t*)((uint8_t*)ctrl + 172);  // curComboLevel
    int64_t nowScore   = *(int32_t*)((uint8_t*)ctrl + 64);    // nowTotalScore
    g.lastKnownScore = nowScore;
    
    double mul = 1.0 + (comboLevel - 1) * 0.05;
    
    // List<DynamicGroup> totalGroup @96
    void* totalGroup = *(void**)((uint8_t*)ctrl + 96);
    int32_t cnt = il2cppListCount(totalGroup);
    long long added = 0;
    
    for (int32_t i = 0; i < cnt; i++) {
        void* grp = il2cppListItem(totalGroup, i);
        if (!grp) continue;
        if (g.scoredGroups[grp]) continue;
        if (!*(bool*)((uint8_t*)grp + 33)) continue;  // isJudgeAllKey @33
        
        void* beatKeys = *(void**)((uint8_t*)grp + 24); // beatKeys[] @24
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
    
    // Fix curArrowsIndex trên tất cả nhóm
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

#pragma mark - === DRIVER TIMER — Không hook trampoline ===

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

#pragma mark - === MENU run_ui_lua ===

extern "C" {
    void run_ui_lua() {
        NSLog(@"========================================");
        NSLog(@"   🎮 ERI MOD v7.2 — AU2! v23.4");
        NSLog(@"   Offsets Verified ✅  Driver: NSTimer");
        NSLog(@"========================================");
        NSLog(@"  [1] Auto Arrow (Perfect)  → %s", g.arrowEnabled ? "⚡ BẬT" : "⭕ TẮT");
        NSLog(@"  [2] Auto Taiko             → %s", g.taikoEnabled ? "⚡ BẬT" : "⭕ TẮT");
        NSLog(@"  [3] Crazy Score Fix        → %s", g.miniCrazyEnabled ? "⚡ BẬT" : "⭕ TẮT");
        NSLog(@"----------------------------------------");
        NSLog(@"  Controller: Arrow=%p Taiko=%p Dyn=%p", g_auditionCtrl, g_taikoCtrl, g_dynCtrl);
        NSLog(@"  Thống kê:");
        NSLog(@"    Nhóm Arrow: %d | Nốt Taiko: %d", g.counts.arrow, g.counts.taiko);
        NSLog(@"    Bonus Crazy: %lld | Tổng: %lld", g.counts.crazyBonus, g.lastKnownScore);
        NSLog(@"========================================");
    }
    
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
        NSLog(@"[Eri Mod] Controllers đã gán ✅");
    }
    void eri_reset_all() {
        restoreAll();
        g.arrowEnabled = g.taikoEnabled = g.miniCrazyEnabled = false;
        NSLog(@"[Eri Mod] Tất cả TẮT & Khôi phục ✅");
    }
}

#pragma mark - === INIT ===

__attribute__((constructor))
static void init() {
    NSLog(@"========================================");
    NSLog(@"  ERI MOD v7.2 — IL2CPP Verified");
    NSLog(@"  AU2! v23.4 | HotFix.dll metadata");
    NSLog(@"  ⚠️  Không hook shared trampoline");
    NSLog(@"  ✅ Dùng NSTimer driver an toàn");
    NSLog(@"========================================");
    NSLog(@"  Gọi run_ui_lua() để xem Menu");
    NSLog(@"  Gọi eri_set_controllers(a,t,d) khi vào màn Dance");
    NSLog(@"========================================");
    
    // Khởi động driver — gọi mỗi 0.1s
    dispatch_source_t timer = dispatch_source_create(
        DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW,
                              0.1 * NSEC_PER_SEC, 0.01 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(timer, ^{
        eri_driverTick();
    });
    dispatch_resume(timer);
}
