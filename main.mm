//
//  main.mm
//  AutoDance HexControl v7.2 — FULL MINI + Crazy Score Fix
//  Chuyển từ Lua → C++ | Giữ nguyên logic & menu
//  Platform: Substrate / IL2CPP AU2! v23.4
//

#import <Foundation/Foundation.h>
#import "substrate.h"
#include <cmath>
#include <map>
#include <string>
#include <vector>
#include <ctime>
#include <cstdio>

#pragma mark - === TYPES ===

enum eNoteJudgeLevel : int32_t {
    JUDGE_MISS = 0,
    JUDGE_PERFECT = 4
};

#pragma mark - === STATE — Giữ nguyên cấu trúc Lua ===

struct SavedVal {
    bool hasInt; int32_t i32;
    bool hasI64; int64_t i64;
    bool hasBool; bool b;
};
struct SavedEntry {
    void* obj;
    std::map<std::string, SavedVal> vals;
};

static struct Global {
    bool activeOn;
    bool taikoOn;
    bool miniOn;
    char status[256];
    
    struct Stats {
        int modified;
        int taiko;
        int mini;
        long long crazy;
    } stats;
    
    time_t lastCheck;
    int lastCount;
    time_t lastTaikoCheck;
    int lastTaikoCount;
    time_t lastMiniCheck;
    int lastMiniCount;
    time_t lastCrazyCheck;
    long long crazyScore;
    std::map<void*, bool> scoredGroups;
    
    Global() {
        activeOn = taikoOn = miniOn = false;
        snprintf(status, sizeof(status), "Sẵn sàng. Bật toggle để chạy tự động qua các trận.");
        stats.modified = stats.taiko = stats.mini = stats.crazy = 0;
        lastCheck = lastTaikoCheck = lastMiniCheck = lastCrazyCheck = 0;
        lastCount = lastTaikoCount = lastMiniCount = 0;
        crazyScore = 0;
    }
} g;

static std::map<std::string, SavedEntry> originals;
static std::map<std::string, int> miniCounts;

#pragma mark - === IL2CPP ACCESSORS — Kết nối field chính xác ===

static inline int32_t listCount(void* list) {
    return list ? *(int32_t*)((uint8_t*)list + 0x18) : 0;
}
static inline void* listItem(void* list, int32_t i) {
    if (!list) return nullptr;
    void* items = *(void**)((uint8_t*)list + 0x10);
    return items ? *(void**)((uint8_t*)items + 0x20 + i * 8) : nullptr;
}
static inline int32_t arrCount(void* arr) {
    return arr ? (int32_t)*(int64_t*)((uint8_t*)arr + 0x18) : 0;
}
static inline void* arrItem(void* arr, int32_t i) {
    return arr ? *(void**)((uint8_t*)arr + 0x20 + i * 8) : nullptr;
}

// Đọc/Ghi an toàn
static int32_t  i32_at(void* p, size_t off) { return *(int32_t*)((uint8_t*)p + off); }
static void set_i32(void* p, size_t off, int32_t v) { *(int32_t*)((uint8_t*)p + off) = v; }
static int64_t  i64_at(void* p, size_t off) { return *(int64_t*)((uint8_t*)p + off); }
static void set_i64(void* p, size_t off, int64_t v) { *(int64_t*)((uint8_t*)p + off) = v; }
static bool     bool_at(void* p, size_t off) { return *(bool*)((uint8_t*)p + off); }
static void set_bool(void* p, size_t off, bool v) { *(bool*)((uint8_t*)p + off) = v; }

#pragma mark - === CAPTURE / RESTORE — Giữ nguyên logic Lua ===

static void captureKey(const std::string& key, void* obj, const std::vector<std::string>& fields,
                       const std::map<std::string, size_t>& offsets) {
    if (!obj || originals.count(key)) return;
    SavedEntry e; e.obj = obj;
    for (const auto& f : fields) {
        auto it = offsets.find(f);
        if (it == offsets.end()) continue;
        SavedVal v;
        if (f == "judgeLevel" || f == "JudgeLevel" || f == "curArrowsIndex" || f == "curKeysIndex") {
            v.i32 = i32_at(obj, it->second); v.hasInt = true;
        } else if (f == "nowTotalScore" || f == "noteBaseScore") {
            v.i64 = i64_at(obj, it->second); v.hasI64 = true;
        } else {
            v.b = bool_at(obj, it->second); v.hasBool = true;
        }
        e.vals[f] = v;
    }
    originals[key] = e;
}

static int restoreAll() {
    int cnt = 0;
    for (auto& kv : originals) {
        auto& e = kv.second;
        if (!e.obj) continue;
        for (auto& fv : e.vals) {
            const auto& f = fv.first;
            const auto& v = fv.second;
            if (f == "judgeLevel") set_i32(e.obj, 64, v.i32);
            else if (f == "isHitBeat") set_bool(e.obj, 50, v.b);
            else if (f == "IsPlaying") ((void(*)(void*, SEL, bool))objc_msgSend)(e.obj, sel_getUid("set_IsPlaying:"), v.b);
            else if (f == "isJudgeLevel") set_bool(e.obj, 48, v.b);
            else if (f == "JudgeLevel") set_i32(e.obj, 56, v.i32);
            else if (f == "IsHit") set_bool(e.obj, 64, v.b);
            else if (f == "JudgeRatio") set_i32(e.obj, 52, v.i32);
            else if (f == "curArrowsIndex") set_i32(e.obj, 36, v.i32);
            else if (f == "nowTotalScore") set_i64(e.obj, 64, v.i64);
        }
        cnt++;
    }
    originals.clear();
    g.scoredGroups.clear();
    g.crazyScore = 0;
    g.stats.modified = g.stats.taiko = g.stats.mini = g.stats.crazy = 0;
    miniCounts.clear();
    return cnt;
}

#pragma mark - === APPLY: Auto Arrow / Audition ===

// Con trỏ Controller — gán khi vào màn hình
static void* g_auditionCtrl = nullptr;
static void* g_taikoCtrl = nullptr;
static void* g_dynCtrl = nullptr;

static int applyAuditionMod() {
    if (!g_auditionCtrl) return 0;
    int n = 0;
    
    // List<AuditionGroup> @48
    void* list = *(void**)((uint8_t*)g_auditionCtrl + 48);
    int32_t cnt = listCount(list);
    for (int32_t i = 0; i < cnt; i++) {
        void* grp = listItem(list, i);
        if (!grp) continue;
        captureKey("AG_" + std::to_string((uintptr_t)grp), grp,
            {"judgeLevel","isHitBeat"}, {{"judgeLevel",64},{"isHitBeat",50}});
        set_i32(grp, 64, JUDGE_PERFECT);
        set_bool(grp, 50, true);
        n++;
    }
    // currGroup @64
    void* cur = *(void**)((uint8_t*)g_auditionCtrl + 64);
    if (cur) {
        captureKey("AGcur_" + std::to_string((uintptr_t)cur), cur,
            {"judgeLevel","isHitBeat"}, {{"judgeLevel",64},{"isHitBeat",50}});
        set_i32(cur, 64, JUDGE_PERFECT);
        set_bool(cur, 50, true);
        n++;
    }
    g.stats.modified += n;
    return n;
}

#pragma mark - === APPLY: Auto Taiko ===

static int applyTaikoMod() {
    if (!g_taikoCtrl) return 0;
    int n = 0;
    
    // List<UI_TaikoNoteBase> @128
    void* list = *(void**)((uint8_t*)g_taikoCtrl + 128);
    int32_t cnt = listCount(list);
    for (int32_t i = 0; i < cnt; i++) {
        void* note = listItem(list, i);
        if (!note) continue;
        captureKey("TK_" + std::to_string((uintptr_t)note), note,
            {"isJudgeLevel","JudgeLevel","IsHit"},
            {{"isJudgeLevel",48},{"JudgeLevel",56},{"IsHit",64}});
        set_bool(note, 48, true);
        set_i32(note, 56, JUDGE_PERFECT);
        set_bool(note, 64, true);
        n++;
    }
    g.stats.taiko += n;
    return n;
}

#pragma mark - === APPLY: FULL MINI GAME ===

struct MiniMode {
    std::string label;
    int32_t judgeVal;
    std::vector<std::pair<std::string, std::vector<std::string>>> classes;
};

static const std::vector<MiniMode> MINI_MODES = {
    {"Bubble", JUDGE_PERFECT, {}},
    {"VOS", JUDGE_PERFECT, {}},
    {"Burst", JUDGE_PERFECT, {}},
    {"Crazy", JUDGE_PERFECT, {
        {"DynamicGroup", {"judgeLevel"}},
        {"DynamicOneBeatKeys", {"judgeLevel","JudgeRatio","curArrowsIndex"}}
    }},
    {"Quỷ đạo", 0, {}},
    {"4K/Track", JUDGE_PERFECT, {}}
};

static int applyMiniMod() {
    if (!g_dynCtrl) return 0;
    int total = 0;
    
    // Crazy mode: DynamicGroup
    void* grpList = *(void**)((uint8_t*)g_dynCtrl + 96); // List<DynamicGroup> @96
    int32_t cnt = listCount(grpList);
    for (int32_t i = 0; i < cnt; i++) {
        void* grp = listItem(grpList, i);
        if (!grp) continue;
        captureKey("DynG_" + std::to_string((uintptr_t)grp), grp,
            {"judgeLevel"}, {{"judgeLevel", 32}});
        set_i32(grp, 32, JUDGE_PERFECT);
        
        // DynamicOneBeatKeys[] @24
        void* keysArr = *(void**)((uint8_t*)grp + 24);
        int32_t kcnt = arrCount(keysArr);
        for (int32_t k = 0; k < kcnt; k++) {
            void* kb = arrItem(keysArr, k);
            if (!kb) continue;
            captureKey("DynK_" + std::to_string((uintptr_t)kb), kb,
                {"judgeLevel","JudgeRatio","curArrowsIndex"},
                {{"judgeLevel",32},{"JudgeRatio",52},{"curArrowsIndex",36}});
            set_i32(kb, 32, JUDGE_PERFECT);
            set_i32(kb, 52, 100); // JudgeRatio = 100%
        }
        total++;
    }
    miniCounts["Crazy"] = total;
    g.stats.mini += total;
    return total;
}

#pragma mark - === CRAZY SCORE FIX — v7.2 Chính xác ===

static int repairCrazyKeys() {
    if (!g_dynCtrl) return 0;
    int fixed = 0;
    
    void* grpList = *(void**)((uint8_t*)g_dynCtrl + 96);
    int32_t cnt = listCount(grpList);
    for (int32_t i = 0; i < cnt; i++) {
        void* grp = listItem(grpList, i);
        if (!grp) continue;
        void* keysArr = *(void**)((uint8_t*)grp + 24);
        int32_t kcnt = arrCount(keysArr);
        for (int32_t k = 0; k < kcnt; k++) {
            void* kb = arrItem(keysArr, k);
            if (!kb) continue;
            int32_t idx = i32_at(kb, 36); // curArrowsIndex @36
            void* arrows = *(void**)((uint8_t*)kb + 16);
            int32_t len = arrCount(arrows);
            if (idx < 0 || idx >= len) {
                set_i32(kb, 36, 0);
                fixed++;
            }
        }
    }
    return fixed;
}

static long long applyCrazyScoreFix() {
    if (!g_dynCtrl) return 0;
    
    int64_t base = i64_at(g_dynCtrl, 60);      // noteBaseScore @60
    int32_t combo = i32_at(g_dynCtrl, 172);     // curComboLevel @172
    int64_t nowScore = i64_at(g_dynCtrl, 64);   // nowTotalScore @64
    g.crazyScore = nowScore;
    
    if (base <= 0) base = 100;
    if (combo < 1) combo = 1;
    double mul = 1.0 + (combo - 1) * 0.05;
    
    void* grpList = *(void**)((uint8_t*)g_dynCtrl + 96);
    int32_t cnt = listCount(grpList);
    long long added = 0;
    
    for (int32_t i = 0; i < cnt; i++) {
        void* grp = listItem(grpList, i);
        if (!grp) continue;
        if (g.scoredGroups[grp]) continue;
        
        bool allHit = bool_at(grp, 33); // isJudgeAllKey @33
        if (!allHit) continue;
        
        int32_t keyCnt = i32_at(grp, 36); // curKeysIndex @36
        if (keyCnt < 1) keyCnt = 1;
        
        long long gain = (long long)std::floor((double)base * mul * keyCnt);
        nowScore += gain;
        added += gain;
        g.scoredGroups[grp] = true;
    }
    
    set_i64(g_dynCtrl, 64, nowScore);
    g.stats.crazy += added;
    g.crazyScore = nowScore;
    return added;
}

#pragma mark - === EXTERNAL API / MENU ===

extern "C" {
    // Gán controller khi vào màn hình chơi
    void eri_set_controllers(void* audition, void* taiko, void* dyn) {
        g_auditionCtrl = audition;
        g_taikoCtrl = taiko;
        g_dynCtrl = dyn;
        NSLog(@"✅ Controllers: A=%p T=%p D=%p", audition, taiko, dyn);
    }
    
    // Toggle — khớp logic Lua
    void eri_toggle_arrow(bool enable) {
        if (g.activeOn == enable) return;
        g.activeOn = enable;
        if (enable) {
            int n = applyAuditionMod();
            snprintf(g.status, sizeof(g.status), "Arrow BẬT. Objects=%d", n);
            g.lastCheck = time(nullptr);
            g.lastCount = n;
        } else {
            int r = restoreAll();
            snprintf(g.status, sizeof(g.status), "Arrow TẮT. Khôi phục %d object.", r);
        }
        NSLog(@"[Eri Mod] %s", g.status);
    }
    
    void eri_toggle_taiko(bool enable) {
        if (g.taikoOn == enable) return;
        g.taikoOn = enable;
        if (enable) {
            int n = applyTaikoMod();
            snprintf(g.status, sizeof(g.status), "Taiko Perfect BẬT. Notes=%d", n);
            g.lastTaikoCheck = time(nullptr);
            g.lastTaikoCount = n;
        } else {
            int r = restoreAll();
            snprintf(g.status, sizeof(g.status), "Taiko TẮT. Khôi phục %d object.", r);
        }
        NSLog(@"[Eri Mod] %s", g.status);
    }
    
    void eri_toggle_mini(bool enable) {
        if (g.miniOn == enable) return;
        g.miniOn = enable;
        if (enable) {
            int n = applyMiniMod();
            snprintf(g.status, sizeof(g.status), "FULL MINI GAME BẬT. Objects=%d", n);
            g.lastMiniCheck = time(nullptr);
            g.lastMiniCount = n;
        } else {
            g.scoredGroups.clear();
            g.crazyScore = 0;
            int r = restoreAll();
            snprintf(g.status, sizeof(g.status), "FULL MINI GAME TẮT. Khôi phục %d object.", r);
        }
        NSLog(@"[Eri Mod] %s", g.status);
    }
    
    void eri_reset_all() {
        g.activeOn = g.taikoOn = g.miniOn = false;
        int r = restoreAll();
        snprintf(g.status, sizeof(g.status), "Đã reset + khôi phục %d object.", r);
        NSLog(@"[Eri Mod] %s", g.status);
    }
    
    // Menu trạng thái — gọi từ Lua/Console
    void run_ui_lua() {
        printf("========================================\n");
        printf("  🎮 AutoDance HexControl v7.2\n");
        printf("  FULL MINI + Crazy Score Fix\n");
        printf("========================================\n");
        printf("  Auto Arrow : %s\n", g.activeOn ? "⚡ BẬT" : "⭕ TẮT");
        printf("  Auto Taiko : %s\n", g.taikoOn ? "⚡ BẬT" : "⭕ TẮT");
        printf("  Mini Game  : %s\n", g.miniOn ? "⚡ BẬT" : "⭕ TẮT");
        printf("----------------------------------------\n");
        printf("  Objects: Arrow=%d | Taiko=%d | Mini=%d\n",
               g.stats.modified, g.stats.taiko, g.stats.mini);
        printf("  Crazy Bonus: %lld điểm | Tổng: %lld\n",
               g.stats.crazy, g.crazyScore);
        printf("  Trạng thái: %s\n", g.status);
        printf("========================================\n");
    }
}

#pragma mark - === DRIVER — Giữ nguyên chu kỳ Lua ===

static void eri_driverTick() {
    time_t now = time(nullptr);
    
    // Auto Arrow — mỗi 2s
    if (g.activeOn && difftime(now, g.lastCheck) >= 2.0) {
        g.lastCheck = now;
        g.lastCount = applyAuditionMod();
    }
    
    // Auto Taiko — mỗi 2s
    if (g.taikoOn && difftime(now, g.lastTaikoCheck) >= 2.0) {
        g.lastTaikoCheck = now;
        g.lastTaikoCount = applyTaikoMod();
    }
    
    // Full Mini — mỗi 2s
    if (g.miniOn && difftime(now, g.lastMiniCheck) >= 2.0) {
        g.lastMiniCheck = now;
        g.lastMiniCount = applyMiniMod();
    }
    
    // Crazy Fix — mỗi 0.3s
    if (g.miniOn && difftime(now, g.lastCrazyCheck) >= 0.3) {
        repairCrazyKeys();
        applyCrazyScoreFix();
        g.lastCrazyCheck = now;
    }
}

#pragma mark - === INIT ===

__attribute__((constructor))
static void init() {
    NSLog(@"========================================");
    NSLog(@"  AutoDance HexControl v7.2");
    NSLog(@"  Chuyển Lua → C++ | FULL MINI + Crazy");
    NSLog(@"========================================");
    NSLog(@"  Gọi eri_set_controllers(a,t,d) khi vào màn hình");
    NSLog(@"  Gọi run_ui_lua() để xem trạng thái");
    NSLog(@"========================================");
    
    // Driver — chạy liên tục
    dispatch_source_t timer = dispatch_source_create(
        DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW,
                              0.1 * NSEC_PER_SEC, 0.05 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(timer, ^{
        eri_driverTick();
    });
    dispatch_resume(timer);
}
