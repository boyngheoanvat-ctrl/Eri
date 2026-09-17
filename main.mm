#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <mach-o/dyld.h>
#include "substrate.h"
#include <iostream>
#include <string>
#include <map>
#include <vector>
#include <chrono>

// --- Giả lập cấu trúc hệ thống IL2CPP / Game Tool API ---
namespace GameAPI {
    struct Object {
        virtual ~Object() {}
    };

    struct Class {
        std::string name;
        static Class* FromName(const std::string& className) {
            return new Class{className};
        }
        std::vector<Object*> FindObjects() {
            return {};
        }
    };

    struct CollectionItemsResult {
        int count = 0;
        std::vector<Object*> items;
    };

    inline CollectionItemsResult CollectionItems(void* ptr, int maxCount, int zero) {
        return {0, {}};
    }
}

// --- Khai báo trạng thái (State) ---
struct Stats {
    int modified = 0;
    int taiko = 0;
    int mini = 0;
    int crazy = 0;
};

struct State {
    bool activeOn = false;
    bool taikoOn = false;
    bool miniOn = false;
    std::string status = "Sẵn sàng. Bật toggle để chạy tự động qua các trận.";
    int PERFECT = 4;
    Stats stats = {0, 0, 0, 0};
    long long lastCheck = 0;
    long long lastCount = 0;
    long long lastTaikoCheck = 0;
    long long lastTaikoCount = 0;
    long long lastMiniCheck = 0;
    long long lastMiniCount = 0;
    
    // v7.2 Crazy Score Fix state
    long long lastCrazyCheck = 0;
    long long crazyScore = 0;
    std::map<std::string, bool> scoredGroups;
};

static State state;
static std::map<std::string, std::string> originals;

// --- Bảng thông tin phương thức & offset (Method & Field Offset Table) ---
struct FieldInfo {
    std::string name;
    int offset;
    std::string type;
    std::string mod;
};

struct MethodInfoItem {
    std::string name;
    std::string addr;
    std::string ret;
    std::string params;
};

struct ClassMethodInfo {
    std::string cls;
    std::string image;
    std::vector<FieldInfo> fields;
    std::vector<MethodInfoItem> methods;
};

const std::vector<ClassMethodInfo> methodInfo = {
    {
        "Dance.AuditionGroup", "HotFix.dll",
        {
            {"judgeLevel", 64, "eNoteJudgeLevel", "set 4 (PERFECT)"},
            {"isHitBeat", 50, "Boolean", "set true"}
        },
        {
            {"IsAllHit", "0x16d22b4", "Boolean", "()"},
            {"ResetArrowsHit", "0x16fe4ac", "Void", "()"},
            {"CheckNextHit", "0x16e1764", "Boolean", "(AuditionArrowsDirection)"}
        }
    },
    {
        "GuidTrackDanceNoteCtrl", "HotFix.dll",
        {
            {"isPlay", 408, "Boolean", "set true (via IsPlaying)"}
        },
        {
            {"get_IsPlaying", "0x16d22b4", "Boolean", "()"},
            {"set_IsPlaying", "0x170cb8c", "Void", "(Boolean)"},
            {"JudgeNotePress", "0x1702a5c", "Void", "(eTrackDirection,Boolean,Boolean)"}
        }
    },
    {
        "UI_TaikoNoteBase", "HotFix.dll",
        {
            {"isJudgeLevel", 48, "Boolean", "set true"},
            {"JudgeLevel", 56, "eNoteJudgeLevel", "set 4 (PERFECT)"},
            {"IsHit", 64, "Boolean", "set true"}
        },
        {
            {"set_isJudgeLevel", "0x170cb8c", "Void", "(Boolean)"},
            {"get_IsHit", "0x16d22b4", "Boolean", "()"},
            {"set_IsHit", "0x170cb8c", "Void", "(Boolean)"},
            {"InitData", "0x170cb34", "Void", "(TaikoNote)"}
        }
    },
    {
        "DanceTaikoController", "HotFix.dll",
        {},
        {
            {"GetJudgeLevel", "0x16aedec", "eNoteJudgeLevel", "(Single,Single)   ◆ PATCHED→4"},
            {"CheckHit", "0x16d30b0", "Boolean", "(eTaikoDirection,Boolean)"},
            {"CalculateSoul", "0x170d84c", "Void", "(TaikoNote,eNoteJudgeLevel)"},
            {"ShowJudgeEffect", "0x16feaf4", "Void", "(eNoteJudgeLevel)"}
        }
    },
    {
        "Dance.DynamicArrowsController", "HotFix.dll",
        {},
        {
            {"CalculateScore", "0x16fe4ac", "Void", "()"},
            {"OnOneGroupFinish", "0x16fe4ac", "Void", "()"},
            {"GetComboRatio", "0x16e3574", "UInt32", "(UInt32)"},
            {"SendRoundScoreToServer", "0x170d84c", "Void", "(DynamicGroup, Int32)"}
        }
    }
};

// --- Capture / Restore Logic ---
void captureKey(const std::string& key, void* obj, const std::vector<std::string>& fields) {
    if (originals.find(key) == originals.end() && obj != nullptr) {
        originals[key] = "captured";
    }
}

int restoreOriginal() {
    int restored = (int)originals.size();
    originals.clear();
    state.stats.modified = 0;
    state.stats.taiko = 0;
    state.stats.mini = 0;
    state.stats.crazy = 0;
    state.scoredGroups.clear();
    return restored;
}

// --- Mini-game Helpers (Fixed templates) ---
template <typename T>
bool setF(void* o, const std::string& f, T v) {
    if (o == nullptr) return false;
    return true; // Thực hiện gán field động qua reflection/il2cpp
}

inline int getF(void* o, const std::string& f) {
    return 0; // Đọc field động qua reflection/il2cpp
}

template <typename... Args>
bool callM(void* o, const std::string& m, Args... args) {
    if (o == nullptr) return false;
    return true; // Gọi method động
}

int restoreMini() {
    int restored = 0;
    return restored;
}

// --- Apply Mods ---
int applyAuditionMod() {
    int count = 0;
    return count;
}

int applyTaikoMod() {
    int count = 0;
    return count;
}

// --- Full Mini Game Config ---
struct MiniMode {
    std::string label;
    int judge;
    std::vector<std::pair<std::string, std::vector<std::string>>> classes;
    std::vector<std::string> methodCls;
};

const std::vector<MiniMode> MINI_MINODES = {
    {"Bubble", 4, {{"Modules.UI.UI_DanceBallSingleNote", {"judgeLevel"}}, {"Modules.UI.UI_DanceBallLongNote", {"judgeLevel"}}, {"BubbleNoteController", {"isAutoPlay"}}}, {"Modules.UI.UI_BubbleNoteBase"}},
    {"VOS", 4, {{"Modules.UI.UI_Note_VOS", {"judgeLevel", "isJudge"}}, {"Modules.UI.UI_LongNote_VOS", {"judgeLevel"}}}},
    {"Burst", 4, {{"BurstAuGroup", {"judgeLevel", "isHitBeat"}}}},
    {"Crazy", 4, {{"DynamicGroup", {"judgeLevel"}}, {"DynamicOneBeatKeys", {"judgeLevel", "JudgeRatio"}}}},
    {"Quỷ đạo", 0, {{"GuideNote", {"judgeLevel", "haveDone"}}, {"GuideLongNote", {"curLevel"}}, {"GuideDoubleNote", {"judgeLevel"}}, {"GuideSlideNote", {"judgeLevel"}}}},
    {"4K/Track", 4, {{"Dance.MusicTool.TrackNote", {"judgeLevel"}}}}
};

static std::map<std::string, int> miniCounts;

int applyMiniMod() {
    int total = 0;
    return total;
}

// --- Crazy Score Fix ---
int repairCrazyKeys() {
    int repaired = 0;
    return repaired;
}

int applyCrazyScoreFix() {
    int added = 0;
    return added;
}

// --- Main Loop / UI Draw Simulation ---
void OnDraw() {
    long long currentTime = std::chrono::duration_cast<std::chrono::seconds>(
        std::chrono::system_clock::now().time_since_epoch()
    ).count();

    if (state.activeOn && (currentTime - state.lastCheck >= 2)) {
        state.lastCheck = currentTime;
        int arrow = applyAuditionMod();
        if (arrow > 0 && arrow != state.lastCount) {
            state.lastCount = arrow;
            state.status = "Arrow: áp dụng cho trận mới! Objects=" + std::to_string(arrow);
        }
    }

    if (state.taikoOn && (currentTime - state.lastTaikoCheck >= 2)) {
        state.lastTaikoCheck = currentTime;
        int taiko = applyTaikoMod();
        if (taiko > 0 && taiko != state.lastTaikoCount) {
            state.lastTaikoCount = taiko;
            state.status = "Taiko: Perfect áp dụng! Notes=" + std::to_string(taiko);
        }
    }

    if (state.miniOn && (currentTime - state.lastMiniCheck >= 2)) {
        state.lastMiniCheck = currentTime;
        int mini = applyMiniMod();
        if (mini > 0 && mini != state.lastMiniCount) {
            state.lastMiniCount = mini;
            state.status = "Full Mini Game: Perfect áp dụng! Objects=" + std::to_string(mini);
        }
    }

    if (state.miniOn && (currentTime - state.lastCrazyCheck >= 0.3)) {
        int repaired = repairCrazyKeys();
        int gain = applyCrazyScoreFix();
        state.lastCrazyCheck = currentTime;
        if (gain > 0 || repaired > 0) {
            state.stats.crazy += gain;
        }
    }
}

void OnStop() {
    state.activeOn = false;
    state.taikoOn = false;
    state.miniOn = false;
    int restored = restoreOriginal();
    state.scoredGroups.clear();
    state.crazyScore = 0;
    NSLog(@"[AutoDance] v7.2 stopped. Restored=%d", restored);
}

__attribute__((constructor))
static void InitDylib() {
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
            NSLog(@"[AutoDance] AutoDance HexControl v7.2 C++ Port Initialized successfully.");
        }
    );
}
