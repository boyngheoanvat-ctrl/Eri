// main.mm — AutoDance HexControl v7 (Dynamic IL2CPP Resolution)
#import <Foundation/Foundation.h>
#include <pthread.h>
#include <dlfcn.h>
#include <stdint.h>
#include <string.h>
#include <substrate.h>

// ============================================================
// 1) Dynamic IL2CPP Function Pointers (Tránh lỗi Undefined Symbols)
// ============================================================
typedef const void* (*il2cpp_domain_get_t)(void);
typedef size_t (*il2cpp_domain_get_assembly_count_t)(const void *domain);
typedef void* (*il2cpp_domain_get_assembly_t)(const void *domain, size_t idx);
typedef const void* (*il2cpp_assembly_get_image_t)(void *assembly);
typedef void* (*il2cpp_class_from_name_t)(const void *image, const char *namespaze, const char *name);
typedef void* (*il2cpp_class_get_field_from_name_t)(void *klass, const char *name);
typedef ptrdiff_t (*il2cpp_field_get_offset_t)(void *field);
typedef void* (*il2cpp_class_get_method_from_name_t)(void *klass, const char *name, int argsCount);

static il2cpp_domain_get_t                 p_il2cpp_domain_get = nullptr;
static il2cpp_domain_get_assembly_count_t  p_il2cpp_domain_get_assembly_count = nullptr;
static il2cpp_domain_get_assembly_t        p_il2cpp_domain_get_assembly = nullptr;
static il2cpp_assembly_get_image_t         p_il2cpp_assembly_get_image = nullptr;
static il2cpp_class_from_name_t            p_il2cpp_class_from_name = nullptr;
static il2cpp_class_get_field_from_name_t  p_il2cpp_class_get_field_from_name = nullptr;
static il2cpp_field_get_offset_t           p_il2cpp_field_get_offset = nullptr;
static il2cpp_class_get_method_from_name_t p_il2cpp_class_get_method_from_name = nullptr;

static void InitIL2CPPAPIs() {
    // Lấy handle của tiến trình hoặc libil2cpp trực tiếp lúc runtime
    void* handle = RTLD_DEFAULT; 
    
    p_il2cpp_domain_get = (il2cpp_domain_get_t)dlsym(handle, "il2cpp_domain_get");
    p_il2cpp_domain_get_assembly_count = (il2cpp_domain_get_assembly_count_t)dlsym(handle, "il2cpp_domain_get_assembly_count");
    p_il2cpp_domain_get_assembly = (il2cpp_domain_get_assembly_t)dlsym(handle, "il2cpp_domain_get_assembly");
    p_il2cpp_assembly_get_image = (il2cpp_assembly_get_image_t)dlsym(handle, "il2cpp_assembly_get_image");
    p_il2cpp_class_from_name = (il2cpp_class_from_name_t)dlsym(handle, "il2cpp_class_from_name");
    p_il2cpp_class_get_field_from_name = (il2cpp_class_get_field_from_name_t)dlsym(handle, "il2cpp_class_get_field_from_name");
    p_il2cpp_field_get_offset = (il2cpp_field_get_offset_t)dlsym(handle, "il2cpp_field_get_offset");
    p_il2cpp_class_get_method_from_name = (il2cpp_class_get_method_from_name_t)dlsym(handle, "il2cpp_class_get_method_from_name");
    
    NSLog(@"[AutoDance] IL2CPP APIs resolved via dlsym.");
}

// ============================================================
// 2) Configuration & Offsets
// ============================================================
static const int    PERFECT_LEVEL   = 4;
static bool         g_AutoDanceOn   = true;

struct ModOffsets {
    ptrdiff_t judgeLevel;
    ptrdiff_t isHitBeat;
    bool ready;
};
static ModOffsets g_off = {0, 0, false};

static void* FindClass(const char* ns, const char* name) {
    if (!p_il2cpp_domain_get || !p_il2cpp_domain_get_assembly_count) return nullptr;
    const void* domain = p_il2cpp_domain_get();
    size_t count = p_il2cpp_domain_get_assembly_count(domain);
    for (size_t i = 0; i < count; i++) {
        void* asm_ = p_il2cpp_domain_get_assembly(domain, i);
        if (!asm_) continue;
        const void* img = p_il2cpp_assembly_get_image(asm_);
        if (!img) continue;
        void* cls = p_il2cpp_class_from_name(img, ns, name);
        if (cls) return cls;
    }
    return nullptr;
}

static void ResolveOffsets() {
    if (g_off.ready) return;
    InitIL2CPPAPIs();

    void* agCls = FindClass("Dance", "AuditionGroup");
    if (agCls && p_il2cpp_class_get_field_from_name && p_il2cpp_field_get_offset) {
        void* f1 = p_il2cpp_class_get_field_from_name(agCls, "judgeLevel");
        void* f2 = p_il2cpp_class_get_field_from_name(agCls, "isHitBeat");
        if (f1) g_off.judgeLevel = p_il2cpp_field_get_offset(f1);
        if (f2) g_off.isHitBeat  = p_il2cpp_field_get_offset(f2);
        NSLog(@"[AutoDance] AuditionGroup resolved — judgeLevel: %td, isHitBeat: %td", 
              g_off.judgeLevel, g_off.isHitBeat);
        g_off.ready = true;
    } else {
        NSLog(@"[AutoDance] ⚠️ Dance.AuditionGroup not found yet, retrying later...");
    }
}

// ============================================================
// 3) Hook Implementation via MSHookFunction
// ============================================================
typedef void (*AuditionGroup_Update_t)(void* self, void* method);
static AuditionGroup_Update_t orig_AuditionGroup_Update = nullptr;

static void hk_AuditionGroup_Update(void* self, void* method) {
    if (g_AutoDanceOn && g_off.ready && self) {
        if (g_off.judgeLevel != 0) {
            int* judgePtr = (int*)((uintptr_t)self + g_off.judgeLevel);
            *judgePtr = PERFECT_LEVEL;
        }
        if (g_off.isHitBeat != 0) {
            bool* hitPtr = (bool*)((uintptr_t)self + g_off.isHitBeat);
            *hitPtr = true;
        }
    }

    if (orig_AuditionGroup_Update) {
        orig_AuditionGroup_Update(self, method);
    }
}

static void SetupHooks() {
    ResolveOffsets();
    void* agCls = FindClass("Dance", "AuditionGroup");
    if (!agCls || !p_il2cpp_class_get_method_from_name) {
        NSLog(@"[AutoDance] SetupHooks failed: AuditionGroup class missing.");
        return;
    }

    void* updateMethod = p_il2cpp_class_get_method_from_name(agCls, "Update", 0);
    if (updateMethod) {
        void* funcAddress = *(void**)((uintptr_t)updateMethod);
        
        if (funcAddress) {
            MSHookFunction(funcAddress, (void*)&hk_AuditionGroup_Update, (void**)&orig_AuditionGroup_Update);
            NSLog(@"[AutoDance] Successfully hooked AuditionGroup::Update at %p", funcAddress);
        } else {
            NSLog(@"[AutoDance] ⚠️ Method pointer address is NULL.");
        }
    } else {
        NSLog(@"[AutoDance] ⚠️ Update method not found in AuditionGroup.");
    }
}

// ============================================================
// 4) Dylib Entry Point
// ============================================================
__attribute__((constructor))
static void InitDylib() {
    NSLog(@"╔══════════════════════════════════════════╗");
    NSLog(@"║  MOD BY ERI NGUYỄN                       ║");
    NSLog(@"╚══════════════════════════════════════════╝");

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
            SetupHooks();
        }
    );
}
