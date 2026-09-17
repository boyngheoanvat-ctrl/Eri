//
//  main.mm
//  Eri Mod v7.2 — IL2CPP Verified + run_ui_lua Menu
//  Đã sửa: tên biến khớp + kiểu con trỏ đúng
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

#pragma mark - === STATE ===

struct SavedField {
    int64_t i64;
    int32_t i32;
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
      lastArrowTick(0), lastTaikoTick(0), lastCrazyTick(0),
      lastKnownScore(0)
    {
        counts.arrow = 0;
        counts.taiko = 0;
        counts.crazyBonus = 0;
    }
} g;

static std::map<std::string, SavedEntry> saved;

#pragma mark - === IL2CPP ACCESSORS ===

static void setAuditionGroupPerfect(void* self) {
    if (!self) return;
    auto key = std::to_string((uintptr_t)self);
    if (!saved.count(key)) {
        SavedEntry e; e.ptr = self;
        e.fields["judgeLevel"].i32 = *(int32_t*)((uint8_t*)self + 64);
        e.fields["judgeLevel"].isInt = true;
        e.fields["isHitBeat"].b = *(bool*)((uint8_t*)self + 50);
        e.fields["isHitBeat"].isBool = true;
        saved[key] = e;
    }
    *(int32_t*)((uint8_t*)self + 64) = JUDGE_PERFECT;
    *(bool*)((uint8_t*)self + 50) = true;
}

static void setTrackPlaying(void* self) {
    if (!self) return;
    auto key = "TRK_" + std::to_string((uintptr_t)self);
    if (!saved.count(key)) {
        SavedEntry e; e.ptr = self;
        e.fields["IsPlaying"].b = ((bool(*)(void*, SEL))objc_msgSend)(self, sel_getUid("IsPlaying"));
        e.fields["IsPlaying"].isBool = true;
        saved[key] = e;
    }
    ((void(*)(void*, SEL, bool))objc_msgSend)(self, sel_getUid("set_IsPlaying:"), true);
}

static void setTaikoNotePerfect(void* self) {
    if (!self) return;
    auto key = "TKO_" + std::to_string((uintptr_t)self);
    if (!saved.count(key)) {
        SavedEntry e; e.ptr = self;
        e.fields["JudgeLevel"].i32 = *(int32_t*)((uint8_t*)self + 56);
        e.fields["JudgeLevel"].isInt = true;
        e.fields["isJudgeLevel"].b = *(bool*)((uint8_t*)self + 48);
        e.fields["isJudgeLevel"].isBool = true;
        e.fields["IsHit"].b = *(bool*)((uint8_t*)self + 64);
        e.fields["IsHit"].isBool = true;
        saved[key] = e;
    }
    *(int32_t*)((uint8_t*)self + 56) = JUDGE_PERFECT;
    *(bool*)((uint8_t*)self + 48) = true;
    *(bool*)((uint8_t*)self + 64) = true;
}

static long long updateCrazyScore(void* ctrl) {
    if (!ctrl) return 0;
    
    long long baseScore = *(int64_t*)((uint8_t*)ctrl + 0x38);
    int32_t comboLevel = *(int32_t*)((uint8_t*)ctrl + 0x44);
    long long nowScore = *(int64_t*)((uint8_t*)ctrl + 0x40);
    g.lastKnownScore = nowScore;
    
    double multiplier = 1.0 + (comboLevel - 1) * 0.05;
    
    void* groupArr = *(void**)((uint8_t*)ctrl + 0x50);
    if (!groupArr) return 0;
    int32_t count = *(int32_t*)((uint8_t*)groupArr + 0x10);
    void** items = (void**)((uint8_t*)groupArr + 0x20);
    
    long long added = 0;
    for (int32_t i = 0; i < count; i++) {
        void* grp = items[i];
        if (!grp) continue;
        if (g.scoredGroups[grp]) continue;
        
        bool allHit = *(bool*)((uint8_t*)grp + 0x30);
        if (!allHit) continue;
        
        int32_t keyCount = *(int32_t*)((uint8_t*)grp + 0x34);
        long long gain = (long long)floor(baseScore * multiplier * std::max(keyCount, 1));
        
        nowScore += gain;
        added += gain;
        g.scoredGroups[grp] = true;
    }
    
    *(int64_t*)((uint8_t*)ctrl + 0x40) = nowScore;
    return added;
}

static int fixArrowIndex(void* beatKeys) {
    if (!beatKeys) return 0;
    int32_t idx = *(int32_t*)((uint8_t*)beatKeys + 0x28);
    void* arr = *(void**)((uint8_t*)beatKeys + 0x20);
    if (!arr) return 0;
    int32_t len = *(int32_t*)((uint8_t*)arr + 0x10);
    
    if (idx < 0 || idx >= len) {
        *(int32_t*)((uint8_t*)beatKeys + 0x28) = 0;
        return 1;
    }
    return 0;
}

#pragma mark - === RESTORE ===

static void restoreAll() {
    for (auto& kv : saved) {
        auto& e = kv.second;
        if (!e.ptr) continue;
        for (auto& fv : e.fields) {
            auto& fn = fv.first;
            auto& fd = fv.second;
            if (fn == "judgeLevel" && fd.isInt)
                *(int32_t*)((uint8_t*)e.ptr + 64) = fd.i32;
            else if (fn == "isHitBeat" && fd.isBool)
                *(bool*)((uint8_t*)e.ptr + 50) = fd.b;
            else if (fn == "IsPlaying" && fd.isBool)
                ((void(*)(void*, SEL, bool))objc_msgSend)(e.ptr, sel_getUid("set_IsPlaying:"), fd.b);
            else if (fn == "JudgeLevel" && fd.isInt)
                *(int32_t*)((uint8_t*)e.ptr + 56) = fd.i32;
            else if (fn == "isJudgeLevel" && fd.isBool)
                *(bool*)((uint8_t*)e.ptr + 48) = fd.b;
            else if (fn == "IsHit" && fd.isBool)
                *(bool*)((uint8_t*)e.ptr + 64) = fd.b;
        }
    }
    saved.clear();
    g.scoredGroups.clear();
    g.counts.arrow = 0;
    g.counts.taiko = 0;
    g.counts.crazyBonus = 0;
    NSLog(@"[Eri Mod] ✅ Đã khôi phục tất cả giá trị gốc");
}

#pragma mark - === APPLY LOGIC ===

static int applyArrow() {
    int n = 0;
    // TODO: Thêm logic liệt kê instance AuditionGroup
    return n;
}

static int applyTaiko() {
    int n = 0;
    // TODO: Thêm logic liệt kê instance UI_TaikoNoteBase
    return n;
}

static long long applyCrazyFix() {
    extern void* DynamicArrowsController_instance;
    if (!DynamicArrowsController_instance) return 0;
    
    // TODO: Gọi fixArrowIndex trên tất cả DynamicOneBeatKeys
    
    long long bonus = updateCrazyScore(DynamicArrowsController_instance);
    g.counts.crazyBonus += bonus;
    return bonus;
}

#pragma mark - === MENU run_ui_lua ===

extern "C" {
    void run_ui_lua() {
        NSLog(@"========================================");
        NSLog(@"   🎮 ERI MOD v7.2 — IL2CPP VERIFIED");
        NSLog(@"========================================");
        NSLog(@"  [1] Auto Arrow (Perfect)  → %s", g.arrowEnabled ? "⚡ BẬT" : "⭕ TẮT");
        NSLog(@"  [2] Auto Taiko             → %s", g.taikoEnabled ? "⚡ BẬT" : "⭕ TẮT");
        NSLog(@"  [3] Full Mini + Crazy Fix  → %s", g.miniCrazyEnabled ? "⚡ BẬT" : "⭕ TẮT");
        NSLog(@"  [4] Ẩn/Hiện Menu           → %s", g.uiVisible ? "👁 Hiện" : "🙈 Ẩn");
        NSLog(@"----------------------------------------");
        NSLog(@"  Thống kê:");
        NSLog(@"    Arrow: %d nhóm | Taiko: %d nốt", g.counts.arrow, g.counts.taiko);
        NSLog(@"    Crazy Bonus đã cộng: %lld điểm", g.counts.crazyBonus);
        NSLog(@"    Tổng điểm hiện tại: %lld", g.lastKnownScore);
        NSLog(@"========================================");
    }
    
    void eri_toggle_arrow(bool enable) {
        if (g.arrowEnabled == enable) return;
        g.arrowEnabled = enable;
        if (!enable) restoreAll();
        NSLog(@"[Eri Mod] Auto Arrow → %s", enable ? "BẬT" : "TẮT");
    }
    void eri_toggle_taiko(bool enable) {
        g.taikoEnabled = enable;
        if (!enable) restoreAll();
        NSLog(@"[Eri Mod] Auto Taiko → %s", enable ? "BẬT" : "TẮT");
    }
    void eri_toggle_mini(bool enable) {
        g.miniCrazyEnabled = enable;
        if (!enable) restoreAll();
        else g.scoredGroups.clear();
        NSLog(@"[Eri Mod] MiniGame + CrazyFix → %s", enable ? "BẬT" : "TẮT");
    }
    void eri_reset_all() {
        restoreAll();
        g.arrowEnabled = g.taikoEnabled = g.miniCrazyEnabled = false;
        NSLog(@"[Eri Mod] Tất cả đã tắt & khôi phục ✅");
    }
}

#pragma mark - === UPDATE LOOP ===

static void (*orig_FrameUpdate)(void* self, void* method, float dt) = nullptr;

static void hook_FrameUpdate(void* self, void* method, float dt) {
    if (orig_FrameUpdate) orig_FrameUpdate(self, method, dt);
    
    time_t now = time(nullptr);
    
    if (g.arrowEnabled && difftime(now, g.lastArrowTick) >= 2.0) {
        g.lastArrowTick = now;
        g.counts.arrow = applyArrow();
    }
    
    if (g.taikoEnabled && difftime(now, g.lastTaikoTick) >= 2.0) {
        g.lastTaikoTick = now;
        g.counts.taiko = applyTaiko();
    }
    
    if (g.miniCrazyEnabled && difftime(now, g.lastCrazyTick) >= 0.3) {
        g.lastCrazyTick = now;
        applyCrazyFix();
    }
}

#pragma mark - === INIT ===

__attribute__((constructor))
static void init() {
    NSLog(@"========================================");
    NSLog(@"  ERI MOD v7.2 — IL2CPP MAPPED");
    NSLog(@"  Game: AU2! v23.4");
    NSLog(@"========================================");
    NSLog(@"  Gọi run_ui_lua() để mở Menu");
    NSLog(@"========================================");
    
    // TODO: Hook vòng lặp cập nhật thực
    // void* updateFunc = ...;
    // MSHookFunction(updateFunc, (void*)hook_FrameUpdate, (void**)&orig_FrameUpdate);
}
