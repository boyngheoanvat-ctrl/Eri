//
//  main.mm
//  Eri Mod — AutoDance HexControl v7.2
//  Nền tảng: Substrate / iOS
//  Đã sửa lỗi: kiểm tra map + trùng tên biến
//

#import <Foundation/Foundation.h>
#import "substrate.h"
#include <cmath>
#include <map>
#include <string>
#include <vector>
#include <ctime>

#pragma mark - === KIỂU DỮ LIỆU ===

enum eNoteJudgeLevel {
    JUDGE_MISS = 0,
    JUDGE_PERFECT = 4
};

struct SavedState {
    std::map<std::string, id> originalValues;
    __weak id object;
};

#pragma mark - === TRẠNG THÁI TOÀN CỤC ===

static struct GlobalState {
    bool activeOn;
    bool taikoOn;
    bool miniOn;
    std::string status;
    const int PERFECT = JUDGE_PERFECT;
    
    struct Stats {
        long long modified, taiko, mini, crazy;
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
        status("Sẵn sàng. Bật để chạy tự động."),
        stats{0,0,0,0},
        lastCheck(0), lastCount(0), lastTaikoCheck(0), lastTaikoCount(0),
        lastMiniCheck(0), lastMiniCount(0), lastCrazyCheck(0), crazyScore(0) {}
} state;

static std::map<std::string, SavedState> originals;
static std::map<std::string, int> miniCounts;

#pragma mark - === HÀM HỖ TRỢ ===

static id getField(id obj, NSString* name) {
    if (!obj) return nil;
    @try { return [obj valueForKey:name]; }
    @catch (...) { return nil; }
}

static bool setField(id obj, NSString* name, id val) {
    if (!obj) return false;
    @try { [obj setValue:val forKey:name]; return true; }
    @catch (...) { return false; }
}

static bool setFieldInt(id obj, NSString* name, int v)       { return setField(obj, name, @(v)); }
static bool setFieldLong(id obj, NSString* name, long long v) { return setField(obj, name, @(v)); }
static int getFieldInt(id obj, NSString* name, int def=0) {
    id v = getField(obj, name); return v ? [v intValue] : def;
}
static long long getFieldLong(id obj, NSString* name, long long def=0) {
    id v = getField(obj, name); return v ? [v longLongValue] : def;
}

static NSArray* findObjects(NSString* clsName) {
    Class cls = NSClassFromString(clsName);
    if (!cls || ![cls respondsToSelector:@selector(findObjects)]) return nil;
    id res = [cls performSelector:@selector(findObjects)];
    return [res isKindOfClass:[NSArray class]] ? res : nil;
}

#pragma mark - === LƯU / KHÔI PHỤC ===

static void capture(NSString* prefix, id obj, NSArray* fields) {
    if (!obj) return;
    NSString* key = [NSString stringWithFormat:@"%@%p", prefix, obj];
    
    // ✅ SỬA LỖI 1: dùng .find() để kiểm tra tồn tại
    if (originals.find([key UTF8String]) != originals.end()) return;
    
    SavedState s;
    s.object = obj;
    for (NSString* f in fields) {
        id v = getField(obj, f);
        if (v) s.originalValues[[f UTF8String]] = v;
    }
    originals[[key UTF8String]] = s;
}

static int restoreAll() {
    int cnt = 0;
    for (auto& p : originals) {
        if (!p.second.object) continue;
        for (auto& fv : p.second.originalValues)
            setField(p.second.object, @(fv.first.c_str()), fv.second);
        cnt++;
    }
    originals.clear();
    state.scoredGroups.clear();
    state.crazyScore = 0;
    return cnt;
}

#pragma mark - === MODULE CHÍNH ===

static int applyAudition() {
    int cnt = 0;
    @autoreleasepool {
        NSArray* groups = findObjects(@"Dance.AuditionGroup");
        for (id g in groups) {
            capture(@"G:", g, @[@"judgeLevel", @"isHitBeat"]);
            setFieldInt(g, @"judgeLevel", JUDGE_PERFECT);
            setFieldInt(g, @"isHitBeat", 1);
            cnt++;
        }
        NSArray* tracks = findObjects(@"GuidTrackDanceNoteCtrl");
        for (id trk in tracks) {
            capture(@"T:", trk, @[@"IsPlaying"]);
            setFieldInt(trk, @"IsPlaying", 1);
            cnt++;
        }
    }
    return cnt;
}

static int repairCrazyKeys() {
    int fixed = 0;
    @autoreleasepool {
        NSArray* keys = findObjects(@"DynamicOneBeatKeys");
        for (id k in keys) {
            int idx = getFieldInt(k, @"curArrowsIndex", -1);
            NSArray* arrows = getField(k, @"arrows");
            NSUInteger len = arrows ? [arrows count] : 0;
            if (len > 0 && (idx < 0 || idx >= (int)len)) {
                setFieldInt(k, @"curArrowsIndex", 0);
                fixed++;
            }
        }
    }
    return fixed;
}

static long long applyCrazyScoreFix() {
    long long added = 0;
    @autoreleasepool {
        NSArray* ctrls = findObjects(@"Dance.DynamicArrowsController");
        if (!ctrls || ctrls.count == 0) return 0;
        id ctrl = ctrls[0];
        
        long long base = getFieldLong(ctrl, @"noteBaseScore", 100);
        int combo = getFieldInt(ctrl, @"curComboLevel", 1);
        double mul = 1.0 + (combo - 1) * 0.05;
        long long score = getFieldLong(ctrl, @"nowTotalScore", 0);
        
        NSArray* groups = getField(ctrl, @"totalGroup");
        for (id grp in groups) {
            NSString* gKey = [NSString stringWithFormat:@"CG:%p", grp];
            if (state.scoredGroups[[gKey UTF8String]]) continue;
            if (!getFieldInt(grp, @"isJudgeAllKey", 0)) continue;
            
            int keys = getFieldInt(grp, @"curKeysIndex", 1);
            long long gain = (long long)floor(base * mul * std::max(keys, 1));
            score += gain;
            setFieldLong(ctrl, @"nowTotalScore", score);
            state.scoredGroups[[gKey UTF8String]] = true;
            added += gain;
        }
        state.crazyScore = score;
    }
    return added;
}

#pragma mark - === SUBSTRATE HOOK / VÒNG LẶP ===

// ✅ SỬA LỖI 2: ĐỔI TÊN để không trùng
static void (*orig_GameUpdate)(id, SEL) = nullptr;

static void hook_GameUpdate(id self, SEL _cmd) {
    // Gọi hàm gốc trước
    if (orig_GameUpdate) orig_GameUpdate(self, _cmd);
    
    time_t now = time(nullptr);
    
    // Auto Arrow — mỗi 2 giây
    if (state.activeOn && difftime(now, state.lastCheck) >= 2) {
        state.lastCheck = now;
        state.lastCount = applyAudition();
    }
    
    // Crazy Score Fix — mỗi 0.3 giây
    if (state.miniOn && difftime(now, state.lastCrazyCheck) >= 0.3) {
        repairCrazyKeys();
        state.stats.crazy += applyCrazyScoreFix();
        state.lastCrazyCheck = now;
    }
}

#pragma mark - === TẢI MODULE ===

__attribute__((constructor))
static void init(void) {
    NSLog(@"[Eri Mod] AutoDance v7.2 ĐANG TẢI...");
    
    // ===================== LƯU Ý =====================
    // Thay "TênLớpCậpNhật" và "tênHàmCậpNhật" bằng tên thực của game!
    // Ví dụ:
    // Class cls = NSClassFromString(@"GameController");
    // MSHookMessageEx(cls, @selector(update:), (IMP)&hook_GameUpdate, (IMP*)&orig_GameUpdate);
    // ==================================================
    
    NSLog(@"[Eri Mod] Đã sẵn sàng ✅");
}
