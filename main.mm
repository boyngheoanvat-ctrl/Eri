//
//  main.mm
//  AutoDance HexControl v7.2 — FULL MINI GAME (Crazy Score Fix)
//  Định dạng: Objective-C++ / C++
//  Nguyên bản: autodance_hexcontrol_v4.txt
//

#import <Foundation/Foundation.h>
#import <ImGui/ImGui.h>
#include <cmath>
#include <cstdint>
#include <map>
#include <string>
#include <vector>
#include <ctime>

#pragma mark - === KHAI BÁO KIỂU DỮ LIỆU ===

enum eNoteJudgeLevel {
    JUDGE_MISS = 0,
    JUDGE_PERFECT = 4
};

struct FieldInfo {
    const char* name;
    size_t offset;
    const char* type;
    const char* mod;
};

struct MethodInfo {
    const char* name;
    const char* addr;
    const char* ret;
    const char* params;
};

struct ClassInfo {
    const char* clsName;
    const char* image;
    std::vector<FieldInfo> fields;
    std::vector<MethodInfo> methods;
};

struct MiniModeDef {
    const char* label;
    int judgeValue;
    std::vector<std::pair<const char*, std::vector<const char*>>> classes;
    std::vector<const char*> methodClasses;
};

struct SavedState {
    std::map<std::string, id> originalValues;
    id object;
};

#pragma mark - === TRẠNG THÁI TOÀN CỤC ===

static struct GlobalState {
    bool activeOn;
    bool taikoOn;
    bool miniOn;
    std::string status;
    const int PERFECT = JUDGE_PERFECT;
    
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
    std::map<std::string, bool> scoredGroups;
    
    GlobalState() : activeOn(false), taikoOn(false), miniOn(false),
                    status("Sẵn sàng. Bật toggle để chạy tự động qua các trận."),
                    modified(0), taiko(0), mini(0), crazy(0),
                    lastCheck(0), lastCount(0), lastTaikoCheck(0), lastTaikoCount(0),
                    lastMiniCheck(0), lastMiniCount(0), lastCrazyCheck(0), crazyScore(0) {}
} state;

static std::map<std::string, SavedState> originals;
static std::map<std::string, int> miniCounts;

#pragma mark - === BẢNG OFFSET & ĐỊA CHỈ ===

static const std::vector<ClassInfo> methodInfo = {
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

static const std::vector<MiniModeDef> MINI_MODES = {
    {
        "Bubble", JUDGE_PERFECT,
        {
            {"Modules.UI.UI_DanceBallSingleNote", {"judgeLevel"}},
            {"Modules.UI.UI_DanceBallLongNote", {"judgeLevel"}},
            {"BubbleNoteController", {"isAutoPlay"}}
        },
        {"Modules.UI.UI_BubbleNoteBase"}
    },
    {
        "VOS", JUDGE_PERFECT,
        {
            {"Modules.UI.UI_Note_VOS", {"judgeLevel", "isJudge"}},
            {"Modules.UI.UI_LongNote_VOS", {"judgeLevel"}}
        },
        {}
    },
    {
        "Burst", JUDGE_PERFECT,
        {
            {"BurstAuGroup", {"judgeLevel", "isHitBeat"}}
        },
        {}
    },
    {
        "Crazy", JUDGE_PERFECT,
        {
            {"DynamicGroup", {"judgeLevel"}},
            {"DynamicOneBeatKeys", {"judgeLevel", "JudgeRatio"}}
        },
        {}
    },
    {
        "Quỷ đạo", 0, // Perfect = 0 ở chế độ này
        {
            {"GuideNote", {"judgeLevel", "haveDone"}},
            {"GuideLongNote", {"curLevel"}},
            {"GuideDoubleNote", {"judgeLevel"}},
            {"GuideSlideNote", {"judgeLevel"}}
        },
        {}
    },
    {
        "4K/Track", JUDGE_PERFECT,
        {
            {"Dance.MusicTool.TrackNote", {"judgeLevel"}}
        },
        {}
    }
};

#pragma mark - === HÀM HỖ TRỢ TRUY CẬP ĐỐI TƯỢNG ===

static id getObjectField(id obj, NSString* fieldName) {
    if (!obj) return nil;
    @try { return [obj valueForKey:fieldName]; }
    @catch (...) { return nil; }
}

static bool setObjectField(id obj, NSString* fieldName, id value) {
    if (!obj) return false;
    @try { [obj setValue:value forKey:fieldName]; return true; }
    @catch (...) { return false; }
}

static bool setObjectFieldBool(id obj, NSString* fieldName, bool value) {
    return setObjectField(obj, fieldName, @(value));
}

static bool setObjectFieldInt(id obj, NSString* fieldName, int value) {
    return setObjectField(obj, fieldName, @(value));
}

static int getObjectFieldInt(id obj, NSString* fieldName, int defaultValue = 0) {
    id val = getObjectField(obj, fieldName);
    return val ? [val intValue] : defaultValue;
}

static long long getObjectFieldLong(id obj, NSString* fieldName, long long defaultValue = 0) {
    id val = getObjectField(obj, fieldName);
    return val ? [val longLongValue] : defaultValue;
}

static bool callObjectMethod(id obj, NSString* selector, id arg1 = nil, id arg2 = nil) {
    if (!obj || !selector) return false;
    SEL sel = NSSelectorFromString(selector);
    if (![obj respondsToSelector:sel]) return false;
    
    @try {
        NSMethodSignature* sig = [obj methodSignatureForSelector:sel];
        NSInvocation* inv = [NSInvocation invocationWithMethodSignature:sig];
        inv.target = obj;
        inv.selector = sel;
        if (arg1) [inv setArgument:&arg1 atIndex:2];
        if (arg2) [inv setArgument:&arg2 atIndex:3];
        [inv invoke];
        return true;
    } @catch (...) {
        return false;
    }
}

static NSArray* findObjectsOfClass(NSString* className) {
    Class cls = NSClassFromString(className);
    if (!cls || ![cls respondsToSelector:@selector(findObjects)]) return nil;
    id result = [cls performSelector:@selector(findObjects)];
    if ([result isKindOfClass:[NSArray class]]) return result;
    return nil;
}

#pragma mark - === LƯU / KHÔI PHỤC TRẠNG THÁI ===

static void captureOriginalValue(NSString* prefix, id obj, NSArray* fields) {
    if (!obj || !prefix) return;
    NSString* key = [NSString stringWithFormat:@"%@%p", prefix, obj];
    if (originals.count([key UTF8String])) return;
    
    SavedState stateEntry;
    stateEntry.object = obj;
    for (NSString* field in fields) {
        id val = getObjectField(obj, field);
        if (val) stateEntry.originalValues[[field UTF8String]] = val;
    }
    originals[[key UTF8String]] = stateEntry;
}

static int restoreAllOriginals() {
    int restored = 0;
    for (auto& pair : originals) {
        const SavedState& rec = pair.second;
        if (!rec.object) continue;
        for (const auto& fv : rec.originalValues) {
            setObjectField(rec.object, [NSString stringWithUTF8String:fv.first.c_str()], fv.second);
        }
        restored++;
    }
    originals.clear();
    state.stats.modified = 0;
    state.stats.taiko = 0;
    state.stats.mini = 0;
    state.stats.crazy = 0;
    state.scoredGroups.clear();
    state.crazyScore = 0;
    return restored;
}

#pragma mark - === ÁP DỤNG MODULE ===

static int applyAuditionMod() {
    int count = 0;
    @autoreleasepool {
        NSArray* groups = findObjectsOfClass(@"Dance.AuditionGroup");
        for (id g in groups) {
            captureOriginalValue(@"group:", g, @[@"judgeLevel", @"isHitBeat"]);
            setObjectFieldInt(g, @"judgeLevel", JUDGE_PERFECT);
            setObjectFieldBool(g, @"isHitBeat", YES);
            count++;
        }
        
        NSArray* tracks = findObjectsOfClass(@"GuidTrackDanceNoteCtrl");
        for (id trk in tracks) {
            captureOriginalValue(@"track:", trk, @[@"IsPlaying"]);
            setObjectFieldBool(trk, @"IsPlaying", YES);
            count++;
        }
    }
    return count;
}

static int applyTaikoMod() {
    int count = 0;
    @autoreleasepool {
        NSArray* notes = findObjectsOfClass(@"UI_TaikoNoteBase");
        for (id n in notes) {
            captureOriginalValue(@"taiko:", n, @[@"JudgeLevel", @"isJudgeLevel", @"IsHit"]);
            setObjectFieldInt(n, @"JudgeLevel", JUDGE_PERFECT);
            setObjectFieldBool(n, @"isJudgeLevel", YES);
            if (!getObjectFieldInt(n, @"IsHit")) {
                setObjectFieldBool(n, @"IsHit", YES);
            }
            count++;
        }
    }
    return count;
}

#pragma mark - === CRAZY SCORE FIX ===

static int repairCrazyKeys() {
    int repaired = 0;
    @autoreleasepool {
        NSArray* keys = findObjectsOfClass(@"DynamicOneBeatKeys");
        for (id k in keys) {
            int idx = getObjectFieldInt(k, @"curArrowsIndex", -1);
            NSArray* arrows = getObjectField(k, @"arrows");
            NSUInteger len = arrows ? [arrows count] : 0;
            
            if (len > 0 && (idx < 0 || idx >= (int)len)) {
                setObjectFieldInt(k, @"curArrowsIndex", 0);
                repaired++;
            }
        }
    }
    return repaired;
}

static long long applyCrazyScoreFix() {
    long long added = 0;
    @autoreleasepool {
        NSArray* ctrls = findObjectsOfClass(@"Dance.DynamicArrowsController");
        id ctrl = ctrls.count > 0 ? ctrls[0] : nil;
        if (!ctrl) return 0;
        
        long long base = getObjectFieldLong(ctrl, @"noteBaseScore", 100);
        int combo = getObjectFieldInt(ctrl, @"curComboLevel", 1);
        double comboMul = 1.0 + (combo - 1) * 0.05;
        long long nowScore = getObjectFieldLong(ctrl, @"nowTotalScore", 0);
        
        NSArray* groups = getObjectField(ctrl, @"totalGroup");
        for (id grp in groups) {
            NSString* gKey = [NSString stringWithFormat:@"crazyG:%p", grp];
            if (state.scoredGroups[[gKey UTF8String]]) continue;
            
            bool allHit = getObjectFieldInt(grp, @"isJudgeAllKey", 0);
            int jl = getObjectFieldInt(grp, @"judgeLevel", -1);
            if (!allHit || jl < 0) continue;
            
            int keysCnt = getObjectFieldInt(grp, @"curKeysIndex", 1);
            long long gain = (long long)floor(base * comboMul * std::max(keysCnt, 1));
            setObjectFieldInt(ctrl, @"nowTotalScore", (int)(nowScore + gain));
            
            state.scoredGroups[[gKey UTF8String]] = true;
            state.crazyScore = nowScore + gain;
            added += gain;
        }
        
        // Force perfect trên keys
        NSArray* keys = findObjectsOfClass(@"DynamicOneBeatKeys");
        for (id k in keys) {
            setObjectFieldInt(k, @"judgeLevel", JUDGE_PERFECT);
            setObjectFieldInt(k, @"JudgeRatio", 100);
            setObjectFieldBool(k, @"isJudge", YES);
        }
    }
    return added;
}

static int applyMiniMod() {
    int total = 0;
    @autoreleasepool {
        for (const auto& mode : MINI_MODES) {
            int modeCnt = 0;
            for (const auto& entry : mode.classes) {
                NSString* clsName = [NSString stringWithUTF8String:entry.first];
                NSArray* objs = findObjectsOfClass(clsName);
                for (id o in objs) {
                    captureOriginalValue([NSString stringWithFormat:@"mini:%p", o], o,
                        [entry.second.utf8String UTF8String]);
                    
                    for (const char* field : entry.second) {
                        std::string f = field;
                        if (f == "isAutoPlay" || f == "isJudge" || f == "isHitBeat" || f == "haveDone") {
                            setObjectFieldBool(o, @(f.c_str()), YES);
                        } else if (f == "JudgeRatio") {
                            setObjectFieldInt(o, @(f.c_str()), 100);
                        } else {
                            setObjectFieldInt(o, @(f.c_str()), mode.judgeValue);
                        }
                    }
                    modeCnt++;
                }
            }
            miniCounts[mode.label] = modeCnt;
            total += modeCnt;
        }
    }
    return total;
}

#pragma mark - === GIAO DIỆN IMGUI ===

void OnDraw() {
    time_t currentTime = time(nullptr);
    
    // Auto Arrow — mỗi 2s
    if (state.activeOn && difftime(currentTime, state.lastCheck) >= 2) {
        state.lastCheck = currentTime;
        int cnt = applyAuditionMod();
        if (cnt > 0 && cnt != state.lastCount) {
            state.lastCount = cnt;
            state.status = "Arrow: áp dụng cho trận mới! Objects=" + std::to_string(cnt);
        }
    }
    
    // Auto Taiko — mỗi 2s
    if (state.taikoOn && difftime(currentTime, state.lastTaikoCheck) >= 2) {
        state.lastTaikoCheck = currentTime;
        int cnt = applyTaikoMod();
        if (cnt > 0 && cnt != state.lastTaikoCount) {
            state.lastTaikoCount = cnt;
            state.status = "Taiko: Perfect áp dụng! Notes=" + std::to_string(cnt);
        }
    }
    
    // Full Mini — mỗi 2s
    if (state.miniOn && difftime(currentTime, state.lastMiniCheck) >= 2) {
        state.lastMiniCheck = currentTime;
        int cnt = applyMiniMod();
        if (cnt > 0 && cnt != state.lastMiniCount) {
            state.lastMiniCount = cnt;
            state.status = "FULL MINI GAME: Perfect áp dụng! Objects=" + std::to_string(cnt);
        }
    }
    
    // Crazy Fix — mỗi 0.3s
    if (state.miniOn && difftime(currentTime, state.lastCrazyCheck) >= 0.3) {
        int repaired = repairCrazyKeys();
        long long gain = applyCrazyScoreFix();
        state.lastCrazyCheck = currentTime;
        if (gain > 0 || repaired > 0) state.stats.crazy += gain;
    }
    
    // === VẼ GIAO DIỆN ===
    ImGui::SetNextWindowSize(ImVec2(660, 680));
    if (ImGui::Begin("AutoDance HexControl v7.2 — FULL MINI (Crazy Score Fix)")) {
        if (ImGui::BeginTabBar("##mainTabs")) {
            
            // === TAB 1: CONTROL ===
            if (ImGui::BeginTabItem("🎮 Control")) {
                bool b1 = state.activeOn;
                if (ImGui::Checkbox("Bật Auto Arrow (Audition)", &b1)) {
                    state.activeOn = b1;
                    if (b1) {
                        state.lastCount = applyAuditionMod();
                        state.lastCheck = currentTime;
                        state.status = "Arrow BẬT. Objects=" + std::to_string(state.lastCount);
                    } else {
                        restoreAllOriginals();
                        state.status = "Arrow TẮT. Khôi phục hoàn tất.";
                    }
                }
                
                bool b2 = state.taikoOn;
                if (ImGui::Checkbox("Bật Auto Taiko (Perfect All Notes)", &b2)) {
                    state.taikoOn = b2;
                    if (b2) {
                        state.lastTaikoCount = applyTaikoMod();
                        state.lastTaikoCheck = currentTime;
                        state.status = "Taiko BẬT. Notes=" + std::to_string(state.lastTaikoCount);
                    } else {
                        restoreAllOriginals();
                        state.status = "Taiko TẮT.";
                    }
                }
                
                bool b3 = state.miniOn;
                if (ImGui::Checkbox("🎯 Bật FULL MINI GAME (Bubble/VOS/Burst/Crazy/Quỷ đạo/4K)", &b3)) {
                    state.miniOn = b3;
                    if (b3) {
                        state.lastMiniCount = applyMiniMod();
                        state.lastMiniCheck = currentTime;
                        state.status = "FULL MINI BẬT. Objects=" + std::to_string(state.lastMiniCount);
                    } else {
                        restoreAllOriginals();
                        state.status = "FULL MINI TẮT.";
                    }
                }
                
                ImGui::Separator();
                ImGui::Text("Arrow: %s | Taiko: %s | Mini: %s",
                    state.activeOn ? "⚡ ON" : "OFF",
                    state.taikoOn ? "⚡ ON" : "OFF",
                    state.miniOn ? "⚡ ON" : "OFF");
                
                ImGui::SeparatorText("🎯 Crazy Score Fix");
                ImGui::Text("  Bonus đã cộng: %lld điểm", state.stats.crazy);
                ImGui::Text("  nowTotalScore: %lld", state.crazyScore);
                ImGui::Text("  Công thức: base × combo(1+%.2f×(combo-1)) × keyCount", 0.05f);
                
                if (state.miniOn) {
                    ImGui::SeparatorText("Mini per-mode");
                    for (const auto& m : MINI_MODES) {
                        ImGui::Text("  %-10s : %d", m.label, miniCounts[m.label]);
                    }
                }
                
                ImGui::SeparatorText("Trạng thái");
                ImGui::TextWrapped("%s", state.status.c_str());
                
                if (ImGui::Button("Reset / Khôi phục tất cả")) {
                    state.activeOn = state.taikoOn = state.miniOn = false;
                    int r = restoreAllOriginals();
                    state.status = "Đã reset + khôi phục " + std::to_string(r) + " object.";
                }
                
                ImGui::EndTabItem();
            }
            
            // === TAB 2: FIELD OFFSET ===
            if (ImGui::BeginTabItem("📐 Field Offset")) {
                for (const auto& cls : methodInfo) {
                    if (!cls.fields.empty()) {
                        ImGui::SeparatorText("%s  [%s]", cls.clsName, cls.image);
                        for (const auto& f : cls.fields) {
                            ImGui::Text("  0x%03zx  %-16s  %-20s → %s",
                                f.offset, f.name, f.type, f.mod);
                        }
                    }
                }
                ImGui::EndTabItem();
            }
            
            // === TAB 3: METHOD OFFSET ===
            if (ImGui::BeginTabItem("📍 Method Offset")) {
                for (const auto& cls : methodInfo) {
                    ImGui::SeparatorText("%s", cls.clsName);
                    for (const auto& m : cls.methods) {
                        ImGui::Text("  %s  %-20s  %s %s", m.addr, m.name, m.ret, m.params);
                    }
                }
                ImGui::EndTabItem();
            }
            
            ImGui::EndTabBar();
        }
    }
    ImGui::End();
}

void OnStop() {
    state.activeOn = state.taikoOn = state.miniOn = false;
    int r = restoreAllOriginals();
    printf("[AutoDance] Dừng. Đã khôi phục %d đối tượng.\n", r);
}

int main(int argc, const char* argv[]) {
    printf("=== AutoDance HexControl v7.2 Đã khởi động ===\n");
    printf("Nền tảng: Objective-C++ / main.mm\n");
    printf("Chế độ: Arrow + Taiko + Full Mini + Crazy Score Fix\n");
    printf("Gọi OnDraw() trong vòng lặp chính của ứng dụng\n");
    printf("Gọi OnStop() khi kết thúc\n");
    
    // Vòng lặp chính tích hợp với ImGui/Game engine
    // while (appRunning) { OnDraw(); }
    
    return 0;
}
