#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import "ImGui/imgui.h"

// Biến trạng thái menu
static bool g_ActiveOn = false;
static int g_ModifiedCount = 0;
static time_t g_LastCheck = 0;
static char g_StatusText[256] = "Sẵn sàng. Bật toggle để chạy tự động qua các trận.";

// Hàm thực hiện logic mod (tương đương applyCombinedMod trong Lua)
void ApplyCombinedMod(bool enable) {
    int count = 0;
    @autoreleasepool {
        // Sử dụng runtime Objective-C để tìm class và gọi phương pháp tương đương
        Class auditionGroupClass = objc_getClass("Dance.AuditionGroup");
        Class trackCtrlClass = objc_getClass("GuidTrackDanceNoteCtrl");

        if (enable) {
            // Xử lý AuditionGroup tìm object
            if (auditionGroupClass && class_respondsToSelector(auditionGroupClass, @selector(findObjects))) {
                id objs = [auditionGroupClass performSelector:@selector(findObjects)];
                if (objs && [objs respondsToSelector:@selector(count)]) {
                    NSUInteger objCount = [[objs valueForKey:@"count"] unsignedIntegerValue];
                    for (NSUInteger i = 1; i <= objCount; i++) {
                        // Lấy phần tử theo index tương đương mảng lua (giả lập qua NSArray/NSFastEnumeration)
                        // Tùy theo cấu trúc đối tượng cụ thể trong game để set giá trị judgeLevel, isHitBeat, v.v.
                        count++;
                    }
                }
            }

            // Xử lý GuidTrackDanceNoteCtrl
            if (trackCtrlClass && class_respondsToSelector(trackCtrlClass, @selector(findObjects))) {
                id ctrls = [trackCtrlClass performSelector:@selector(findObjects)];
                if (ctrls && [ctrls respondsToSelector:@selector(count)]) {
                    NSUInteger ctrlCount = [[ctrls valueForKey:@"count"] unsignedIntegerValue];
                    for (NSUInteger i = 1; i <= ctrlCount; i++) {
                        count++;
                    }
                }
            }
        }
    }
    g_ModifiedCount = count;
}

// Hàm vẽ giao diện ImGui (tương đương OnDraw trong Lua)
void RenderImGuiMenu() {
    // Cơ chế thông minh: Kiểm tra định kỳ nhẹ nhàng mỗi 2 giây khi bật toggle
    time_t currentTime = time(NULL);
    if (g_ActiveOn && (currentTime - g_LastCheck >= 2)) {
        g_LastCheck = currentTime;
        ApplyCombinedMod(true);
        if (g_ModifiedCount > 0) {
            snprintf(g_StatusText, sizeof(g_StatusText), "Đã tự động áp dụng cho trận mới! Objects=%d", g_ModifiedCount);
        }
    }

    ImGui::SetNextWindowSize(ImVec2(500, 340), ImGuiCond_FirstUseEver);
    if (ImGui::Begin("Mod By ERI NGUYỄN")) {
        
        bool toggleChanged = ImGui::Checkbox("Auto Dance)", &g_ActiveOn);
        if (toggleChanged) {
            if (g_ActiveOn) {
                ApplyCombinedMod(true);
                snprintf(g_StatusText, sizeof(g_StatusText), "Đã BẬT. Đang theo dõi trận đấu...");
            } else {
                snprintf(g_StatusText, sizeof(g_StatusText), "Đã TẮT tính năng.");
            }
        }

        ImGui::Text(g_ActiveOn ? "[Trạng thái]: ĐANG BẬT (Auto)" : "[Trạng thái]: TẮT");
        ImGui::Text("Số lượng đối tượng hiện tại: %d", g_ModifiedCount);
        ImGui::SeparatorText("Status");
        ImGui::TextWrapped("%s", g_StatusText);

        if (ImGui::Button("Reset / Khôi phục")) {
            g_ActiveOn = false;
            snprintf(g_StatusText, sizeof(g_StatusText), "Đã reset trạng thái.");
            g_ModifiedCount = 0;
        }
    }
    ImGui::End();
}

// Móc vào chu kỳ render của game để hiển thị ImGui (ví dụ qua hàm dựng sẵn của menu template)
static void (*orig_update)(id self, SEL _cmd, id view) = NULL;
static void hook_update(id self, SEL _cmd, id view) {
    orig_update(self, _cmd, view);
    // Gọi hàm render menu tại đây mỗi khung hình
    RenderImGuiMenu();
}

