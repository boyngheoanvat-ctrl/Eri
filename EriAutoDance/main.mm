#include <atomic>
#include <cstdint>
#include <cstring>
#include <vector>
#include <unordered_map>

#include "il2cpp/il2cpp-api.h"
#include "il2cpp/il2cpp-class-internals.h"
#include "il2cpp/il2cpp-object-internals.h"
#include "il2cpp/il2cpp-runtime-metadata.h"
#include "il2cpp/il2cpp-functions.h"
#include "gc/gc.h"

static const char* kAuditionGroupNs = "Dance";
static const char* kAuditionGroupName = "AuditionGroup";
static const char* kTrackCtrlNs = "";
static const char* kTrackCtrlName = "GuidTrackDanceNoteCtrl";

static const uint32_t OFF_JUDGE_LEVEL = 0x40;
static const uint32_t OFF_IS_HIT_BEAT  = 0x32;
static const uint32_t OFF_IS_PLAY      = 0x198;
static const int32_t  PERFECT          = 4;
static const uint64_t REAPPLY_MS       = 2000;

static Il2CppClass* g_clsAuditionGroup = nullptr;
static Il2CppClass* g_clsTrackCtrl      = nullptr;
static std::atomic<bool>        g_enabled{false};
static std::atomic<uint64_t>    g_lastTick{0};
static std::atomic<int32_t>     g_modified{0};

struct Originals {
    void*   obj = nullptr;
    int32_t judgeLevel = 0;
    bool    isHitBeat  = false;
    bool    isPlay     = false;
    bool    captured   = false;
};
static std::vector<Originals> g_originals;

static Il2CppClass* FindClass(const char* ns, const char* name) {
    const Il2CppDomain* domain = il2cpp_domain_get();
    size_t nImages = 0;
    Il2CppImage** images = il2cpp_domain_get_assemblies(domain, &nImages);
    for (size_t i = 0; i < nImages; ++i) {
        Il2CppClass* c = il2cpp_class_from_name(images[i], ns, name);
        if (c) return c;
    }
    return nullptr;
}

static std::vector<Il2CppObject*> FindObjectsOfClass(Il2CppClass* klass) {
    std::vector<Il2CppObject*> out;
    if (!klass) return out;
    il2cpp::gc::GarbageCollector::ForEachHeapObject([&](Il2CppObject* obj) {
        if (obj && obj->klass == klass) out.push_back(obj);
    });
    return out;
}

static uint64_t NowMs() { return GetTickCount64(); }

static void CaptureObject(Il2CppObject* group, Il2CppObject* track) {
    if (group) {
        for (auto& r : g_originals)
            if (r.obj == group) return;
        Originals o;
        o.obj = group;
        o.judgeLevel = *(int32_t*)((uint8_t*)group + OFF_JUDGE_LEVEL);
        o.isHitBeat  = *(bool*)((uint8_t*)group + OFF_IS_HIT_BEAT);
        o.captured   = true;
        g_originals.push_back(o);
    }
    if (track) {
        for (auto& r : g_originals)
            if (r.obj == track) return;
        Originals o;
        o.obj    = track;
        o.isPlay = *(bool*)((uint8_t*)track + OFF_IS_PLAY);
        o.captured = true;
        g_originals.push_back(o);
    }
}

static void RestoreAll() {
    for (auto& r : g_originals) {
        if (!r.captured) continue;
        if (r.obj && r.judgeLevel != 0)
            *(int32_t*)((uint8_t*)r.obj + OFF_JUDGE_LEVEL) = r.judgeLevel;
        if (r.obj)
            *(bool*)((uint8_t*)r.obj + OFF_IS_HIT_BEAT) = r.isHitBeat;
        if (r.obj)
            *(bool*)((uint8_t*)r.obj + OFF_IS_PLAY) = r.isPlay;
    }
    g_originals.clear();
    g_modified = 0;
}

static void ApplyOnce() {
    if (!g_clsAuditionGroup || !g_clsTrackCtrl) {
        g_clsAuditionGroup = FindClass(kAuditionGroupNs, kAuditionGroupName);
        g_clsTrackCtrl      = FindClass(kTrackCtrlNs,  kTrackCtrlName);
        if (!g_clsAuditionGroup || !g_clsTrackCtrl) return;
    }
    int32_t n = 0;

    auto groups = FindObjectsOfClass(g_clsAuditionGroup);
    for (auto* g : groups) {
        CaptureObject(g, nullptr);
        *(int32_t*)((uint8_t*)g + OFF_JUDGE_LEVEL) = PERFECT;
        *(bool*)((uint8_t*)g + OFF_IS_HIT_BEAT)     = true;
        ++n;
    }

    auto tracks = FindObjectsOfClass(g_clsTrackCtrl);
    for (auto* t : tracks) {
        CaptureObject(nullptr, t);
        *(bool*)((uint8_t*)t + OFF_IS_PLAY) = true;
        ++n;
    }

    g_modified = n;
}

void OnTick() {
    if (!g_enabled.load()) return;
    uint64_t now = NowMs();
    if (now - g_lastTick.load() >= REAPPLY_MS) {
        g_lastTick = now;
        ApplyOnce();
    }
}

void EnableAutoDance() {
    g_enabled = true;
    ApplyOnce();
}

void DisableAutoDance() {
    g_enabled = false;
    RestoreAll();
}

int32_t ModifiedCount() { return g_modified.load(); }
