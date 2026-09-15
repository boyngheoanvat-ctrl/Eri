// main.mm — AutoDance HexControl v6 (Native IL2CPP + MSHookFunction)
// Compile (với Theos hoặc Makefile có liên kết MobileSubstrate):
//   xcrun -sdk iphoneos clang++ -shared -fobjc-arc -arch arm64 \
//     -o main.dylib main.mm -framework Foundation -lsubstrate

#import <Foundation/Foundation.h>
#include <pthread.h>
#include <dlfcn.h>
#include <stdint.h>
#include <string.h>
#include <substrate.h>

// ============================================================
// 1) IL2CPP C API Declarations
// ============================================================
#ifdef __cplusplus
extern "C" {
#endif

typedef struct Il2CppImage    Il2CppImage;
typedef struct Il2CppClass    Il2CppClass;
typedef struct Il2CppObject   Il2CppObject;
typedef struct Il2CppField    Il2CppField;
typedef struct Il2CppAssembly Il2CppAssembly;
typedef struct Il2CppMethodInfo Il2CppMethodInfo;

const void*     il2cpp_domain_get(void);
size_t          il2cpp_domain_get_assembly_count(const void *domain);
Il2CppAssembly* il2cpp_domain_get_assembly(const void *domain, size_t idx);
const Il2CppImage* il2cpp_assembly_get_image(Il2CppAssembly *a);
Il2CppClass*    il2cpp_class_from_name(const Il2CppImage *img, const char *ns, const char *name);
Il2CppField*    il2cpp_class_get_field_from_name(Il2CppClass *k, const char *name);
ptrdiff_t       il2cpp_field_get_offset(Il2CppField *f);
Il2CppMethodInfo* il2cpp_class_get_method_from_name(Il2CppClass *klass, const char *name, int argsCount);

#ifdef __cplusplus
}
#endif

// ============================================================
// 2) Configuration & Offsets
// ============================================================
static const int    PERFECT_LEVEL   = 4;   // 4 tương ứng với Perfect
static bool         g_AutoDanceOn   = true;

struct ModOffsets {
    ptrdiff_t judgeLevel;
    ptrdiff_t isHitBeat;
    bool ready;
};
static ModOffsets g_off = {0, 0, false};

static Il2CppClass* FindClass(const char* ns, const char* name) {
    const void* domain = il2cpp_domain_get();
    size_t count = il2cpp_domain_get_assembly_count(domain);
    for (size_t i = 0; i < count; i++) {
        Il2CppAssembly* asm_ = il2cpp_domain_get_assembly(domain, i);
        if (!asm_) continue;
        const Il2CppImage* img = il2cpp_assembly_get_image(asm_);
        if (!img) continue;
        Il2CppClass* cls = il2cpp_class_from_name(img, ns, name);
        if (cls) return cls;
    }
    return nullptr;
}

static void ResolveOffsets() {
    if (g_off.ready) return;

    Il2CppClass* agCls = FindClass("Dance", "AuditionGroup");
    if (agCls) {
        Il2CppField* f1 = il2cpp_class_get_field_from_name(agCls, "judgeLevel");
        Il2CppField* f2 = il2cpp_class_get_field_from_name(agCls, "isHitBeat");
        if (f1) g_off.judgeLevel = il2cpp_field_get_offset(f1);
        if (f2) g_off.isHitBeat  = il2cpp_field_get_offset(f2);
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
    // Thực hiện ghi đè giá trị trực tiếp trên instance hiện tại mỗi frame
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

    // Gọi lại hàm gốc để game duy trì luồng xử lý bình thường
    if (orig_AuditionGroup_Update) {
        orig_AuditionGroup_Update(self, method);
    }
}

static void SetupHooks() {
    ResolveOffsets();
    Il2CppClass* agCls = FindClass("Dance", "AuditionGroup");
    if (!agCls) {
        NSLog(@"[AutoDance] SetupHooks failed: AuditionGroup class missing.");
        return;
    }

    Il2CppMethodInfo* updateMethod = il2cpp_class_get_method_from_name(agCls, "Update", 0);
    if (updateMethod) {
        // Trong cấu trúc Il2CppMethodInfo của Unity, con trỏ hàm thực thi (methodPointer) 
        // thường nằm ở các offset đầu tiên. Ta ép kiểu lấy con trỏ thực thi thực tế:
        // Lưu ý: Offset của methodPointer có thể khác nhau tùy phiên bản Unity (thường là offset tương ứng trong struct).
        // Cách an toàn chuẩn IL2CPP: lấy trực tiếp trường `methodPointer` từ struct `Il2CppMethodInfo`.
        
        void* funcAddress = *(void**)((uintptr_t)updateMethod); // Hoặc dịch offset chuẩn tùy phiên bản Unity nếu cần
        
        if (funcAddress) {
            MSHookFunction(funcAddress, (void*)&hk_AuditionGroup_Update, (void**)&orig_AuditionGroup_Update);
            NSLog(@"[AutoDance] Successfully hooked AuditionGroup::Update at %p", funcAddress);
        } else {
            // Fallback nếu layout trỏ trực tiếp cần dịch offset
            // Ví dụ Unity 2022+ đôi khi `methodPointer` nằm ở offset khác, 
            // bạn có thể dùng trực tiếp địa chỉ thunk từ IDA/Ghidra nếu cần độ chính xác tuyệt đối.
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
    NSLog(@"║          Mod By Eri Nguyễn               ║");
    NSLog(@"╚══════════════════════════════════════════╝");

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
            SetupHooks();
        }
    );
}
