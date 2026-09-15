#import <Foundation/Foundation.h>

// Khai báo cấu trúc ImGui để trình biên dịch không báo lỗi
namespace ImGui {
    bool Begin(const char* name, bool* p_open = NULL, int flags = 0);
    void End();
    bool Checkbox(const char* label, bool* v);
    void Text(const char* fmt, ...);
    void Separator();
    bool Button(const char* label, const ImVec2& size = ImVec2(0,0));
    void SetNextWindowSize(float width, float height, int cond = 0);
}

struct ImVec2 {
    float x, y;
    ImVec2() : x(0.0f), y(0.0f) {}
    ImVec2(float _x, float _y) : x(_x), y(_y) {}
};

static BOOL g_activeOn = NO;
static int g_modifiedCount = 0;

static void applyMod(BOOL enable) {
    int count = 0;
    @try {
        Class auditionGroupClass = NSClassFromString(@"Dance.AuditionGroup");
        Class trackCtrlClass = NSClassFromString(@"GuidTrackDanceNoteCtrl");
        
        if (enable) {
            if (auditionGroupClass && [auditionGroupClass respondsToSelector:@selector(findObjects)]) {
                id objs = [auditionGroupClass performSelector:@selector(findObjects)];
                if (objs && [objs respondsToSelector:@selector(count)]) {
                    NSUInteger total = [[objs performSelector:@selector(count)] unsignedIntegerValue];
                    for (NSUInteger i = 0; i < total; i++) {
                        count++;
                    }
                }
            }
            if (trackCtrlClass && [trackCtrlClass respondsToSelector:@selector(findObjects)]) {
                id ctrls = [trackCtrlClass performSelector:@selector(findObjects)];
                if (ctrls && [ctrls respondsToSelector:@selector(count)]) {
                    NSUInteger total = [[ctrls performSelector:@selector(count)] unsignedIntegerValue];
                    for (NSUInteger i = 0; i < total; i++) {
                        count++;
                    }
                }
            }
        }
    } @catch (NSException *exception) {
        NSLog(@"[EriError]: %@", exception.reason);
    }
    g_modifiedCount = count;
}

void OnDraw() {
    static time_t lastCheck = 0;
    time_t currentTime = time(NULL);
    
    if (g_activeOn && (currentTime - lastCheck >= 2)) {
        lastCheck = currentTime;
        applyMod(YES);
    }

    ImGui::SetNextWindowSize(500, 340, 0);
    if (ImGui::Begin("AutoDance HexControl v4 (Auto-Match)", NULL, 0)) {
        if (ImGui::Checkbox("Bật Auto Tất Cả (Tự động bắt trận mới)", &g_activeOn)) {
            if (g_activeOn) {
                applyMod(YES);
            }
        }
        
        if (g_activeOn) {
            ImGui::Text("[Trạng thái]: ĐANG BẬT (Auto)");
        } else {
            ImGui::Text("[Trạng thái]: TẮT");
        }
        
        ImGui::Text("Số lượng đối tượng hiện tại: %d", g_modifiedCount);
        ImGui::Separator();
        
        if (ImGui::Button("Reset / Khôi phục", ImVec2(0, 0))) {
            g_activeOn = NO;
            g_modifiedCount = 0;
        }
    }
    ImGui::End();
}

__attribute__((constructor)) static void init() {
    NSLog(@"=== EriAutoDance Native Loaded Successfully ===");
}
